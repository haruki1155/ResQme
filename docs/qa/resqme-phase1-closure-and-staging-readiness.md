# ResQMe Phase 1.6 — Emulator Verification & Staging Acceptance Preparation

**Branch:** `feat/resqme-admin-tier2-access`
**Baseline:** `main` @ `dde3ca5`
**Scope:** Phase 1 — Secure Cross-Device Tier 2 Access only (no Phase 2 Admin management, no Phase 3 SF1 roster import, no hosted execution performed).

---

## 1. Local Emulator Verification Procedure (Blocked Pending Dedicated Isolated Runner)

### Current Status
- **Status:** **BLOCKED / NOT RUN** in this session.
- **Reason:** Per `docs/qa/resqme-reviewer-firestore-contention-pass.md`, emulator startups must run under an isolated temporary profile with verified CIM process ownership, listener allowlist guards, empty initial Auth/ADC stores, and exact post-run deletion readback. The Phase 1.7 emulator integration suite (`functions/test/staff_tier2_emulator_integration.test.ts`, script `npm run test:integration:phase1`) is compiled and ready for the 24-export committed package, but no emulator was launched because separate credential-safety startup authorization is required.

### Exact Emulator Verification Steps (Once Approved Isolated Runner Is Prepared)
1. **Preflight:**
   - Verify Node.js 22 (`node -v` → `v22.x`), `CI=1`, empty isolated Firebase CLI profile, and free loopback ports (`4400`, `4500`, `8080`, `9099`, `5001`).
   - Build clean committed `functions` under Node 22 (`npm run build`) and confirm all 24 callable exports register.
2. **Firestore Rules Suite (`npm run test:rules` against `demo-resqme`):**
   - Confirm `studentMedicalRecords/{uid}` and `studentMedicalRecords/{uid}/acknowledgments/{id}` deny direct client reads/writes for owner, other users, and unauthenticated callers.
   - Confirm `staffAccounts`, `staffTier2Devices`, `staffEnrollmentChallenges`, `staffTier2Challenges`, and `tier2AccessAudits` deny all direct client reads/writes.
3. **Real-Transaction Concurrency & Authorization Harness (HTTP against local emulator `demo-resqme`):**
   - Seed synthetic adult student (`student-1`, assigned/approved `pilot-school-1`, complete medical revision 1, active QR), synthetic minor without guardian (`minor-1`), active same-school Admin (`admin-1`), active same-school Authorized (`auth-1`), wrong-school staff (`other-1`), and inactive staff (`inactive-1`).
   - Exercise `getStaffAccess`, `issueStaffEnrollmentChallenge` → `enrollStaffTier2Device` (with test root override in emulator only), `issueStaffTier2Challenge`, and two **simultaneous** HTTP `readStudentTier2` requests with the same proof:
     - Exactly 1 HTTP 200 returning `{ conditions, allergies, primaryContact }` and 1 HTTP 403 `PERMISSION_DENIED`.
     - Exactly 1 `tier2AccessAudits` document with `outcome: 'allowed'` and zero medical/QR/signature fields.
   - Exercise QR revocation/replacement mid-challenge, staff suspension mid-challenge, device key rotation mid-challenge, and cross-school denial.
4. **Cleanup & Readback:**
   - Delete all synthetic Auth users and Firestore documents; read back 0 Auth users and 0 Firestore documents before emulator shutdown; verify 0 leftover processes/listeners.

---

## 2. Two-Device Physical Acceptance Procedure

### Prerequisites
- **Phone A (Student Device):** `student` debug APK (`com.example.resqme`, entry `lib/main.dart`, `RESQME_BACKEND=staging`).
- **Phone B (Staff Device):** `admin` debug APK (`com.example.resqme.admin`, entry `lib/main_admin.dart`, `RESQME_BACKEND=staging`) on Android 9+ with hardware-backed Android Keystore, locked bootloader (`Verified`), and enrolled strong fingerprint.

### Acceptance Scenarios (Fictional Data Only)
1. **Student App Regression (Phone A):** Register/sign in fictional adult student, confirm inert pending QR, complete medical form, obtain synthetic school approval, verify active QR renders.
2. **Staff Role Gate (Phone B):**
   - Attempt sign-in with student account → denied and signed out immediately.
   - Sign in with provisioned fictional `authorized` or `admin` staff account → role-gated scan shell opens showing assigned `schoolId`.
3. **Staff Biometric Device Enrollment (Phone B):**
   - Open `Trusted Device Biometrics`, confirm staff password, verify hardware-attested key enrollment succeeds (`staffTier2Devices/{staffUid}` created with `attestationLevel: trusted_environment | strongbox`).
4. **Cross-Device Emergency Tier 2 Read (Phone B scanning Phone A):**
   - Phone A displays active student QR (student does NOT authenticate on Phone B).
   - Phone B selects purpose (`Emergency Response`), scans Phone A's QR, confirms OS strong biometric prompt on Phone B.
   - Verify medical allowlist (`conditions`, `allergies`, `primaryContact`) displays; verify screenshot/recents capture is blocked (`FLAG_SECURE`).
   - Verify `tier2AccessAudits` records 1 `allowed` entry with actor, role, school, target reference, device ID, purpose, and timestamp — zero medical data or raw QR.
5. **Negative & Lifecycle Checks (Phone B):**
   - Cancel biometric prompt → no medical data shown, no password fallback offered, camera resets for next scan.
   - Lock button, background/home button, 120s TTL expiry, and sign-out each immediately wipe displayed medical data.
   - Revoke or replace Phone A's QR after challenge issuance → read denied.
   - Suspend staff or revoke Phone B's device key → read denied.

---

## 3. Staging Rollout Prerequisites (No Hosted Actions Performed)

1. **Firebase Android App Registration & Explicit Staging Config:**
   - Register Android app `com.example.resqme.admin` in Firebase project `resqme-943ee` (with approved signing SHA-256 fingerprint) and replace the local demo-only `android/app/src/admin/google-services.json`.
   - Build the staging Admin APK with explicit `--dart-define=RESQME_BACKEND=staging`, `--dart-define=RESQME_ADMIN_FIREBASE_APP_ID=<admin-app-id>`, and `--dart-define=RESQME_ADMIN_FIREBASE_API_KEY=<admin-api-key>`. `AdminBackendConfig.resolve` fails closed if either define is missing, malformed, or reuses the Student Android `appId`.
2. **Callable Exports (24 total in `functions/src/index.ts`, Node.js 22 runtime, dedicated runtime service account):**
   - Existing 16 + 8 new Phase 1 callables:
     - `getMyMedicalRecordStatus`, `getMySyntheticMedicalRecord`
     - `getStaffAccess`, `issueStaffEnrollmentChallenge`, `enrollStaffTier2Device`, `revokeStaffTier2Device`, `issueStaffTier2Challenge`, `readStudentTier2`
3. **Firestore Rules Deployment:**
   - Deploy hardened `firestore.rules` denying all direct client reads/writes on `studentMedicalRecords/{uid}` and keeping all `staff*` / `tier2AccessAudits` collections denied by default catch-all.
   - Confirm staging Rules posture remains strictly least-privilege (no client writes, no broad staff reads).
4. **Runtime Permissions & Environment Configuration:**
   - Existing dedicated Cloud Functions runtime service account (`resqmeRuntimeOptions`) requires Firestore read/write on `staffAccounts`, `staffEnrollmentChallenges`, `staffTier2Devices`, `staffTier2Challenges`, `tier2AccessAudits`, `studentProfiles`, `studentMedicalRecords`, `studentQrCredentials`, `studentQrLookups`, `studentGuardianAuthorizations`. No Auth admin IAM is needed in Phase 1.
   - Configure Cloud Functions environment variable `RESQME_ADMIN_SIGNING_CERT_SHA256` with the approved `com.example.resqme.admin` APK signing certificate SHA-256 hex digest (fail-closed if unset).
   - Optionally configure `RESQME_ATTESTATION_ROOT_SHA256` for rotated Google Hardware Attestation Root SPKI SHA-256 digests.
5. **Hardware Attestation & Revocation Status Verification:**
   - `staff_attestation.ts` enforces hardware security level (`TrustedEnvironment` / `StrongBox`), `com.example.resqme.admin` package name, approved signing-certificate SHA-256 digest, `KM_ORIGIN_GENERATED`, `SIGN` purpose, Verified Boot (`deviceLocked && Verified`), per-use strong biometric policy, and Google's `https://android.googleapis.com/attestation/status` revocation list with a 1-hour bounded cache and fail-closed behavior on both enrollment and every subsequent Tier 2 challenge/read.
6. **Synthetic Staging Accounts & Deployment Sequence:**
   - Deploy Functions first, then deploy updated `firestore.rules`, verify active `nodejs22` revisions, provision disposable fictional accounts (`studentProfiles`, `staffAccounts/{uid}` via operator Admin SDK), execute two-device acceptance, and run exact cleanup deleting every test-created Auth user and Firestore document with readback confirmation (`0` remaining test resources).
