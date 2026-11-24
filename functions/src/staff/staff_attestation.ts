import {createHash, createPublicKey, timingSafeEqual, X509Certificate} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';

// Google Hardware Attestation Root SPKI SHA-256 fingerprints (RSA-4096 & EC-P384 roots).
// Additional rotated roots can be supplied via RESQME_ATTESTATION_ROOT_SHA256 (comma-separated 64-hex).
const DEFAULT_TRUSTED_ROOT_SPKI_SHA256: readonly string[] = [
  '2549b3923e8f618f0284c048b99dc0c11a84935455d1c08d376c6282a45269f5',
  '9a2520f2a0e7a2b561517d9a71992593263d3f9c022a7a3e640b9921d803e060',
  'f97e83f629a1f7b1f0909f74383b4a13c542b33015c0c98a6f7509d560728f8e',
];

const ATTESTATION_STATUS_URL = 'https://android.googleapis.com/attestation/status';
const MAX_STATUS_CACHE_AGE_MS = 60 * 60 * 1000; // 1 hour bounded cache; stale data fails closed.
const FETCH_TIMEOUT_MS = 5000;
const HEX64_PATTERN = /^[a-f0-9]{64}$/;
const SERIAL_PATTERN = /^[a-f0-9]{1,64}$/;

export interface AttestationStatusEntry {
  status?: unknown;
  reason?: unknown;
}

export interface AttestationStatusPayload {
  entries: Record<string, AttestationStatusEntry>;
}

export type AttestationStatusFetcher = () => Promise<AttestationStatusPayload>;

let testRootOverrides: readonly string[] | null = null;
let testSigningDigestOverrides: readonly string[] | null = null;
let testStatusFetcher: AttestationStatusFetcher | null = null;
let cachedStatus: {entries: Record<string, AttestationStatusEntry>; fetchedAtMs: number} | null = null;

export function setTrustedAttestationRootHashesForTest(hashes: readonly string[] | null): void {
  testRootOverrides = hashes;
}

export function setApprovedSigningDigestsForTest(digests: readonly string[] | null): void {
  testSigningDigestOverrides = digests;
}

export function setAttestationStatusFetcherForTest(fetcher: AttestationStatusFetcher | null): void {
  testStatusFetcher = fetcher;
}

export function resetAttestationStatusCacheForTest(): void {
  cachedStatus = null;
}

function parseHex64List(raw: string | undefined): string[] {
  if (!raw || !raw.trim()) return [];
  const items = raw
    .split(',')
    .map((s) => s.trim().toLowerCase().replace(/:/g, ''))
    .filter(Boolean);
  for (const item of items) {
    if (!HEX64_PATTERN.test(item)) {
      throw new HttpsError('failed-precondition', 'Invalid attestation trust configuration.');
    }
  }
  return items;
}

function getTrustedRootHashes(): readonly string[] {
  if (testRootOverrides !== null) return testRootOverrides;
  const extra = parseHex64List(process.env.RESQME_ATTESTATION_ROOT_SHA256);
  return extra.length > 0 ? [...DEFAULT_TRUSTED_ROOT_SPKI_SHA256, ...extra] : DEFAULT_TRUSTED_ROOT_SPKI_SHA256;
}

function getApprovedSigningDigests(): readonly string[] {
  if (testSigningDigestOverrides !== null) return testSigningDigestOverrides;
  const configured = parseHex64List(process.env.RESQME_ADMIN_SIGNING_CERT_SHA256);
  if (configured.length === 0) {
    throw new HttpsError('permission-denied', 'Admin signing certificate allowlist is not configured.');
  }
  return configured;
}

export function normalizeSerialHex(serial: string): string {
  const cleaned = serial.trim().toLowerCase().replace(/:/g, '').replace(/^0+/, '');
  return cleaned.length > 0 ? cleaned : '0';
}

export function resolveAttestationStatusUrl(env: NodeJS.ProcessEnv = process.env): string {
  const project = env.GCLOUD_PROJECT || env.GOOGLE_CLOUD_PROJECT;
  const override = env.RESQME_ATTESTATION_STATUS_URL?.trim();
  if (
    project === 'demo-resqme' &&
    typeof env.FIRESTORE_EMULATOR_HOST === 'string' &&
    env.FIRESTORE_EMULATOR_HOST.startsWith('127.0.0.1:') &&
    override &&
    /^http:\/\/127\.0\.0\.1:\d{2,5}\/[A-Za-z0-9/_-]*$/.test(override)
  ) {
    return override;
  }
  return ATTESTATION_STATUS_URL;
}

async function defaultFetchAttestationStatus(): Promise<AttestationStatusPayload> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const response = await fetch(resolveAttestationStatusUrl(), {
      method: 'GET',
      headers: {Accept: 'application/json'},
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`status-http-${response.status}`);
    }
    const body = (await response.json()) as unknown;
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      throw new Error('status-malformed');
    }
    const entries = (body as {entries?: unknown}).entries;
    if (!entries || typeof entries !== 'object' || Array.isArray(entries)) {
      throw new Error('status-no-entries');
    }
    return {entries: entries as Record<string, AttestationStatusEntry>};
  } finally {
    clearTimeout(timer);
  }
}

async function getAttestationRevocationEntries(
  nowMs = Date.now(),
): Promise<Record<string, AttestationStatusEntry>> {
  if (cachedStatus && nowMs >= cachedStatus.fetchedAtMs && nowMs - cachedStatus.fetchedAtMs < MAX_STATUS_CACHE_AGE_MS) {
    return cachedStatus.entries;
  }
  // Cache is missing or stale: must refresh; never reuse stale cache on failure.
  cachedStatus = null;
  const fetcher = testStatusFetcher ?? defaultFetchAttestationStatus;
  try {
    const payload = await fetcher();
    if (!payload || typeof payload !== 'object' || !payload.entries || typeof payload.entries !== 'object' || Array.isArray(payload.entries)) {
      throw new Error('status-invalid');
    }
    const normalized: Record<string, AttestationStatusEntry> = {};
    for (const [k, v] of Object.entries(payload.entries)) {
      if (v && typeof v === 'object') {
        normalized[normalizeSerialHex(k)] = v;
      }
    }
    cachedStatus = {entries: normalized, fetchedAtMs: nowMs};
    return normalized;
  } catch {
    throw new HttpsError('permission-denied', 'Device attestation revocation status is unavailable.');
  }
}

export async function assertAttestationSerialsNotRevoked(
  serials: unknown,
  nowMs = Date.now(),
): Promise<void> {
  if (
    !Array.isArray(serials) ||
    serials.length < 2 ||
    serials.length > 8 ||
    serials.some((s) => typeof s !== 'string' || !SERIAL_PATTERN.test(normalizeSerialHex(s)))
  ) {
    throw new HttpsError('permission-denied', 'Device attestation state is invalid.');
  }
  const entries = await getAttestationRevocationEntries(nowMs);
  for (const raw of serials) {
    const key = normalizeSerialHex(raw);
    const entry = entries[key];
    if (entry && entry.status !== 'ACTIVE') {
      throw new HttpsError('permission-denied', 'Device attestation certificate is revoked.');
    }
  }
}

const ANDROID_ATTESTATION_OID_DER = Buffer.from([
  0x06, 0x0a, 0x2b, 0x06, 0x01, 0x04, 0x01, 0xd6, 0x79, 0x02, 0x01, 0x11,
]);

interface DerNode {
  tagClass: number;
  constructed: boolean;
  tagNumber: number;
  headerLength: number;
  content: Buffer;
  endOffset: number;
}

function readDerNode(buf: Buffer, offset: number): DerNode {
  if (offset >= buf.length) throw new Error('truncated');
  const first = buf[offset];
  const tagClass = first >> 6;
  const constructed = (first & 0x20) !== 0;
  let tagNumber = first & 0x1f;
  let cursor = offset + 1;
  if (tagNumber === 0x1f) {
    tagNumber = 0;
    let count = 0;
    while (true) {
      if (cursor >= buf.length || count > 4) throw new Error('bad-tag');
      const b = buf[cursor++];
      tagNumber = (tagNumber << 7) | (b & 0x7f);
      count++;
      if ((b & 0x80) === 0) break;
    }
  }
  if (cursor >= buf.length) throw new Error('truncated-len');
  const lenByte = buf[cursor++];
  let length = 0;
  if ((lenByte & 0x80) === 0) {
    length = lenByte;
  } else {
    const numBytes = lenByte & 0x7f;
    if (numBytes === 0 || numBytes > 4 || cursor + numBytes > buf.length) throw new Error('bad-len');
    for (let i = 0; i < numBytes; i++) {
      length = (length << 8) | buf[cursor++];
    }
  }
  const endOffset = cursor + length;
  if (endOffset > buf.length) throw new Error('overflow');
  return {
    tagClass,
    constructed,
    tagNumber,
    headerLength: cursor - offset,
    content: buf.subarray(cursor, endOffset),
    endOffset,
  };
}

function readDerChildren(buf: Buffer): DerNode[] {
  const nodes: DerNode[] = [];
  let offset = 0;
  while (offset < buf.length) {
    const node = readDerNode(buf, offset);
    nodes.push(node);
    offset = node.endOffset;
  }
  return nodes;
}

function derSmallInt(buf: Buffer): number {
  if (buf.length === 0 || buf.length > 4) throw new Error('bad-int');
  let val = 0;
  for (const b of buf) val = (val << 8) | b;
  return val;
}

function extractAttestationExtensionContent(leafDer: Buffer): Buffer | null {
  const cert = readDerNode(leafDer, 0);
  if (cert.tagClass !== 0 || cert.tagNumber !== 16) return null;
  const certChildren = readDerChildren(cert.content);
  if (certChildren.length < 1) return null;
  const tbs = certChildren[0];
  const tbsChildren = readDerChildren(tbs.content);
  const extWrapper = tbsChildren.find((n) => n.tagClass === 2 && n.tagNumber === 3);
  if (!extWrapper) return null;
  const extSeq = readDerNode(extWrapper.content, 0);
  if (extSeq.tagClass !== 0 || extSeq.tagNumber !== 16) return null;
  for (const ext of readDerChildren(extSeq.content)) {
    if (ext.tagClass !== 0 || ext.tagNumber !== 16) continue;
    const fields = readDerChildren(ext.content);
    if (fields.length < 2) continue;
    const oidRaw = ext.content.subarray(0, fields[0].endOffset);
    if (!oidRaw.equals(ANDROID_ATTESTATION_OID_DER)) continue;
    const valueNode = fields[fields.length - 1];
    if (valueNode.tagClass === 0 && valueNode.tagNumber === 4) {
      return valueNode.content;
    }
  }
  return null;
}

export type AttestationSecurityLevel = 'trusted_environment' | 'strongbox';

export interface VerifiedAttestationResult {
  securityLevel: AttestationSecurityLevel;
  certificateSerials: string[];
}

export async function verifyAndroidKeyAttestation(input: {
  publicKey: string;
  attestationChain: unknown;
  expectedChallenge: Buffer;
  nowMs?: number;
}): Promise<VerifiedAttestationResult> {
  const deny = () => new HttpsError('permission-denied', 'Device key attestation could not be verified.');
  if (!Array.isArray(input.attestationChain) || input.attestationChain.length < 2 || input.attestationChain.length > 8) {
    throw deny();
  }
  const nowMs = input.nowMs ?? Date.now();
  const certs: {x509: X509Certificate; der: Buffer; serial: string}[] = [];
  let securityLevel: AttestationSecurityLevel;
  try {
    const trustedRoots = getTrustedRootHashes();
    const approvedSigningDigests = getApprovedSigningDigests();

    for (const raw of input.attestationChain) {
      if (typeof raw !== 'string' || raw.length === 0 || raw.length > 12_000) throw new Error('cert-str');
      const der = Buffer.from(raw, 'base64url');
      if (der.length === 0 || der.length > 8192) throw new Error('cert-len');
      const x509 = new X509Certificate(der);
      const notBefore = Date.parse(x509.validFrom);
      const notAfter = Date.parse(x509.validTo);
      if (!Number.isFinite(notBefore) || !Number.isFinite(notAfter) || nowMs < notBefore || nowMs > notAfter) {
        throw new Error('cert-expired');
      }
      const serial = normalizeSerialHex(x509.serialNumber);
      if (!SERIAL_PATTERN.test(serial)) throw new Error('bad-serial');
      certs.push({x509, der, serial});
    }

    // 1. Leaf public key must match submitted EC P-256 publicKey
    const submittedDer = Buffer.from(input.publicKey, 'base64url');
    const submittedKey = createPublicKey({key: submittedDer, format: 'der', type: 'spki'});
    if (submittedKey.asymmetricKeyType !== 'ec' || submittedKey.asymmetricKeyDetails?.namedCurve !== 'prime256v1') {
      throw new Error('key-type');
    }
    const leafSpki = certs[0].x509.publicKey.export({type: 'spki', format: 'der'});
    if (!leafSpki.equals(submittedDer)) throw new Error('leaf-mismatch');

    // 2. Verify certificate chain signatures and self-signed root
    for (let i = 0; i < certs.length - 1; i++) {
      if (!certs[i].x509.verify(certs[i + 1].x509.publicKey)) throw new Error('chain-sig');
    }
    const rootCert = certs[certs.length - 1].x509;
    if (!rootCert.verify(rootCert.publicKey)) throw new Error('root-sig');

    // 3. Verify root trust anchor (supports root rotation via env)
    const rootSpki = rootCert.publicKey.export({type: 'spki', format: 'der'});
    const rootHash = createHash('sha256').update(rootSpki).digest('hex');
    if (!trustedRoots.includes(rootHash)) throw new Error('untrusted-root');

    // 4. Parse Android Key Attestation extension (1.3.6.1.4.1.11129.2.1.17)
    const extContent = extractAttestationExtensionContent(certs[0].der);
    if (!extContent) throw new Error('no-ext');
    const keyDesc = readDerNode(extContent, 0);
    if (keyDesc.tagClass !== 0 || keyDesc.tagNumber !== 16) throw new Error('bad-desc');
    const fields = readDerChildren(keyDesc.content);
    if (fields.length < 8) throw new Error('short-desc');

    const attestationLevel = derSmallInt(fields[1].content);
    const keymasterLevel = derSmallInt(fields[3].content);
    if ((attestationLevel !== 1 && attestationLevel !== 2) || (keymasterLevel !== 1 && keymasterLevel !== 2)) {
      throw new Error('software-level');
    }

    const challengeNode = fields[4];
    if (
      challengeNode.tagClass !== 0 ||
      challengeNode.tagNumber !== 4 ||
      challengeNode.content.length !== input.expectedChallenge.length ||
      !timingSafeEqual(challengeNode.content, input.expectedChallenge)
    ) {
      throw new Error('challenge-mismatch');
    }

    // 5. Verify application identity AND approved signing-certificate SHA-256 digest (softwareEnforced tag 709)
    const swEnforced = fields[6];
    if (swEnforced.tagClass !== 0 || swEnforced.tagNumber !== 16) throw new Error('bad-sw');
    let matchedPackage = false;
    let matchedSigner = false;
    for (const tag of readDerChildren(swEnforced.content)) {
      if (tag.tagClass === 2 && tag.tagNumber === 709) {
        const octet = readDerNode(tag.content, 0);
        if (octet.tagClass !== 0 || octet.tagNumber !== 4) throw new Error('bad-app-id');
        const appIdSeq = readDerNode(octet.content, 0);
        const appIdFields = readDerChildren(appIdSeq.content);
        if (appIdFields.length < 2) throw new Error('bad-app-id-seq');
        for (const pkgInfo of readDerChildren(appIdFields[0].content)) {
          const pkgFields = readDerChildren(pkgInfo.content);
          if (pkgFields.length >= 1 && pkgFields[0].content.toString('utf8') === 'com.example.resqme.admin') {
            matchedPackage = true;
          }
        }
        for (const sigDigest of readDerChildren(appIdFields[1].content)) {
          if (sigDigest.tagClass === 0 && sigDigest.tagNumber === 4 && sigDigest.content.length === 32) {
            const hex = sigDigest.content.toString('hex');
            if (approvedSigningDigests.includes(hex)) {
              matchedSigner = true;
            }
          }
        }
      }
    }
    if (!matchedPackage || !matchedSigner) throw new Error('wrong-app-or-signer');

    // 6. Verify hardware-enforced (teeEnforced) origin, purpose, verified boot, and per-use strong biometric policy
    const teeEnforced = fields[7];
    if (teeEnforced.tagClass !== 0 || teeEnforced.tagNumber !== 16) throw new Error('bad-tee');
    const teeTags = readDerChildren(teeEnforced.content);
    let hasNoAuthRequired = false;
    let userAuthType: number | null = null;
    let authTimeout: number | null = null;
    let hasSignPurpose = false;
    let keyOrigin: number | null = null;
    let verifiedBootOk = false;
    for (const tag of teeTags) {
      if (tag.tagClass !== 2) continue;
      if (tag.tagNumber === 1) {
        const purposeSet = readDerNode(tag.content, 0);
        for (const p of readDerChildren(purposeSet.content)) {
          if (derSmallInt(p.content) === 2) hasSignPurpose = true;
        }
      }
      if (tag.tagNumber === 503) hasNoAuthRequired = true;
      if (tag.tagNumber === 504) {
        const inner = readDerNode(tag.content, 0);
        userAuthType = derSmallInt(inner.content);
      }
      if (tag.tagNumber === 505) {
        const inner = readDerNode(tag.content, 0);
        authTimeout = derSmallInt(inner.content);
      }
      if (tag.tagNumber === 702) {
        const inner = readDerNode(tag.content, 0);
        keyOrigin = derSmallInt(inner.content);
      }
      if (tag.tagNumber === 704) {
        const rot = readDerNode(tag.content, 0);
        const rotFields = readDerChildren(rot.content);
        if (rotFields.length >= 3) {
          const deviceLocked = rotFields[1].content.length === 1 && rotFields[1].content[0] !== 0;
          const bootState = derSmallInt(rotFields[2].content);
          verifiedBootOk = deviceLocked && bootState === 0;
        }
      }
    }
    if (
      !hasSignPurpose ||
      keyOrigin !== 0 ||
      !verifiedBootOk ||
      hasNoAuthRequired ||
      userAuthType === null ||
      (userAuthType & 2) === 0 ||
      (authTimeout !== null && authTimeout > 0)
    ) {
      throw new Error('weak-auth-policy');
    }

    securityLevel = attestationLevel === 2 && keymasterLevel === 2 ? 'strongbox' : 'trusted_environment';
  } catch {
    throw deny();
  }

  // 7. Verify no certificate in chain is revoked (bounded cache, fail-closed)
  const certificateSerials = certs.map((c) => c.serial);
  await assertAttestationSerialsNotRevoked(certificateSerials, nowMs);
  return {securityLevel, certificateSerials};
}
