# ResQMe Admin App and Cross-Device Tier 2 Access — Design Specification

**Date:** 2026-11-24  
**Scope:** Phase 1 — Secure Cross-Device Tier 2 Access (separate Student/Admin builds, staff role boundaries, biometric-backed staff device enrollment, QR-bound cross-device medical read, audit logging, and protected display).  
**Baseline:** `main` @ `dde3ca5` (branch `feat/resqme-admin-tier2-access`).

---

## 1. Architectural Principles & Trust Boundaries

1. **Single Repository, Distinct Application Builds**:
   - **Student App (`student` flavor)**: Preserves existing `applicationId` (`com.example.resqme`), label (`ResQme`), entry point (`lib/main.dart`), registration, QR generation, medical submission, Tier 1 public resources, and student self-access Tier 2. No cross-student access or staff/admin screens are exposed.
   - **Admin / Staff App (`admin` flavor)**: Distinct `applicationId` (`com.example.resqme.admin`), label (`ResQme Admin`), entry point (`lib/main_admin.dart`), and isolated Firebase app instance (`resqme-admin-${backend.mode}`). Hosts role-gated Admin and Authorized staff workflows.
2. **Server-Authoritative Staff Roles**:
   - Stored exclusively in server-owned `staffAccounts/{uid}` with schema `{ role: 'admin' | 'authorized', active: boolean, schoolId: string }`.
   - Client writes and direct client reads to `staffAccounts/{uid}` are denied by Firestore Rules.
   - All staff callables derive actor identity solely from `request.auth?.uid` and validate role/scope via `requireStaff(db, uid, allowedRoles)`.
   - No client-selected role, school ID, self-elevation, or public staff registration.
   - Legacy `schoolReviewers/{uid}` records are not automatically mapped to `staffAccounts/{uid}` unless explicitly provisioned; legacy school-approval callables are aligned with server-trusted scope.
3. **Zero Direct Client Reads of Medical Records**:
   - `firestore.rules` denies all direct client reads and writes on `studentMedicalRecords/{uid}` and its subcollections (`allow read, write: if false`).
   - Legitimate student medical editing/status checks use purpose-scoped server callables (`getMyMedicalRecordStatus` for metadata-only status/revision, and existing owner completion/synthetic-record callables with fresh auth where sensitive values are returned).
   - Staff never receive direct Firestore read permissions on `studentMedicalRecords`, `studentProfiles`, `studentQrCredentials`, or `tier2AccessAudits`.

---

## 2. Biometric-Backed Staff Device Enrollment (Task 1.3)

- **Separate Key Namespace**: Staff device keys use `staffTier2Devices/{staffUid}` (and Android Keystore alias prefix `resqme_staff_tier2_<deviceId>`), completely isolated from student `tier2Devices/{uid}`.
- **One Active Key Per Staff Account**: Enrolling a new device atomically overwrites/increments `keyVersion` on `staffTier2Devices/{staffUid}`, immediately invalidating any previously enrolled key.
- **Enrollment Flow**:
  1. Staff signs in with email/password and completes fresh password reauthentication (`auth_time` within 120 seconds).
  2. Client calls `issueStaffEnrollmentChallenge({})` → returns `{ challengeId, nonce, expiresAt }` (60-second expiry, single-use, stored in `staffEnrollmentChallenges/{challengeId}`).
  3. Native Android (`MainActivity.kt` method channel `resqme/tier2_key`) generates an EC P-256 (`secp256r1`) key in `AndroidKeyStore` with:
     - `PURPOSE_SIGN`, `DIGEST_SHA256`
     - `setUserAuthenticationRequired(true)`
     - `setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)` on API 30+ (or `setUserAuthenticationValidityDurationSeconds(-1)` on API 28–29)
     - `setInvalidatedByBiometricEnrollment(true)`
     - `setAttestationChallenge(nonceBytes)`
     - Returns `{ publicKey, attestationChain }` (DER-encoded X.509 certificate chain as base64url array).
  4. Client calls `enrollStaffTier2Device({ challengeId, deviceId, publicKey, attestationChain })`.
  5. Server verifies:
     - Active staff role (`admin` or `authorized`) and fresh auth (`<= 120s`).
     - Valid, unconsumed, unexpired enrollment challenge bound to `staffUid`.
     - Valid EC P-256 SPKI `publicKey`.
     - **Attestation Verification**: Parses X.509 certificate chain (`attestationChain`), verifies leaf public key matches `publicKey`, verifies chain signatures and validity window, checks Android Key Attestation extension (`1.3.6.1.4.1.11129.2.1.17`) for matching `attestationChallenge === nonce`, hardware-backed security level (`TrustedEnvironment` or `StrongBox`), and hardware-enforced strong biometric user authentication policy (no software-only keys, no unlocked/unattested keys). Root trust anchors are checked against configured Google Hardware Attestation Root SPKIs (failing closed if unsupported or unverified).
     - Consumes enrollment challenge and writes `staffTier2Devices/{staffUid}` atomically in a Firestore transaction.
  6. `revokeStaffTier2Device({})` allows a staff member (with fresh auth) to revoke their own enrolled device key atomically without requiring full eligibility.

---

## 3. Cross-Device QR-Bound Challenge, Medical Read & Audit (Task 1.4)

- **No Responder Password Fallback**: Staff Tier 2 reads require biometric-backed cryptographic proof from the staff member's enrolled device. Password is only for initial sign-in and trusted device enrollment/recovery.
- **QR-Bound Challenge Issuance** (`issueStaffTier2Challenge({ payload, deviceId, purpose })`):
  - Validates active staff (`admin` | `authorized`), active `staffTier2Devices/{staffUid}` matching `deviceId`, canonical `resqme:v1:...` payload, and allowed `purpose` enum (`emergency_response`, `clinic_triage`, `incident_assistance`).
  - Server-side per-staff rate limiting (bounded window).
  - Resolves `payload` privately via `studentQrLookups/{sha256(payload)}` — never logs raw payloads.
  - Verifies live `studentProfiles/{targetUid}`, `studentQrCredentials/{targetUid}` (active, payload match), `studentMedicalRecords/{targetUid}`, `studentGuardianAuthorizations/{targetUid}` via `evaluateQrEligibility`, and enforces same-school scope (`student.schoolId === staff.schoolId`).
  - Creates single-use 60-second challenge in `staffTier2Challenges/{challengeId}` bound to `{ staffUid, schoolId, deviceId, keyVersion, targetUid, qrHash, medicalRevision, operation: 'staff_read_medical', purpose, nonce, expiresAt, consumedAt: null }`.
  - Returns **opaque challenge only** (`{ challengeId, nonce, deviceId, operation, purpose, expiresAt }`) — zero student identity or medical details before biometric proof.
- **Domain-Separated Signed Message**:
  ```
  resqme:staff-tier2:v1
  {staffUid}
  {deviceId}
  {operation}
  {purpose}
  {challengeId}
  {nonce}
  ```
- **Atomic Proof Consumption, Re-Verification & Audit** (`readStudentTier2({ challengeId, deviceId, signature })`):
  - Inside a single Firestore transaction:
    1. Re-reads live `staffAccounts/{staffUid}`, `staffTier2Devices/{staffUid}`, `staffTier2Challenges/{challengeId}`, `studentProfiles/{targetUid}`, `studentQrCredentials/{targetUid}`, `studentQrLookups/{qrHash}`, `studentMedicalRecords/{targetUid}`, and `studentGuardianAuthorizations/{targetUid}`.
    2. Fails closed if staff suspended/reassigned, device key revoked/rotated (`keyVersion` mismatch), challenge expired/consumed/mismatched, signature invalid, QR revoked/replaced after challenge issuance, medical revision changed, or student/guardian eligibility failed.
    3. Marks challenge consumed (`consumedAt: FieldValue.serverTimestamp()`).
    4. Writes immutable success audit document in `tier2AccessAudits/{auditId}` containing `{ actorUid, actorRole, schoolId, targetUid, deviceId, purpose, outcome: 'allowed', recordedAt }` (zero medical data, signatures, passwords, or raw QR). Audit write is inside the same transaction so audit failure prevents data release.
  - Denied attempts record bounded, sanitized denial audit entries safely outside the aborted transaction (without leaking raw QR, signatures, or medical content).
  - Returns strictly the validated allowlist: `{ conditions, allergies, primaryContact }`.

---

## 4. Staff Scanner & Protected Medical Display (Task 1.5)

- **Role-Gated Admin Shell**:
  - `AdminApp` (`lib/features/admin/admin_app.dart`) gates entry behind staff sign-in and `getStaffAccess({})`.
  - Both `admin` and `authorized` roles can enroll/revoke their own biometric device and scan a student QR for Tier 2 emergency access.
  - Phase 1 intentionally omits Phase 2 management screens and Phase 3 roster import.
- **Protected Display Controls**:
  - One scan triggers at most one challenge; no student medical data is displayed prior to biometric verification.
  - Cancel, lockout, or hardware unavailability never reveals medical data and never falls back to password.
  - **120-second display TTL**: Auto-locks and wipes in-memory state after 120 seconds.
  - **Lifecycle Clearing**: Clears record immediately on Lock button, route exit/back, app background/hidden/paused, account switch, or logout; ignores late async completions via generation tokens.
  - **Screenshot / Recents Suppression**: Native Android `FLAG_SECURE` enabled via method channel when protected medical display is active and cleared on exit.
  - No offline cache or disk persistence of medical records.

---

## 5. Deferred Scope (Out of Phase 1)

- Phase 2: Admin dashboard management (personnel listing/provisioning/suspension, student list/search/conflict resolution, lost QR rotation, audit log viewer).
- Phase 3: School Form 1 (SF1) `.xls`/`.xlsx` parsing, preview, import, and enrollment code issuance.
- Hosted Firebase deployment, App Check, IAM changes, and real-account provisioning.
