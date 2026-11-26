import {createHash, randomBytes} from 'node:crypto';
import {FieldValue, Timestamp} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {keys, object} from '../medical/medical_contract';
import {resqmeRuntimeOptions} from '../onboarding/authorization';
import {auditRecord, requireMasterAdmin, staffManagementDeps} from '../staff/staff_account_management';
import {enforceTransactionalRateLimit, maskLrn} from '../staff/staff_student_management';
import {normalizeRosterName, rosterCodeDigest, rosterLookupId} from './roster_contract';
import {parseSf1Workbook, type ParsedSf1Row} from './sf1_parser';

export type PreviewRowStatus =
  | 'new'
  | 'unchanged'
  | 'proposed_update'
  | 'duplicate'
  | 'conflict'
  | 'invalid';

export interface PreviewRowRecord {
  rowNumber: number;
  status: PreviewRowStatus;
  maskedLrn: string | null;
  fullName: string;
  gradeLevel: string;
  sex: string | null;
  birthDate: string | null;
  reason: string | null;
}

interface StoredPreviewRow {
  rowNumber: number;
  status: PreviewRowStatus;
  rosterId: string | null;
  lrn: string | null;
  maskedLrn: string | null;
  lastName: string;
  firstName: string;
  middleName: string;
  fullName: string;
  normalizedName: string;
  gradeLevel: string;
  sex: string | null;
  birthDate: string | null;
  fatherName: string | null;
  motherMaidenName: string | null;
  guardianName: string | null;
  guardianRelationship: string | null;
  parentGuardianContact: string | null;
  reason: string | null;
}

const PREVIEW_TTL_MS = 15 * 60_000;
const ENROLLMENT_CODE_TTL_MS = 30 * 24 * 60 * 60 * 1000;
const CHUNK_SIZE = 100;
const PREVIEW_ID_PATTERN = /^[a-f0-9]{32,64}$/;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9_-]{8,128}$/;

function generateEnrollmentCode(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = randomBytes(20);
  let code = '';
  for (let i = 0; i < 20; i++) {
    code += alphabet[bytes[i] % alphabet.length];
  }
  return code;
}

function summarizeStatuses(rows: readonly {status: PreviewRowStatus}[]) {
  const counts = {
    totalRows: rows.length,
    newCount: 0,
    unchangedCount: 0,
    proposedUpdateCount: 0,
    duplicateCount: 0,
    conflictCount: 0,
    invalidCount: 0,
  };
  for (const r of rows) {
    if (r.status === 'new') counts.newCount++;
    else if (r.status === 'unchanged') counts.unchangedCount++;
    else if (r.status === 'proposed_update') counts.proposedUpdateCount++;
    else if (r.status === 'duplicate') counts.duplicateCount++;
    else if (r.status === 'conflict') counts.conflictCount++;
    else counts.invalidCount++;
  }
  return counts;
}

function isSameRosterPayload(
  existing: Record<string, unknown>,
  row: ParsedSf1Row,
  gradeLevel: string,
): boolean {
  return (
    normalizeRosterName(String(existing.normalizedName ?? '')) ===
      normalizeRosterName(row.fullName) &&
    String(existing.gradeLevel ?? '') === gradeLevel &&
    (existing.sex ?? null) === row.sex &&
    (existing.birthDate ?? null) === row.birthDate
  );
}

export const previewSchoolRosterImport = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['fileName', 'fileBase64', 'confirmedGradeLevel']);

  if (typeof data.fileName !== 'string' || data.fileName.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'File name is required.');
  }
  if (!/\.(xls|xlsx)$/i.test(data.fileName.trim())) {
    throw new HttpsError('invalid-argument', 'Only .xls and .xlsx SF1 spreadsheets are supported.');
  }
  if (typeof data.fileBase64 !== 'string' || data.fileBase64.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Spreadsheet content is required.');
  }
  const confirmedGradeLevel =
    typeof data.confirmedGradeLevel === 'string' && data.confirmedGradeLevel.trim().length > 0
      ? data.confirmedGradeLevel.trim()
      : null;

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  await enforceTransactionalRateLimit(
    db,
    `staffRosterImportRateLimits/${adminUid}`,
    10,
    'Too many roster import previews. Wait before trying again.',
  );

  const buffer = Buffer.from(data.fileBase64, 'base64');
  const fileSha256 = createHash('sha256').update(buffer).digest('hex');
  const parsed = parseSf1Workbook({
    buffer,
    confirmedGradeLevel,
    fileName: data.fileName.trim(),
  });

  const key = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  if (!key || Buffer.byteLength(key, 'utf8') < 32) {
    throw new HttpsError('failed-precondition', 'Roster lookup key is not configured.');
  }

  // Opportunistic TTL cleanup of expired previews for this school so temporary rows are not retained.
  try {
    const nowCleanup = Date.now();
    const staleSnap = await db
      .collection('schoolRosterImportPreviews')
      .where('schoolId', '==', admin.schoolId)
      .get();
    let cleaned = 0;
    for (const doc of staleSnap.docs) {
      if (cleaned >= 15) break;
      const d = doc.data();
      const exp = d.expiresAt;
      const expMs =
        exp instanceof Timestamp
          ? exp.toMillis()
          : exp instanceof Date
            ? exp.getTime()
            : 0;
      if (expMs > 0 && expMs <= nowCleanup) {
        const refAny = doc.ref as unknown as {delete?: () => Promise<void>};
        if (typeof refAny.delete === 'function') {
          await refAny.delete();
        }
        cleaned++;
      }
    }
  } catch {
    // Cleanup is best-effort and must never fail a valid preview.
  }

  const seenLrns = new Set<string>();
  const storedRows: StoredPreviewRow[] = [];

  // Load existing studentProfiles for conflict detection
  const studentsSnap = await db.collection('studentProfiles').where('schoolId', '==', admin.schoolId).get();
  const studentByLrn = new Map<string, {uid: string; data: Record<string, unknown>}>();
  for (const doc of studentsSnap.docs) {
    const s = doc.data();
    if (typeof s.lrn === 'string' && /^\d{12}$/.test(s.lrn)) {
      studentByLrn.set(s.lrn, {uid: doc.id, data: s});
    }
  }

  for (const row of parsed.rows) {
    const masked = maskLrn(row.lrn);
    if (row.validationError || !row.lrn) {
      storedRows.push({
        rowNumber: row.rowNumber,
        status: 'invalid',
        rosterId: null,
        lrn: null,
        maskedLrn: masked,
        lastName: row.lastName,
        firstName: row.firstName,
        middleName: row.middleName,
        fullName: row.fullName || 'Unknown Student',
        normalizedName: normalizeRosterName(row.fullName || 'unknown'),
        gradeLevel: parsed.effectiveGradeLevel,
        sex: row.sex,
        birthDate: row.birthDate,
        fatherName: row.fatherName,
        motherMaidenName: row.motherMaidenName,
        guardianName: row.guardianName,
        guardianRelationship: row.guardianRelationship,
        parentGuardianContact: row.parentGuardianContact,
        reason: row.validationError ?? 'Invalid row',
      });
      continue;
    }

    if (seenLrns.has(row.lrn)) {
      storedRows.push({
        rowNumber: row.rowNumber,
        status: 'duplicate',
        rosterId: null,
        lrn: null,
        maskedLrn: masked,
        lastName: row.lastName,
        firstName: row.firstName,
        middleName: row.middleName,
        fullName: row.fullName,
        normalizedName: normalizeRosterName(row.fullName),
        gradeLevel: parsed.effectiveGradeLevel,
        sex: row.sex,
        birthDate: row.birthDate,
        fatherName: row.fatherName,
        motherMaidenName: row.motherMaidenName,
        guardianName: row.guardianName,
        guardianRelationship: row.guardianRelationship,
        parentGuardianContact: row.parentGuardianContact,
        reason: 'Duplicate LRN within uploaded SF1 file',
      });
      continue;
    }
    seenLrns.add(row.lrn);

    const rId = rosterLookupId(row.lrn, key);
    const existingSnap = await db.doc(`schoolRosterClaims/${rId}`).get();
    const existing = existingSnap.exists ? existingSnap.data() : undefined;
    const existingStudent = studentByLrn.get(row.lrn);

    let status: PreviewRowStatus = 'new';
    let reason: string | null = null;

    if (existing) {
      if (existing.schoolId !== admin.schoolId) {
        status = 'conflict';
        reason = 'LRN is already claimed by another school roster.';
      } else if (
        existing.claimedByUid &&
        normalizeRosterName(String(existing.normalizedName ?? '')) !== normalizeRosterName(row.fullName)
      ) {
        status = 'conflict';
        reason = 'Claimed student identity mismatch; requires separate administrative review.';
      } else if (existing.claimedByUid) {
        status = isSameRosterPayload(existing, row, parsed.effectiveGradeLevel)
          ? 'unchanged'
          : 'conflict';
        if (status === 'conflict') {
          reason = 'Already claimed by a registered student account; cannot overwrite claimed record.';
        }
      } else if (isSameRosterPayload(existing, row, parsed.effectiveGradeLevel)) {
        status = 'unchanged';
      } else {
        status = 'proposed_update';
        reason = 'Updates unclaimed roster metadata (grade/name/details).';
      }
    } else if (
      existingStudent &&
      normalizeRosterName(String(existingStudent.data.fullName ?? '')) !==
        normalizeRosterName(row.fullName)
    ) {
      status = 'conflict';
      reason = 'Existing registered student with this LRN has a different name.';
    }

    storedRows.push({
      rowNumber: row.rowNumber,
      status,
      rosterId: status === 'new' || status === 'proposed_update' ? rId : null,
      lrn: status === 'new' || status === 'proposed_update' ? row.lrn : null,
      maskedLrn: masked,
      lastName: row.lastName,
      firstName: row.firstName,
      middleName: row.middleName,
      fullName: row.fullName,
      normalizedName: normalizeRosterName(row.fullName),
      gradeLevel: parsed.effectiveGradeLevel,
      sex: row.sex,
      birthDate: row.birthDate,
      fatherName: row.fatherName,
      motherMaidenName: row.motherMaidenName,
      guardianName: row.guardianName,
      guardianRelationship: row.guardianRelationship,
      parentGuardianContact: row.parentGuardianContact,
      reason,
    });
  }

  const summary = summarizeStatuses(storedRows);
  const previewId = randomBytes(16).toString('hex');
  const nowMs = Date.now();

  await db.doc(`schoolRosterImportPreviews/${previewId}`).create({
    schoolId: admin.schoolId,
    actorUid: adminUid,
    fileName: data.fileName.trim().slice(0, 120),
    fileSha256,
    detectedGradeLevel: parsed.detectedGradeLevel,
    confirmedGradeLevel: parsed.effectiveGradeLevel,
    summary,
    rows: storedRows,
    consumed: false,
    expiresAt: Timestamp.fromMillis(nowMs + PREVIEW_TTL_MS),
    createdAt: FieldValue.serverTimestamp(),
  });

  const publicRows: PreviewRowRecord[] = storedRows.map((r) => ({
    rowNumber: r.rowNumber,
    status: r.status,
    maskedLrn: r.maskedLrn,
    fullName: r.fullName,
    gradeLevel: r.gradeLevel,
    sex: r.sex,
    birthDate: r.birthDate,
    reason: r.reason,
  }));

  return {
    previewId,
    fileName: data.fileName.trim().slice(0, 120),
    fileSha256,
    detectedGradeLevel: parsed.detectedGradeLevel,
    confirmedGradeLevel: parsed.effectiveGradeLevel,
    summary,
    rows: publicRows,
  };
});

export const commitSchoolRosterImport = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['previewId', 'requestId', 'expectedFileSha256', 'privacyNoticeAcknowledged']);

  if (typeof data.previewId !== 'string' || !PREVIEW_ID_PATTERN.test(data.previewId)) {
    throw new HttpsError('invalid-argument', 'Invalid preview ID.');
  }
  if (typeof data.requestId !== 'string' || !REQUEST_ID_PATTERN.test(data.requestId)) {
    throw new HttpsError('invalid-argument', 'Invalid import request ID.');
  }
  if (data.privacyNoticeAcknowledged !== true) {
    throw new HttpsError(
      'failed-precondition',
      'Acknowledge the Data Privacy Act notice before importing student records.',
    );
  }
  if (typeof data.expectedFileSha256 !== 'string' || !/^[a-f0-9]{64}$/i.test(data.expectedFileSha256)) {
    throw new HttpsError('invalid-argument', 'Invalid preview file hash.');
  }
  const expectedFileSha256 = data.expectedFileSha256.toLowerCase();
  const previewId = data.previewId;
  const requestId = data.requestId;

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  const key = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  if (!key || Buffer.byteLength(key, 'utf8') < 32) {
    throw new HttpsError('failed-precondition', 'Roster lookup key is not configured.');
  }

  const importRef = db.doc(`schoolRosterImports/${requestId}`);
  const previewRef = db.doc(`schoolRosterImportPreviews/${previewId}`);

  const existingImport = await importRef.get();
  if (existingImport.exists) {
    if (
      existingImport.get('schoolId') !== admin.schoolId ||
      existingImport.get('previewId') !== previewId
    ) {
      throw new HttpsError('already-exists', 'Request ID already used for another import.');
    }
    if (existingImport.get('status') === 'completed') {
      return {
        importId: requestId,
        status: 'completed',
        committedCount: Number(existingImport.get('committedCount') ?? 0),
        newCount: Number(existingImport.get('newCount') ?? 0),
        updatedCount: Number(existingImport.get('updatedCount') ?? 0),
        generatedCredentials: [],
      };
    }
  }

  const previewSnap = await previewRef.get();
  const preview = previewSnap.data();
  const expiresAt = preview?.expiresAt;
  const expiresMs =
    expiresAt instanceof Timestamp
      ? expiresAt.toMillis()
      : expiresAt instanceof Date
        ? expiresAt.getTime()
        : 0;

  if (
    !previewSnap.exists ||
    !preview ||
    preview.schoolId !== admin.schoolId ||
    preview.actorUid !== adminUid ||
    expiresMs <= Date.now()
  ) {
    throw new HttpsError('failed-precondition', 'Import preview expired or unavailable.');
  }
  if (
    expectedFileSha256 !== null &&
    typeof preview.fileSha256 === 'string' &&
    preview.fileSha256.toLowerCase() !== expectedFileSha256
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Import preview file hash mismatch. Generate a fresh preview before committing.',
    );
  }
  if (preview.consumed === true && !existingImport.exists) {
    throw new HttpsError('failed-precondition', 'Import preview has already been committed.');
  }

  const rows = ((preview.rows as StoredPreviewRow[]) ?? []).filter(
    (r) => (r.status === 'new' || r.status === 'proposed_update') && r.rosterId && r.lrn,
  );
  if (rows.length === 0) {
    throw new HttpsError('failed-precondition', 'No new or updatable student rows in this preview.');
  }

  const startIndex = existingImport.exists
    ? Number(existingImport.get('lastCommittedIndex') ?? 0)
    : 0;
  let newCount = existingImport.exists ? Number(existingImport.get('newCount') ?? 0) : 0;
  let updatedCount = existingImport.exists ? Number(existingImport.get('updatedCount') ?? 0) : 0;
  const generatedCredentials: Array<{
    maskedLrn: string;
    fullName: string;
    gradeLevel: string;
    enrollmentCode: string;
  }> = [];

  if (!existingImport.exists) {
    await importRef.create({
      schoolId: admin.schoolId,
      actorUid: adminUid,
      previewId,
      fileName: preview.fileName ?? 'sf1-import',
      confirmedGradeLevel: preview.confirmedGradeLevel ?? '',
      status: 'in_progress',
      totalRows: rows.length,
      lastCommittedIndex: 0,
      committedCount: 0,
      newCount: 0,
      updatedCount: 0,
      startedAt: FieldValue.serverTimestamp(),
    });
  }

  for (let offset = startIndex; offset < rows.length; offset += CHUNK_SIZE) {
    const chunk = rows.slice(offset, offset + CHUNK_SIZE);
    await db.runTransaction(async (tx) => {
      const snaps = await Promise.all(
        chunk.map((r) => tx.get(db.doc(`schoolRosterClaims/${r.rosterId}`))),
      );

      for (let i = 0; i < chunk.length; i++) {
        const row = chunk[i];
        const snap = snaps[i];
        const ref = db.doc(`schoolRosterClaims/${row.rosterId}`);

        if (snap.exists && snap.get('claimedByUid')) {
          continue; // Never overwrite a claimed student record
        }

        if (snap.exists) {
          const oldDigest = snap.get('enrollmentCodeDigest');
          const code = generateEnrollmentCode();
          const digest = rosterCodeDigest(code, key);
          const codeExpiresAt = Date.now() + ENROLLMENT_CODE_TTL_MS;
          if (typeof oldDigest === 'string' && oldDigest.length > 0) {
            tx.set(
              db.doc(`schoolRosterCodes/${oldDigest}`),
              {revoked: true, revokedAt: FieldValue.serverTimestamp()},
              {merge: true},
            );
          }
          tx.update(ref, {
            lastName: row.lastName,
            firstName: row.firstName,
            middleName: row.middleName,
            fullName: row.fullName,
            normalizedName: row.normalizedName,
            gradeLevel: row.gradeLevel,
            sex: row.sex,
            birthDate: row.birthDate,
            fatherName: row.fatherName,
            motherMaidenName: row.motherMaidenName,
            guardianName: row.guardianName,
            guardianRelationship: row.guardianRelationship,
            parentGuardianContact: row.parentGuardianContact,
            enrollmentCodeDigest: digest,
            codeExpiresAt,
            updatedAt: FieldValue.serverTimestamp(),
          });
          tx.create(db.doc(`schoolRosterCodes/${digest}`), {
            rosterId: row.rosterId,
            schoolId: admin.schoolId,
            claimedByUid: null,
            codeExpiresAt,
            createdAt: FieldValue.serverTimestamp(),
          });
          generatedCredentials.push({
            maskedLrn: row.maskedLrn ?? '••••••••••••',
            fullName: row.fullName,
            gradeLevel: row.gradeLevel,
            enrollmentCode: code,
          });
          updatedCount++;
        } else {
          const code = generateEnrollmentCode();
          const digest = rosterCodeDigest(code, key);
          const codeExpiresAt = Date.now() + ENROLLMENT_CODE_TTL_MS;
          tx.create(ref, {
            schoolId: admin.schoolId,
            lrn: row.lrn,
            lastName: row.lastName,
            firstName: row.firstName,
            middleName: row.middleName,
            fullName: row.fullName,
            normalizedName: row.normalizedName,
            gradeLevel: row.gradeLevel,
            sex: row.sex,
            birthDate: row.birthDate,
            fatherName: row.fatherName,
            motherMaidenName: row.motherMaidenName,
            guardianName: row.guardianName,
            guardianRelationship: row.guardianRelationship,
            parentGuardianContact: row.parentGuardianContact,
            enrollmentCodeDigest: digest,
            codeExpiresAt,
            claimedByUid: null,
            importedByUid: adminUid,
            importId: requestId,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          });
          tx.create(db.doc(`schoolRosterCodes/${digest}`), {
            rosterId: row.rosterId,
            schoolId: admin.schoolId,
            claimedByUid: null,
            codeExpiresAt,
            createdAt: FieldValue.serverTimestamp(),
          });
          generatedCredentials.push({
            maskedLrn: row.maskedLrn ?? '••••••••••••',
            fullName: row.fullName,
            gradeLevel: row.gradeLevel,
            enrollmentCode: code,
          });
          newCount++;
        }
      }

      const nextIdx = offset + chunk.length;
      const done = nextIdx >= rows.length;
      tx.update(importRef, {
        lastCommittedIndex: nextIdx,
        committedCount: newCount + updatedCount,
        newCount,
        updatedCount,
        status: done ? 'completed' : 'in_progress',
        ...(done ? {completedAt: FieldValue.serverTimestamp()} : {}),
      });
      if (done) {
        tx.update(previewRef, {
          consumed: true,
          rows: [],
          consumedAt: FieldValue.serverTimestamp(),
        });
        tx.create(
          db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
          auditRecord({
            actorUid: adminUid,
            actorRole: admin.role,
            schoolId: admin.schoolId,
            action: 'commit_roster_import',
            targetUid: requestId,
            outcome: 'allowed',
          }),
        );
      }
    });
  }

  return {
    importId: requestId,
    status: 'completed',
    committedCount: newCount + updatedCount,
    newCount,
    updatedCount,
    generatedCredentials,
  };
});

export const listSchoolRosterImports = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  keys(object(request.data ?? {}), []);

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  const snap = await db
    .collection('schoolRosterImports')
    .where('schoolId', '==', admin.schoolId)
    .get();

  const items = snap.docs.map((doc) => {
    const d = doc.data();
    const ts = d.completedAt ?? d.startedAt;
    const ms =
      ts instanceof Timestamp
        ? ts.toMillis()
        : ts instanceof Date
          ? ts.getTime()
          : 0;
    return {
      importId: doc.id,
      fileName: typeof d.fileName === 'string' ? d.fileName : 'SF1 Import',
      confirmedGradeLevel:
        typeof d.confirmedGradeLevel === 'string' ? d.confirmedGradeLevel : '',
      status: typeof d.status === 'string' ? d.status : 'completed',
      committedCount: Number(d.committedCount ?? 0),
      newCount: Number(d.newCount ?? 0),
      updatedCount: Number(d.updatedCount ?? 0),
      ms,
      timestamp: ms > 0 ? new Date(ms).toISOString() : new Date(0).toISOString(),
    };
  });

  items.sort((a, b) => b.ms - a.ms);
  return {
    imports: items.slice(0, 20).map(({ms: _m, ...rest}) => rest),
  };
});

const ROSTER_CLAIM_ID_PATTERN = /^[a-f0-9]{64}$/;

export const reissueRosterEnrollmentCode = onCall(resqmeRuntimeOptions, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError('unauthenticated', 'Sign in is required.');
  const data = object(request.data);
  keys(data, ['rosterId']);

  if (typeof data.rosterId !== 'string' || !ROSTER_CLAIM_ID_PATTERN.test(data.rosterId)) {
    throw new HttpsError('invalid-argument', 'Invalid roster entry ID.');
  }
  const rosterId = data.rosterId;

  const db = staffManagementDeps.db(adminUid);
  const admin = await requireMasterAdmin(
    db,
    adminUid,
    request.auth?.token.email_verified === true,
  );

  await enforceTransactionalRateLimit(
    db,
    `staffRosterCodeReissueRateLimits/${adminUid}`,
    30,
    'Too many enrollment code requests. Wait before trying again.',
  );

  const key = process.env.RESQME_SCHOOL_ROSTER_HMAC_KEY;
  if (!key || Buffer.byteLength(key, 'utf8') < 32) {
    throw new HttpsError('failed-precondition', 'Roster lookup key is not configured.');
  }

  return db.runTransaction(async (tx) => {
    const ref = db.doc(`schoolRosterClaims/${rosterId}`);
    const snap = await tx.get(ref);
    const row = snap.data();
    if (!snap.exists || !row || row.schoolId !== admin.schoolId) {
      throw new HttpsError('permission-denied', 'Roster entry is unavailable for this school.');
    }
    if (typeof row.claimedByUid === 'string' && row.claimedByUid.length > 0) {
      throw new HttpsError(
        'failed-precondition',
        'This student has already registered and claimed their roster slot.',
      );
    }

    const oldDigest = row.enrollmentCodeDigest;
    const code = generateEnrollmentCode();
    const digest = rosterCodeDigest(code, key);
    const codeExpiresAt = Date.now() + ENROLLMENT_CODE_TTL_MS;

    if (typeof oldDigest === 'string' && oldDigest.length > 0) {
      tx.set(
        db.doc(`schoolRosterCodes/${oldDigest}`),
        {revoked: true, revokedAt: FieldValue.serverTimestamp()},
        {merge: true},
      );
    }
    tx.update(ref, {
      enrollmentCodeDigest: digest,
      codeExpiresAt,
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.create(db.doc(`schoolRosterCodes/${digest}`), {
      rosterId,
      schoolId: admin.schoolId,
      claimedByUid: null,
      codeExpiresAt,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.create(
      db.doc(`staffManagementAudits/${randomBytes(16).toString('hex')}`),
      auditRecord({
        actorUid: adminUid,
        actorRole: admin.role,
        schoolId: admin.schoolId,
        action: 'reissue_roster_enrollment_code',
        targetUid: rosterId,
        outcome: 'allowed',
      }),
    );

    return {
      maskedLrn: maskLrn(row.lrn) ?? '••••••••••••',
      fullName: typeof row.fullName === 'string' ? row.fullName : 'Student',
      gradeLevel: typeof row.gradeLevel === 'string' ? row.gradeLevel : '',
      enrollmentCode: code,
    };
  });
});
