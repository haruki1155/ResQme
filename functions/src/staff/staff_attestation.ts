import {createHash, createPublicKey, timingSafeEqual, X509Certificate} from 'node:crypto';
import {HttpsError} from 'firebase-functions/v2/https';

// Google Hardware Attestation Root SPKI SHA-256 fingerprints (RSA-4096 & EC-P384 roots).
// Production rollout also requires checking Google's attestation revocation status list.
const DEFAULT_TRUSTED_ROOT_SPKI_SHA256: readonly string[] = [
  '2549b3923e8f618f0284c048b99dc0c11a84935455d1c08d376c6282a45269f5',
  '9a2520f2a0e7a2b561517d9a71992593263d3f9c022a7a3e640b9921d803e060',
  'f97e83f629a1f7b1f0909f74383b4a13c542b33015c0c98a6f7509d560728f8e',
];

let testRootOverrides: readonly string[] | null = null;

export function setTrustedAttestationRootHashesForTest(hashes: readonly string[] | null): void {
  testRootOverrides = hashes;
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

export function verifyAndroidKeyAttestation(input: {
  publicKey: string;
  attestationChain: unknown;
  expectedChallenge: Buffer;
  nowMs?: number;
}): AttestationSecurityLevel {
  const deny = () => new HttpsError('permission-denied', 'Device key attestation could not be verified.');
  if (!Array.isArray(input.attestationChain) || input.attestationChain.length < 2 || input.attestationChain.length > 8) {
    throw deny();
  }
  const nowMs = input.nowMs ?? Date.now();
  const certs: {x509: X509Certificate; der: Buffer}[] = [];
  try {
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
      certs.push({x509, der});
    }

    // 1. Leaf public key must match submitted EC P-256 publicKey
    const submittedDer = Buffer.from(input.publicKey, 'base64url');
    const submittedKey = createPublicKey({key: submittedDer, format: 'der', type: 'spki'});
    if (submittedKey.asymmetricKeyType !== 'ec' || submittedKey.asymmetricKeyDetails?.namedCurve !== 'prime256v1') {
      throw new Error('key-type');
    }
    const leafSpki = certs[0].x509.publicKey.export({type: 'spki', format: 'der'});
    if (!leafSpki.equals(submittedDer)) throw new Error('leaf-mismatch');

    // 2. Verify certificate chain signatures
    for (let i = 0; i < certs.length - 1; i++) {
      if (!certs[i].x509.verify(certs[i + 1].x509.publicKey)) throw new Error('chain-sig');
    }

    // 3. Verify root trust anchor
    const rootSpki = certs[certs.length - 1].x509.publicKey.export({type: 'spki', format: 'der'});
    const rootHash = createHash('sha256').update(rootSpki).digest('hex');
    const trustedRoots = testRootOverrides ?? DEFAULT_TRUSTED_ROOT_SPKI_SHA256;
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

    // 5. Verify hardware-enforced (teeEnforced) per-use strong biometric policy
    const teeEnforced = fields[7];
    if (teeEnforced.tagClass !== 0 || teeEnforced.tagNumber !== 16) throw new Error('bad-tee');
    const teeTags = readDerChildren(teeEnforced.content);
    let hasNoAuthRequired = false;
    let userAuthType: number | null = null;
    let authTimeout: number | null = null;
    for (const tag of teeTags) {
      if (tag.tagClass !== 2) continue;
      if (tag.tagNumber === 503) hasNoAuthRequired = true;
      if (tag.tagNumber === 504) {
        const inner = readDerNode(tag.content, 0);
        userAuthType = derSmallInt(inner.content);
      }
      if (tag.tagNumber === 505) {
        const inner = readDerNode(tag.content, 0);
        authTimeout = derSmallInt(inner.content);
      }
    }
    // Tag 503 (noAuthRequired) forbidden; tag 504 must include HW_BIOMETRIC (bit 2);
    // tag 505 (authTimeout) must be absent or 0 (per-use auth).
    if (hasNoAuthRequired || userAuthType === null || (userAuthType & 2) === 0 || (authTimeout !== null && authTimeout > 0)) {
      throw new Error('weak-auth-policy');
    }

    return attestationLevel === 2 && keymasterLevel === 2 ? 'strongbox' : 'trusted_environment';
  } catch {
    throw deny();
  }
}
