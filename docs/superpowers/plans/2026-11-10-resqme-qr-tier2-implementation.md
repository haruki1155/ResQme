# ResQMe QR Tier 1 and Biometric Tier 2 Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Let an active school-approved QR start a public-only Tier 1 experience, while requiring fresh account-bound biometric proof or Firebase password reauthentication before Tier 2 data is released.

**Architecture:** QR scanning calls a public, generic eligibility endpoint and creates no Firebase owner session. Tier 2 uses the existing Firebase account, a device public key registered after password reauthentication, one-time server challenges, and trusted medical read callables. Server-owned school approval and medical-completion states gate credential activation. Firestore Rules remain deny-all.

**Tech Stack:** Flutter/Dart, Android BiometricPrompt with Android Keystore signing key (Android implementation; other platforms fail closed until a reviewed provider is added), Firebase Auth, Cloud Functions v2 callable TypeScript, Firestore, existing emulator and test tooling.

**Spec:** `docs/superpowers/specs/2026-11-10-resqme-qr-tier2-security-design.md`

## Global Constraints

- Tier 1 QR access exposes public resources only and is not an authenticated Firebase owner session.
- QR eligibility requires school approval and the owner-approved existing medical fields; guardian approval is not required.
- Conditions and allergies require `unknown`, `none_known`, or `listed`; details are required only for `listed`.
- One primary emergency contact is required before QR activation; the secondary contact remains optional.
- The Firebase account password is the Tier 2 fallback; do not create a second password store.
- QR payloads remain opaque, high entropy, and free of personal/medical data.
- Every Tier 2 read is backend-authorized by authenticated UID and fresh, scoped, single-use proof.
- Do not enable APIs, change IAM/App Check/Rules, deploy, create hosted accounts, migrate data, commit, or push.
- Preserve unrelated dirty worktree changes; do not add third-party dependencies without a separately reviewed design amendment.

## Review Focus

- Copied active QR — may access only public Tier 1 content; test all callables reject any QR-only auth context.
- Unknown/revoked/unapproved QR — same generic result; test no UID/profile/status leakage.
- Wrong school reviewer — approval denied and no credential becomes active.
- Stale/replayed/wrong-account Tier 2 challenge — data read denied.
- Android biometric unavailable/enrollment changed — fail closed to password reauthentication; other platforms fail closed.

## File Structure

- `functions/src/qr/` — QR status lookup, activation, revocation, hash index, and Tier 2 challenge callables.
- `functions/src/onboarding/authorization.ts` — shared registration, school reviewer, QR-only, and Tier 2 guards.
- `functions/src/medical/` — production medical validation/save/read contract separate from synthetic QA code.
- `lib/features/qr/` — active credential and generic scan outcome models/repository.
- `lib/features/medical/` — required medical completion and owner-only Tier 2 read state.
- `android/app/src/main/kotlin/` — biometric-authenticated Keystore key creation/signing channel; no key material leaves secure hardware.
- `functions/test/` and `test/features/` — focused backend and Flutter security coverage.

---

### Task 1: Model production eligibility and trusted school approval

**Files:**
- Modify `functions/src/registration/registration_contract.ts` and `functions/src/registration/create_student_registration.ts` only as needed to preserve a trusted school assignment.
- Modify `functions/src/medical/medical_contract.ts` for the approved required fields, removing synthetic-only acknowledgment from the production contract.
- Create `functions/src/medical/complete_my_medical_record.ts` for owner-authenticated, idempotent completion.
- Create `functions/src/school/approve_student_qr.ts` for school-scoped, server-authorized approval and audit record.
- Modify `functions/src/onboarding/authorization.ts` for `requireSchoolReviewer` and eligibility-state validation.
- Test `functions/test/medical_eligibility.test.ts` and `functions/test/school_approval.test.ts`.

**Interfaces:**
- `completeMyMedicalRecord`: authenticated owner; validates conditions, allergies, primary contact and request ID; writes `medicalStatus: complete` transactionally.
- `approveStudentQr`: authenticated reviewer; derives reviewer school from a server-managed reviewer record; approves only a profile assigned to that school; records actor UID and timestamp.
- No reviewer provisioning endpoint is created. Test fixtures seed reviewer records locally; hosted reviewer assignment needs a separately authorized trusted process.

- [ ] Write failing validation tests for each medical state and primary-contact requirement.
- [ ] Write failing tests for unauthenticated owner, untrusted reviewer, wrong-school reviewer, pending/incomplete profile, duplicate request, and idempotent retry.
- [ ] Run focused tests and confirm they fail for missing production endpoints/guards.
- [ ] Implement transactionally; keep synthetic QA endpoints and data paths separate.
- [ ] Run focused tests and `npm.cmd test`; preserve existing behaviors outside this scope.

### Task 2: Activate and resolve QR for Tier 1 only

**Files:**
- Modify `functions/src/qr/ensure_my_tier1_qr.ts` to issue only after school approval and medical completion.
- Create `functions/src/qr/resolve_tier1_qr.ts` to hash and resolve payload, returning generic active/inactive status with no UID or profile fields.
- Modify `functions/src/index.ts` to export the new callable.
- Modify `lib/features/qr/domain/qr_payload_parser.dart` only if the payload contract needs additive version parsing.
- Modify `lib/features/qr/services/tier1_qr_repository.dart` and `lib/features/qr/presentation/qr_scanner_screen.dart` to resolve active credentials and route to the public dashboard after success.
- Test `functions/test/resolve_tier1_qr.test.ts`, `functions/test/ensure_my_tier1_qr.test.ts`, and Flutter scanner tests.

**Interfaces:**
- `resolveTier1Qr({payload}) -> {active: boolean}`; all invalid, unknown, revoked, unapproved, and incomplete conditions have indistinguishable client results.
- Store a SHA-256 lookup document keyed by payload hash; never return UID. No Firebase custom token or owner auth state is created.
- Add credential lifecycle states `active` and `revoked`; replacement invalidates the prior lookup and credential atomically.

- [ ] Test valid, malformed, copied, unknown, revoked, replaced, unapproved, incomplete, and enumeration-resistant cases.
- [ ] Implement hash lookup and atomic activation/revocation.
- [ ] Test QR-only context cannot call profile, owner-QR, registration mutation, or medical endpoints.
- [ ] Verify the scanner shows successful Tier 1 feedback only after an active server result and never exposes personal data.

### Task 3: Add biometric-bound Tier 2 authorization and production medical reads

**Files:**
- Create `functions/src/medical/enroll_tier2_device.ts`, `issue_tier2_challenge.ts`, `read_my_tier2_record.ts`, and `functions/src/medical/tier2_challenge.ts`.
- Modify `functions/src/onboarding/authorization.ts` with verified UID, approval, device, challenge-expiry, operation, and replay guards.
- Create the Android BiometricPrompt/Keystore channel under `android/app/src/main/kotlin/` for key enrollment and auth-per-use signatures.
- Create `lib/features/medical/services/tier2_authorization_repository.dart` and `lib/features/medical/services/platform_tier2_key.dart`.
- Test `functions/test/tier2_authorization.test.ts`, `functions/test/tier2_record_access.test.ts`, and Android channel tests.

**Interfaces:**
- Enroll a public key only after recent Firebase password authentication for the same UID and approved profile.
- `issueTier2Challenge({operation})` binds a random challenge to UID, enrolled device, operation, expiry, and one-time nonce.
- `readMyTier2Record({challengeId, signature})` verifies and consumes the challenge before returning only the authenticated owner's approved fields.
- Password fallback uses Firebase reauthentication and server-verified fresh `auth_time`; it is rate-limited and short-lived.
- Platform key operations fail closed on unsupported platforms, unavailable biometrics, cancellation, lockout, and invalidated keys.

- [ ] Test challenge expiry, replay, wrong UID/device/operation, revoked key, invalid signature, and missing approval.
- [ ] Test medical data is never read before proof verification and never returned to another UID.
- [ ] Test password reauthentication fallback and invalid/old auth time.
- [ ] Implement Android auth-per-use key operations; no biometric templates or private keys are exported.
- [ ] Run Android unit/instrumentation tests where supported and document physical-device coverage separately.

### Task 4: Complete Flutter registration, login feedback, and Tier 2 UI

**Files:**
- Modify `lib/features/medical/screens/synthetic_medical_screen.dart` into the approved required production form without synthetic labels/test storage.
- Modify registration/profile states to show medical completion and school approval separately.
- Modify `lib/features/qr/presentation/qr_scanner_screen.dart` and scanner entry to show generic rejection or post-server-success Tier 1 animation.
- Create `lib/features/medical/screens/tier2_access_screen.dart` for biometric prompt, password fallback, and authorized result display.
- Modify `lib/app/resqme_app.dart` routes only for necessary Tier 2 navigation.
- Test registration, scanner, and Tier 2 widget flows in `test/features/`.

**Interfaces:**
- QR scan success means `QR accepted — Tier 1`; do not claim owner identity verification.
- Tier 2 UI displays data only after the trusted read returns for the current UID and operation.
- Clear requests, view models, and visible values on logout, account switch, background, route exit, and grant expiry.

- [ ] Test completed/incomplete registration, medical form answers, reviewer status, guest resources, QR success/rejection, Tier 2 success/fallback, and cancellation.
- [ ] Test stale asynchronous responses cannot populate a subsequent account's screen.
- [ ] Implement navigation and state clearing; preserve existing guest resources and scanner lifecycle.
- [ ] Run focused Flutter tests and analyzer.

### Task 5: Local integration, security audit, and rollout handoff

**Files:**
- Update `functions/src/index.ts`, local emulator config/tests, and the design/acceptance docs as necessary.
- Create/update a local-only synthetic integration suite; no hosted credentials or records.

- [ ] Run Functions build/tests and Auth/Firestore/Functions emulator integration with loopback-only `demo-resqme`.
- [ ] Run Flutter focused/full relevant suite and Android debug build.
- [ ] Audit every exported callable for QR-only denial and Tier 2 proof requirements.
- [ ] Verify Rules remain unchanged and deny-all tests still pass.
- [ ] Produce a deployment prerequisite report with exact API, IAM, runtime permission, reviewer provisioning, data migration, and App Check changes; do not perform them.

## Deployment boundary

Local implementation does not authorize hosted use. The runtime custom role currently permits Firestore get/create only; medical updates, QR status transitions, reviewer audit, challenges, and device registration require a new permission review. If Admin custom tokens are later selected, Firebase documents a `iam.serviceAccounts.signBlob` prerequisite. No IAM/API changes, hosted reviewer creation, migration, account tests, or deployment occur under this plan.
