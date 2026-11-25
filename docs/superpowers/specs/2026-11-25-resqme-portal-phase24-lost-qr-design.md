# ResQMe Portal — Phase 2.4: Lost QR Management Design Specification

Date: 2026-11-25  
Branch: `feat/resqme-admin-tier2-access`  
Baseline HEAD: `355c6f1`  
Staging Project: `resqme-943ee`

---

## 1. Task 0 — Security Preflight & Baseline

1. **Working Tree Preservation:** Confirmed `29` unrelated reviewer-QA working-tree entries are present and must remain untouched and unstaged across all Phase 2.4 commits.
2. **Hosted Callable Reconciliation:** `firebase functions:list --project resqme-943ee` returned **41** hosted v2 callables (`us-central1`, `nodejs22`):
   - All **39** callables exported by `HEAD:functions/src/index.ts`.
   - Plus **2** reviewer-QA callables (`getSchoolReviewCandidateByQr`, `getSchoolReviewStatus`).
3. **Synthetic Medical Endpoints Posture (`saveMySyntheticMedicalRecord`, `clearMySyntheticMedicalRecord`, `getMySyntheticMedicalRecord`):**
   - All three are exported in `HEAD:functions/src/index.ts` and deployed in `resqme-943ee`.
   - `saveMySyntheticMedicalRecord` and `clearMySyntheticMedicalRecord` fail closed via `qaTesters/{uid}.enabled === true && qaTesters/{uid}.syntheticOnly === true` and `requirePending(profile)`.
   - `getMySyntheticMedicalRecord` additionally enforces `requireRecentAuth(request.auth?.token.auth_time)`.
   - `firestore.rules` denies all client reads/writes to `qaTesters/{uid}` (`allow read, write: if false`). Normal students, Authorized staff, and Master Admins cannot enable synthetic access. No hosted functions are deleted without explicit owner authorization.
4. **Legacy School-Review & Revocation Endpoints:**
   - `approveStudentQr`, `revokeStudentQr`, and `getSchoolReviewCandidate` all delegate to `functions/src/school/approval_contract.ts` (`assertApprovalEligible`, `assertRevocationEligible`, `assertReviewCandidateEligible`), enforcing `!isStudentAccountDisabled(student)` and same-school `schoolReviewers/{reviewerUid}` authorization.
5. **Security Baseline Preserved:**
   - Hardware-backed ECDSA P-256 biometric Tier 2 enrollment & access (`STAFF_ENROLLMENT_PROOF_VERSION = 2`).
   - Server-side LRN masking (`XXXX••••XXXX`) + single-use, rate-limited 2-layer step-up LRN reveal (`issueAdminLrnRevealChallenge`, `revealStudentLrn`) with `FLAG_SECURE`, 30s auto-hide, and background wipe.

---

## 2. Task 1 — Existing QR Lifecycle Review

- **`functions/src/qr/replace_my_tier1_qr.ts`:** Generates `resqme:v1:<32-byte-base64url>` payload, hashes with SHA-256 into `studentQrLookups/{hash}`, revokes `oldLookup` (`status: 'revoked', revokedAt`), updates/creates `studentQrCredentials/{uid}`, and computes `verificationStatus` via `evaluateQrEligibility`.
- **`functions/src/qr/ensure_my_tier1_qr.ts`:** Transactional read/activate for the student owner (`studentProfiles/{uid}`, `studentQrCredentials/{uid}`, `studentQrLookups/{hash}`). Returns `{payload, verificationStatus, issuedAt}` directly from Firestore.
- **`functions/src/qr/resolve_tier1_qr.ts`:** Public/scanner Tier 1 resolution checks `lookup.get('status') === 'active'`, `credential.get('payload') === payload`, and `evaluateQrEligibility(...)`. Rotating `studentQrCredentials/{uid}.payload` and marking the old `studentQrLookups/{oldHash}` as `status: 'revoked'` immediately invalidates the old QR.
- **`functions/src/staff/issue_staff_tier2_challenge.ts` & `functions/src/staff/read_student_tier2.ts`:** Tier 2 challenges bind `qrHash = hashQrPayload(payload)`. `readStudentTier2` re-reads `studentQrCredentials/{uid}` and `studentQrLookups/{qrHash}` inside a transaction and rejects if `lookupSnap.get('status') !== 'active'` or `hashQrPayload(livePayload) !== qrHash`. Rotating the student credential automatically denies any outstanding `staffTier2Challenges` tied to the old QR.
- **`functions/src/school/revoke_student_qr.ts`:** Revokes both `studentProfiles.schoolApprovalStatus = 'revoked'` and `studentQrCredentials.verificationStatus = 'revoked'`. **Not** suitable for lost/damaged/compromised QR replacement because it revokes school enrollment.
- **Student App (`lib/features/qr/screens/my_unverified_qr_screen.dart` & `lib/core/data/pilot_client.dart`):** `MyUnverifiedQrScreen` fetches via `ensureMyTier1Qr` callable (and `readMine` uses `Source.server`). Adding a lightweight `AppBar` refresh button ensures a student with the screen already open can pull the rotated QR immediately without altering visual design or re-completing onboarding.

---

## 3. Architecture & Contracts (Phase 2.4)

### 3.1 Shared QR Rotation Helper (`functions/src/qr/qr_rotation.ts`)
Extract `rotateStudentTier1QrInTx` shared by `replaceMyTier1Qr` (student-initiated) and `replaceSchoolStudentQr` (Master Admin-initiated):
- Computes next `credentialVersion`: `existing.exists ? (Number(existing.get('credentialVersion')) || 1) + 1 : 1`.
- Generates canonical `resqme:v1:${randomBytes(32).toString('base64url')}` payload and verifies `studentQrLookups/{newHash}` does not collide.
- Evaluates `evaluateQrEligibility(...)` before setting `verificationStatus` (`'active'` or `'pending'`).
- Atomically marks previous `studentQrLookups/{oldHash}` as `status: 'revoked', revokedAt: serverTimestamp(), revokedReason?`.
- Updates or creates `studentQrCredentials/{uid}` with `payload`, `verificationStatus`, `credentialVersion`, `issuedAt`, optional `activatedAt`, and for admin replacements `replacedAt`, `replacedByUid`, `replacementReason`.
- Never deletes any Firestore document (IAM least privilege).

### 3.2 Master Admin Step-Up QR Replacement Callables (`functions/src/staff/staff_qr_replacement.ts`)
1. **`issueAdminQrReplaceChallenge`**
   - Auth: Master Admin (`role === 'master_admin'`), `emailVerified === true`, `setupComplete === true`, `status === 'active'`, same `schoolId`.
   - Input: `{ studentUid, reason: 'lost' | 'damaged' | 'compromised', deviceId? }`.
   - Checks: Student exists, same `schoolId`, `!isStudentAccountDisabled(student)`, `schoolApprovalStatus !== 'revoked'`, and eligible for Tier 1 QR (`evaluateStudentEligibility(...)` is `true` — or if `schoolApprovalStatus === 'approved'` and medical+guardian complete).
   - Rate-limits via `enforceTransactionalRateLimit` (`staffQrReplaceRateLimits/{adminUid}`, max 10 per 60s).
   - Creates single-use `staffQrReplaceChallenges/{challengeId}` (120s TTL) bound to `adminUid`, `schoolId`, `targetUid: studentUid`, `reason`, `operation: 'admin_replace_student_qr'`, `deviceId` (if provided), `nonce`, `issuedAtSec`.
2. **`replaceSchoolStudentQr`**
   - Input: `{ studentUid, reason: 'lost' | 'damaged' | 'compromised', requestId, challengeId, method: 'biometric' | 'password', deviceId?, signature? }`.
   - Step-up verification:
     - `biometric`: verifies active enrolled device (`proofVersion === 2`) ECDSA P-256 signature over:
       `resqme:staff-qr-replace:v1\n${adminUid}\n${deviceId}\nadmin_replace_student_qr\n${studentUid}\n${reason}\n${challengeId}\n${nonce}`
     - `password`: enforces `request.auth.token.auth_time >= challenge.issuedAtSec` (fresh per-operation reauthentication).
   - Idempotency & Concurrency:
     - Uses `staffManagementAudits/${requestId}` (or dedicated digest check) inside the Firestore transaction. Replaying the same `requestId` with matching `{adminUid, studentUid, reason}` returns the recorded result without double-rotating; mismatched payload throws `already-exists`.
     - Consumes `staffQrReplaceChallenges/${challengeId}` inside the transaction (`consumed: true`, `consumedAt: serverTimestamp()`).
   - Eligibility & Rotation:
     - Denies disabled students (`isStudentAccountDisabled`), revoked school approval, or ineligible students (`!evaluateStudentEligibility(...)`).
     - Calls `rotateStudentTier1QrInTx` inside the transaction.
   - Audit Integrity:
     - Writes immutable `staffManagementAudits/${requestId}` inside the **same** transaction (`action: 'replace_student_qr'`, `schoolId`, `actorUid`, `targetUid`, `reason`, `previousCredentialVersion`, `credentialVersion`, `verificationStatus`, `method`, `deviceId?`, `digest`, `recordedAt`). Audit write failure aborts the entire transaction. Never logs raw QR payloads, raw LRN, medical data, or passwords.
3. **`getSchoolStudentDetails` update:**
   - Exposes `credentialVersion: Number(qrSnap.get('credentialVersion') ?? (qrSnap.exists ? 1 : 0))` in student details so Portal screens display current credential version without exposing any QR payload.

### 3.3 Portal UI (`LostQrManagementScreen`, `PortalDashboardScreen`, `StudentDetailsScreen`)
- **No extra bottom navigation tab:** Preserve the 4-tab `NavigationBar` (`Dashboard`, `Active Students`, `Student Roster`, `Authorized Personnel`).
- **Dashboard Quick Action:** Add a compact **Lost QR Management** action card on `PortalDashboardScreen` opening `LostQrManagementScreen`.
- **`LostQrManagementScreen`:** Reuses school-scoped student search/list (`listSchoolStudents`), shows student name, masked LRN (`XXXX••••XXXX`), grade level, verification status, QR status, and `credentialVersion`, with a `Replace QR Code` flow.
- **`StudentDetailsScreen`:** Add contextual **Replace QR Code** action in the QR Credential card (disabled with explanation if student is disabled or QR not eligible).
- **Replacement Confirmation & Step-Up Dialog:** Reason selector (`Lost QR code`, `Damaged QR code`, `Compromised QR code`), permanent invalidation warning for the old QR, confirmation button, and step-up Biometric or Password verification (reusing existing `PlatformTier2Key` + `FirebaseAuth` reauth pattern). Displays loading, cancelled, error, conflict, and success states with updated `credentialVersion`.
