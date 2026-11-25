import assert from 'node:assert/strict';
import test from 'node:test';
import {staffManagementDeps, type StaffAdminAuthPort} from '../src/staff/staff_account_management';
import {listSchoolActivityLogs} from '../src/staff/staff_activity_logs';

test('Phase 6: listSchoolActivityLogs enriches actorDisplayName + role, filters dates in Asia/Manila (UTC+08:00), supports failed outcome, and enforces strict redaction allowlist', async (t) => {
  const rows = new Map<string, Record<string, unknown>>([
    [
      'staffAccounts/admin-p6',
      {
        schoolId: 'school-p6',
        role: 'admin',
        isMasterAdmin: true,
        active: true,
        mustChangePassword: false,
        requiresEmailVerification: true,
        fullName: 'Principal Elena Cruz',
      },
    ],
    [
      'staffAccounts/nurse-p6',
      {
        schoolId: 'school-p6',
        role: 'authorized',
        isMasterAdmin: false,
        active: true,
        mustChangePassword: false,
        fullName: 'Nurse Marco Tan',
      },
    ],
    // 2026-11-25T20:30:00Z == 2026-11-26 04:30:00 Asia/Manila!
    [
      'staffManagementAudits/ev-pht-boundary',
      {
        schoolId: 'school-p6',
        actorUid: 'admin-p6',
        actorRole: 'admin',
        action: 'reset_student_trusted_device',
        targetUid: 'stu-p6-1',
        reason: 'school_verified_recovery',
        outcome: 'allowed',
        secretRawToken: 'MUST_NEVER_LEAK',
        createdAt: new Date('2026-11-25T20:30:00.000Z'),
      },
    ],
    [
      'staffManagementAudits/ev-failed-import',
      {
        schoolId: 'school-p6',
        actorUid: 'admin-p6',
        actorRole: 'admin',
        action: 'commit_roster_import',
        targetUid: 'imp-failed-1',
        reason: 'validation_failed',
        outcome: 'failed',
        createdAt: new Date('2026-11-25T05:00:00.000Z'),
      },
    ],
    [
      'tier2AccessAudits/ev-tier2-scan',
      {
        schoolId: 'school-p6',
        actorUid: 'nurse-p6',
        actorRole: 'authorized',
        targetUid: 'stu-p6-1',
        purpose: 'clinic_triage',
        outcome: 'allowed',
        conditions: {state: 'listed', details: 'PRIVATE_MEDICAL_DETAIL'},
        recordedAt: new Date('2026-11-25T06:15:00.000Z'),
      },
    ],
  ]);

  const docRef = (path: string) => ({
    path,
    id: path.split('/').pop()!,
    async get() {
      const data = rows.get(path);
      return {
        id: path.split('/').pop()!,
        exists: data !== undefined,
        data: () => data,
        get: (field: string) => data?.[field],
      };
    },
  });

  const db = {
    doc: docRef,
    collection(col: string) {
      const filters: Array<[string, unknown]> = [];
      const q = {
        where(f: string, _op: string, v: unknown) {
          filters.push([f, v]);
          return q;
        },
        async get() {
          const docs = [...rows.entries()]
            .filter(([p]) => p.startsWith(`${col}/`) && p.split('/').length === 2)
            .filter(([, d]) => filters.every(([f, v]) => d[f] === v))
            .map(([p, d]) => ({
              id: p.split('/').pop()!,
              ref: docRef(p),
              data: () => ({...d}),
              get: (k: string) => d[k],
            }));
          return {docs, empty: docs.length === 0, size: docs.length};
        },
      };
      return q;
    },
  };

  t.mock.method(staffManagementDeps, 'db', () => db as never);
  t.mock.method(staffManagementDeps, 'auth', () => ({}) as StaffAdminAuthPort);

  const authReq = (data: unknown) =>
    ({
      auth: {uid: 'admin-p6', token: {email_verified: true}},
      data,
      rawRequest: {},
    }) as never;

  const allRes = (await listSchoolActivityLogs.run(authReq({}))) as {
    entries: Array<Record<string, unknown>>;
    totalMatched: number;
  };
  assert.equal(allRes.totalMatched, 3);
  assert.equal(allRes.entries[0].actorDisplayName, 'Principal Elena Cruz');
  assert.equal(allRes.entries[0].manilaDate, '2026-11-26');
  assert.equal(allRes.entries[1].actorDisplayName, 'Nurse Marco Tan');
  assert.equal(JSON.stringify(allRes).includes('MUST_NEVER_LEAK'), false);
  assert.equal(JSON.stringify(allRes).includes('PRIVATE_MEDICAL_DETAIL'), false);

  // Asia/Manila date filter: 2026-11-25T20:30:00Z is 2026-11-26 in Manila!
  const manilaNov26 = (await listSchoolActivityLogs.run(
    authReq({startDate: '2026-11-26', endDate: '2026-11-26'}),
  )) as {entries: Array<{id: string}>};
  assert.deepEqual(manilaNov26.entries.map((e) => e.id), ['ev-pht-boundary']);

  // Outcome = 'failed' filter
  const failedOnly = (await listSchoolActivityLogs.run(
    authReq({outcome: 'failed'}),
  )) as {entries: Array<{id: string; outcome: string}>};
  assert.equal(failedOnly.entries.length, 1);
  assert.equal(failedOnly.entries[0].id, 'ev-failed-import');
  assert.equal(failedOnly.entries[0].outcome, 'failed');
});
