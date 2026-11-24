import assert from 'node:assert/strict';
import {createHash, generateKeyPairSync, sign} from 'node:crypto';
import test from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';
import type {CallableRequest} from 'firebase-functions/v2/https';
import {issueStaffEnrollmentChallenge} from '../src/staff/issue_staff_enrollment_challenge';
import {enrollStaffTier2Device} from '../src/staff/enroll_staff_tier2_device';
import {revokeStaffTier2Device} from '../src/staff/revoke_staff_tier2_device';
import {
  assertAttestationSerialsNotRevoked,
  resetAttestationStatusCacheForTest,
  resolveAttestationStatusUrl,
  setApprovedSigningDigestsForTest,
  setAttestationStatusFetcherForTest,
  setTrustedAttestationRootHashesForTest,
  verifyAndroidKeyAttestation,
} from '../src/staff/staff_attestation';

const authorization = require('../src/onboarding/authorization') as typeof import('../src/onboarding/authorization');

// Minimal DER/X.509 v3 certificate generator for deterministic offline attestation unit tests.
function derLen(len: number): Buffer {
  if (len < 0x80) return Buffer.from([len]);
  const bytes: number[] = [];
  let n = len;
  while (n > 0) {
    bytes.unshift(n & 0xff);
    n >>= 8;
  }
  return Buffer.from([0x80 | bytes.length, ...bytes]);
}
function derTag(tag: number, content: Buffer): Buffer {
  return Buffer.concat([Buffer.from([tag]), derLen(content.length), content]);
}
function derSeq(items: Buffer[]): Buffer {
  return derTag(0x30, Buffer.concat(items));
}
function derInt(value: number): Buffer {
  if (value === 0) return derTag(0x02, Buffer.from([0]));
  const bytes: number[] = [];
  let n = value;
  while (n > 0) {
    bytes.unshift(n & 0xff);
    n >>= 8;
  }
  if (bytes[0] & 0x80) bytes.unshift(0);
  return derTag(0x02, Buffer.from(bytes));
}
function derEnum(value: number): Buffer {
  return derTag(0x0a, Buffer.from([value]));
}
function derOctet(buf: Buffer): Buffer {
  return derTag(0x04, buf);
}
function derBitString(buf: Buffer): Buffer {
  return derTag(0x03, Buffer.concat([Buffer.from([0]), buf]));
}
function derOid(oid: string): Buffer {
  const parts = oid.split('.').map(Number);
  const out = [parts[0] * 40 + parts[1]];
  for (let i = 2; i < parts.length; i++) {
    let v = parts[i];
    const enc = [v & 0x7f];
    v >>= 7;
    while (v > 0) {
      enc.unshift((v & 0x7f) | 0x80);
      v >>= 7;
    }
    out.push(...enc);
  }
  return derTag(0x06, Buffer.from(out));
}
function derContext(tagNumber: number, content: Buffer): Buffer {
  if (tagNumber < 31) {
    return derTag(0xa0 | tagNumber, content);
  }
  const bytes: number[] = [];
  let n = tagNumber;
  bytes.unshift(n & 0x7f);
  n >>= 7;
  while (n > 0) {
    bytes.unshift((n & 0x7f) | 0x80);
    n >>= 7;
  }
  return Buffer.concat([Buffer.from([0xbf, ...bytes]), derLen(content.length), content]);
}
function derUtcTime(date: Date): Buffer {
  const pad = (v: number) => String(v).padStart(2, '0');
  const s =
    pad(date.getUTCFullYear() % 100) +
    pad(date.getUTCMonth() + 1) +
    pad(date.getUTCDate()) +
    pad(date.getUTCHours()) +
    pad(date.getUTCMinutes()) +
    pad(date.getUTCSeconds()) +
    'Z';
  return derTag(0x17, Buffer.from(s, 'ascii'));
}
const TEST_SIGNING_DIGEST_BYTES = Buffer.alloc(32, 3);
const TEST_SIGNING_DIGEST_HEX = TEST_SIGNING_DIGEST_BYTES.toString('hex');

function buildAttestationExtension(opts: {
  challenge: Buffer;
  attestationLevel: number;
  keymasterLevel: number;
  noAuthRequired?: boolean;
  userAuthType?: number;
  authTimeout?: number;
  origin?: number;
  purpose?: number;
  deviceLocked?: boolean;
  verifiedBootState?: number;
  packageName?: string;
  signingDigest?: Buffer | null;
}): Buffer {
  const teeTags: Buffer[] = [];
  teeTags.push(derContext(1, derTag(0x31, derInt(opts.purpose ?? 2)))); // purpose: SIGN (2)
  if (opts.noAuthRequired) teeTags.push(derContext(503, derTag(0x05, Buffer.alloc(0))));
  if (opts.userAuthType !== undefined) teeTags.push(derContext(504, derInt(opts.userAuthType)));
  if (opts.authTimeout !== undefined) teeTags.push(derContext(505, derInt(opts.authTimeout)));
  teeTags.push(derContext(702, derInt(opts.origin ?? 0))); // origin: GENERATED (0)
  const rootOfTrust = derSeq([
    derOctet(Buffer.alloc(32, 1)), // verifiedBootKey
    derTag(0x01, Buffer.from([opts.deviceLocked === false ? 0x00 : 0xff])), // deviceLocked
    derEnum(opts.verifiedBootState ?? 0), // verifiedBootState: Verified (0)
    derOctet(Buffer.alloc(32, 2)), // verifiedBootHash
  ]);
  teeTags.push(derContext(704, rootOfTrust));

  const swTags: Buffer[] = [];
  if (opts.packageName !== '') {
    const pkg = opts.packageName ?? 'com.example.resqme.admin';
    const digestSet =
      opts.signingDigest === null
        ? derTag(0x31, Buffer.alloc(0))
        : derTag(0x31, derOctet(opts.signingDigest ?? TEST_SIGNING_DIGEST_BYTES));
    const appId = derSeq([
      derTag(0x31, derSeq([derOctet(Buffer.from(pkg, 'utf8')), derInt(1)])),
      digestSet,
    ]);
    swTags.push(derContext(709, derOctet(appId)));
  }

  const keyDescription = derSeq([
    derInt(4), // attestationVersion
    derEnum(opts.attestationLevel),
    derInt(41), // keymasterVersion
    derEnum(opts.keymasterLevel),
    derOctet(opts.challenge),
    derOctet(Buffer.alloc(0)), // uniqueId
    derSeq(swTags), // softwareEnforced
    derSeq(teeTags), // teeEnforced
  ]);
  return derSeq([derOid('1.3.6.1.4.1.11129.2.1.17'), derOctet(keyDescription)]);
}
function buildSignedCert(opts: {
  subjectCn: string;
  issuerCn: string;
  subjectSpki: Buffer;
  issuerPrivateKey: ReturnType<typeof generateKeyPairSync>['privateKey'];
  notBefore: Date;
  notAfter: Date;
  extensions?: Buffer[];
}): Buffer {
  const sigAlg = derSeq([derOid('1.2.840.10045.4.3.2')]); // ecdsa-with-SHA256
  const name = (cn: string) =>
    derSeq([derTag(0x31, derSeq([derOid('2.5.4.3'), derTag(0x0c, Buffer.from(cn, 'utf8'))]))]);
  const tbsItems = [
    derContext(0, derInt(2)), // v3
    derInt(Math.floor(Math.random() * 1_000_000) + 1),
    sigAlg,
    name(opts.issuerCn),
    derSeq([derUtcTime(opts.notBefore), derUtcTime(opts.notAfter)]),
    name(opts.subjectCn),
    opts.subjectSpki,
  ];
  if (opts.extensions && opts.extensions.length > 0) {
    tbsItems.push(derContext(3, derSeq(opts.extensions)));
  }
  const tbs = derSeq(tbsItems);
  const sig = sign('sha256', tbs, opts.issuerPrivateKey);
  return derSeq([tbs, sigAlg, derBitString(sig)]);
}

function makeChain(opts: {
  challenge: Buffer;
  attestationLevel?: number;
  keymasterLevel?: number;
  noAuthRequired?: boolean;
  userAuthType?: number;
  authTimeout?: number;
  origin?: number;
  purpose?: number;
  deviceLocked?: boolean;
  verifiedBootState?: number;
  packageName?: string;
  signingDigest?: Buffer | null;
  tamperRoot?: boolean;
}) {
  const root = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
  const leaf = generateKeyPairSync('ec', {namedCurve: 'prime256v1'});
  const now = Date.now();
  const rootSpki = root.publicKey.export({type: 'spki', format: 'der'});
  const leafSpki = leaf.publicKey.export({type: 'spki', format: 'der'});
  const rootCert = buildSignedCert({
    subjectCn: 'Test Attestation Root',
    issuerCn: 'Test Attestation Root',
    subjectSpki: rootSpki,
    issuerPrivateKey: root.privateKey,
    notBefore: new Date(now - 60_000),
    notAfter: new Date(now + 86_400_000),
  });
  const ext = buildAttestationExtension({
    challenge: opts.challenge,
    attestationLevel: opts.attestationLevel ?? 1,
    keymasterLevel: opts.keymasterLevel ?? 1,
    noAuthRequired: opts.noAuthRequired,
    userAuthType: opts.userAuthType ?? 2,
    authTimeout: opts.authTimeout,
    origin: opts.origin,
    purpose: opts.purpose,
    deviceLocked: opts.deviceLocked,
    verifiedBootState: opts.verifiedBootState,
    packageName: opts.packageName,
    signingDigest: opts.signingDigest,
  });
  const leafCert = buildSignedCert({
    subjectCn: 'Android Keystore Key',
    issuerCn: 'Test Attestation Root',
    subjectSpki: leafSpki,
    issuerPrivateKey: opts.tamperRoot ? leaf.privateKey : root.privateKey,
    notBefore: new Date(now - 60_000),
    notAfter: new Date(now + 86_400_000),
    extensions: [ext],
  });
  const rootHash = createHash('sha256').update(rootSpki).digest('hex');
  return {
    publicKey: leafSpki.toString('base64url'),
    attestationChain: [leafCert.toString('base64url'), rootCert.toString('base64url')],
    rootHash,
  };
}

function mockDb(entries: Array<[string, Record<string, unknown>]>) {
  const rows = new Map<string, Record<string, unknown>>(entries);
  const read = async (path: string) => {
    const data = rows.get(path);
    return {
      exists: data !== undefined,
      data: () => (data ? {...data} : undefined),
      get: (field: string) => (data ? data[field] : undefined),
    };
  };
  return {
    rows,
    db: {
      doc: (path: string) => ({path, get: () => read(path)}),
      async runTransaction<T>(action: (tx: unknown) => Promise<T>) {
        const pending: Array<() => void> = [];
        const tx = {
          get: (ref: {path: string}) => read(ref.path),
          create: (ref: {path: string}, data: Record<string, unknown>) => {
            pending.push(() => rows.set(ref.path, {...data}));
          },
          set: (ref: {path: string}, data: Record<string, unknown>) => {
            pending.push(() => rows.set(ref.path, {...data}));
          },
          update: (ref: {path: string}, patch: Record<string, unknown>) => {
            pending.push(() => rows.set(ref.path, {...rows.get(ref.path), ...patch}));
          },
        };
        const result = await action(tx);
        for (const fn of pending) fn();
        return result;
      },
    },
  };
}

function req(uid: string | undefined, data: unknown, authTime = Math.floor(Date.now() / 1000)) {
  return {
    auth: uid ? {uid, token: {auth_time: authTime}} : undefined,
    data,
  } as unknown as CallableRequest;
}

test('verifyAndroidKeyAttestation enforces signing digest, revocation status, bounded cache, and hardware policy', async () => {
  const challenge = Buffer.from('fictional-nonce-bytes-1234567890', 'utf8');
  const valid = makeChain({challenge, attestationLevel: 1, keymasterLevel: 1, userAuthType: 2});
  setTrustedAttestationRootHashesForTest([valid.rootHash]);
  setApprovedSigningDigestsForTest([TEST_SIGNING_DIGEST_HEX]);
  setAttestationStatusFetcherForTest(async () => ({entries: {}}));
  resetAttestationStatusCacheForTest();
  try {
    const verified = await verifyAndroidKeyAttestation({
      publicKey: valid.publicKey,
      attestationChain: valid.attestationChain,
      expectedChallenge: challenge,
    });
    assert.equal(verified.securityLevel, 'trusted_environment');
    assert.equal(verified.certificateSerials.length, 2);

    // Wrong signing-certificate digest must deny
    const wrongSigner = makeChain({challenge, signingDigest: Buffer.alloc(32, 9)});
    setTrustedAttestationRootHashesForTest([wrongSigner.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: wrongSigner.publicKey, attestationChain: wrongSigner.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    // Missing signing digest must deny
    const noSigner = makeChain({challenge, signingDigest: null});
    setTrustedAttestationRootHashesForTest([noSigner.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: noSigner.publicKey, attestationChain: noSigner.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    // Revoked certificate serial in status list must deny
    setTrustedAttestationRootHashesForTest([valid.rootHash]);
    resetAttestationStatusCacheForTest();
    setAttestationStatusFetcherForTest(async () => ({
      entries: {[verified.certificateSerials[0]]: {status: 'REVOKED', reason: 'KEY_COMPROMISE'}},
    }));
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: valid.publicKey, attestationChain: valid.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    // Unavailable revocation service must fail closed (even if cache was previously warm but now stale)
    const t0 = Date.now();
    resetAttestationStatusCacheForTest();
    setAttestationStatusFetcherForTest(async () => ({entries: {}}));
    await assertAttestationSerialsNotRevoked(verified.certificateSerials, t0);
    // Still within 1h TTL -> uses cache even if fetcher would fail
    setAttestationStatusFetcherForTest(async () => {
      throw new Error('network-down');
    });
    await assertAttestationSerialsNotRevoked(verified.certificateSerials, t0 + 30 * 60_000);
    // Beyond 1h TTL -> stale cache expires and unavailable fetcher fails closed
    await assert.rejects(
      () => assertAttestationSerialsNotRevoked(verified.certificateSerials, t0 + 61 * 60_000),
      {code: 'permission-denied'},
    );

    // Reset clean fetcher for remaining checks
    resetAttestationStatusCacheForTest();
    setAttestationStatusFetcherForTest(async () => ({entries: {}}));

    const software = makeChain({challenge, attestationLevel: 0, keymasterLevel: 0, userAuthType: 2});
    setTrustedAttestationRootHashesForTest([software.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: software.publicKey, attestationChain: software.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    const noAuth = makeChain({challenge, noAuthRequired: true});
    setTrustedAttestationRootHashesForTest([noAuth.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: noAuth.publicKey, attestationChain: noAuth.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    const wrongChallenge = makeChain({challenge: Buffer.from('other-nonce')});
    setTrustedAttestationRootHashesForTest([wrongChallenge.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: wrongChallenge.publicKey, attestationChain: wrongChallenge.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    const badChain = makeChain({challenge, tamperRoot: true});
    setTrustedAttestationRootHashesForTest([badChain.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: badChain.publicKey, attestationChain: badChain.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    setTrustedAttestationRootHashesForTest(['0'.repeat(64)]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: valid.publicKey, attestationChain: valid.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    const wrongApp = makeChain({challenge, packageName: 'com.evil.otherapp'});
    setTrustedAttestationRootHashesForTest([wrongApp.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: wrongApp.publicKey, attestationChain: wrongApp.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    const importedKey = makeChain({challenge, origin: 2});
    setTrustedAttestationRootHashesForTest([importedKey.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: importedKey.publicKey, attestationChain: importedKey.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    const unlockedBoot = makeChain({challenge, deviceLocked: false});
    setTrustedAttestationRootHashesForTest([unlockedBoot.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: unlockedBoot.publicKey, attestationChain: unlockedBoot.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );

    const wrongPurpose = makeChain({challenge, purpose: 1});
    setTrustedAttestationRootHashesForTest([wrongPurpose.rootHash]);
    await assert.rejects(
      () => verifyAndroidKeyAttestation({publicKey: wrongPurpose.publicKey, attestationChain: wrongPurpose.attestationChain, expectedChallenge: challenge}),
      {code: 'permission-denied'},
    );
  } finally {
    setTrustedAttestationRootHashesForTest(null);
    setApprovedSigningDigestsForTest(null);
    setAttestationStatusFetcherForTest(null);
    resetAttestationStatusCacheForTest();
  }
});

test('resolveAttestationStatusUrl permits loopback override strictly in demo-resqme emulator', () => {
  assert.equal(
    resolveAttestationStatusUrl({
      GCLOUD_PROJECT: 'resqme-943ee',
      FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
      RESQME_ATTESTATION_STATUS_URL: 'http://127.0.0.1:18199/status',
    }),
    'https://android.googleapis.com/attestation/status',
  );
  assert.equal(
    resolveAttestationStatusUrl({
      GCLOUD_PROJECT: 'demo-resqme',
      FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
      RESQME_ATTESTATION_STATUS_URL: 'https://evil.example/status',
    }),
    'https://android.googleapis.com/attestation/status',
  );
  assert.equal(
    resolveAttestationStatusUrl({
      GCLOUD_PROJECT: 'demo-resqme',
      FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
      RESQME_ATTESTATION_STATUS_URL: 'http://127.0.0.1:18199/status',
    }),
    'http://127.0.0.1:18199/status',
  );
});

test('staff enrollment requires fresh auth, active staff, one-time attested challenge, and replaces prior key atomically', async (t) => {
  const state = mockDb([
    ['staffAccounts/staff-1', {role: 'authorized', active: true, schoolId: 'pilot-school-1'}],
    ['staffAccounts/inactive-1', {role: 'authorized', active: false, schoolId: 'pilot-school-1'}],
  ]);
  t.mock.method(authorization, 'onboardingDatabase', () => state.db as never);

  const stale = Math.floor(Date.now() / 1000) - 300;
  await assert.rejects(() => issueStaffEnrollmentChallenge.run(req(undefined, {})), {code: 'unauthenticated'});
  await assert.rejects(() => issueStaffEnrollmentChallenge.run(req('staff-1', {}, stale)), {code: 'failed-precondition'});
  await assert.rejects(() => issueStaffEnrollmentChallenge.run(req('inactive-1', {})), {code: 'permission-denied'});

  const issued = await issueStaffEnrollmentChallenge.run(req('staff-1', {})) as {challengeId: string; nonce: string};
  assert.ok(issued.challengeId.length >= 32);
  const storedChallenge = state.rows.get(`staffEnrollmentChallenges/${issued.challengeId}`)!;
  // Simulate Firestore Timestamp stored by Admin SDK
  storedChallenge.expiresAt = Timestamp.fromMillis(Date.now() + 60_000);

  const chain1 = makeChain({challenge: Buffer.from(issued.nonce, 'base64url')});
  setTrustedAttestationRootHashesForTest([chain1.rootHash]);
  setApprovedSigningDigestsForTest([TEST_SIGNING_DIGEST_HEX]);
  setAttestationStatusFetcherForTest(async () => ({entries: {}}));
  resetAttestationStatusCacheForTest();
  try {
    const enrolled = await enrollStaffTier2Device.run(req('staff-1', {
      challengeId: issued.challengeId,
      deviceId: 'staff_device_0123456789abc',
      publicKey: chain1.publicKey,
      attestationChain: chain1.attestationChain,
    }));
    assert.deepEqual(enrolled, {deviceId: 'staff_device_0123456789abc', status: 'active', keyVersion: 1});
    assert.equal(Array.isArray(state.rows.get('staffTier2Devices/staff-1')?.attestationSerials), true);

    // Replay of same challenge must fail
    await assert.rejects(() => enrollStaffTier2Device.run(req('staff-1', {
      challengeId: issued.challengeId,
      deviceId: 'staff_device_0123456789abc',
      publicKey: chain1.publicKey,
      attestationChain: chain1.attestationChain,
    })), {code: 'permission-denied'});

    // Revoke succeeds for owner with fresh auth
    const revoked = await revokeStaffTier2Device.run(req('staff-1', {}));
    assert.deepEqual(revoked, {status: 'revoked'});
    assert.equal(state.rows.get('staffTier2Devices/staff-1')?.status, 'revoked');
  } finally {
    setTrustedAttestationRootHashesForTest(null);
    setApprovedSigningDigestsForTest(null);
    setAttestationStatusFetcherForTest(null);
    resetAttestationStatusCacheForTest();
  }
});
