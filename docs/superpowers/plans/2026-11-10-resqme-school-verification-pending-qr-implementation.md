# ResQMe School Verification and Pending QR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended when review capacity is available) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Use `superpowers:test-driven-development`, `superpowers:systematic-debugging` on failures and `superpowers:verification-before-completion` at the end.

**Goal:** Add required LRN, single-use school-code auto verification, five emulator-only student records, trusted manual reviewer approval and non-active pending QR, without bypassing any existing QR/medical/guardian safety requirement or interrupting immediate public Tier 1 access.

**Architecture:** Extend the existing Firebase Auth registration callable and `studentProfiles` document. Import a small synthetic school roster only into the Firebase emulator; an authenticated transaction consumes a code and records a verified same-school assignment, otherwise leaves a pending review path. Reuse `schoolReviewers` and existing approval/revocation callables; the server creates an opaque pending QR and activates it only after *independent* eligibility checks. Flutter only displays server-projected state and never assigns approval or school identity.

**Tech Stack:** Flutter/Dart, Firebase Auth, Firestore, Firebase Functions v2/TypeScript (Node.js 22), `node:test`, Firebase emulators, existing widget and integration tests. No new libraries unless a failing scoped test proves necessary.

**Spec:** `docs/superpowers/specs/2026-11-10-resqme-school-verification-design.md`. Respect the previous registration and QR design and existing project security agreements.

## Global Constraints

- **Baseline:** Paths in this plan were verified against `haruki1155/Resqme` GitHub `main` on 2026-11-10, tree `cd5d9f2a412e3bcb6aa501a5729824ea6685dc73`. The owner's Windows working tree may contain later uncommitted changes. **Read and reconcile local reality before editing.** If existing work already supplies a feature, reuse it and update the relevant test instead of rebuilding it.
- **Authorization:** Local implementation, synthetic-only test data and documentation only. **No** staging Firebase mutations, hosted tests, deploy/redeploy, IAM, API, Rules/App Check change, real/student accounts, school assignment by fiat, production roster import, commit, push or branch manipulation without an independent owner instruction. When executing, commits are *proposed checkpoints*, not preauthorization to commit.
- **Disk/credentials:** Do not make another worktree. Preserve all existing changes. Do not launch Firebase CLI emulators while the previously reported isolated Firebase ADC file issue is unresolved; run unit/widget checks first, then report integration as blocked until a safe operator-approved path exists. Never inspect, print or clean up credentials as part of this plan.
- **Existing interfaces:** Keep callable names `createStudentRegistration`, `getMyStudentProfile`, `ensureMyTier1Qr`, `resolveTier1Qr`, `approveStudentQr`, `revokeStudentQr` and `replaceMyTier1Qr`. Extend response shapes compatibly. The current repo also exports other medical/Tier 2 Functions: do not deploy, change or remove their exports.
- **Preservation:** Keep the existing backend meaning and assignment of `status` (`pending_review` / `pending_guardian`) while separating school review and QR activation. The GitHub baseline currently writes `pending_review` even for minors; do **not** silently change that legacy behavior as part of this scope—record any mismatch with the older minor-registration design for owner review. `schemaVersion:1` legacy `lrn:null` accounts remain readable/restricted; a new LRN requirement must not silently grant legacy accounts new privileges. Keep device release/profile Firebase protections.
- **Security:** No direct client approval or roster writes. School ID comes only from an authentic roster or operator-provisioned reviewer. A code cannot be inferred from LRN/name. A school roster, reviewer or guardian authorization cannot be invented. Raw LRN/code never enters public QR, owner profile callable response, error text or logs. Require authoritative guardian verification for under-18 QR activation; absent implementation means no minor activation.
- **Data:** Synthetic roster, student names, contact values, email addresses and enrollment codes must be clearly fictional. Forbid seeding to `resqme-943ee` or any non-emulator endpoint. No plaintext real enrollment codes committed. Untrusted/error outputs do not reveal whether an LRN exists.
- **Fail closed:** Preserve public emergency dashboard, hotlines, first aid, scanner and DRRM navigation even if the logged-in student's QR or verification state is unavailable. QR scans reveal at most `active: boolean`.

## Review Focus

1. Same LRN/code raced from **two different Auth UIDs**: only one successful auto-claim, second pending/conflict, never two approved profiles (Tasks 2–3).
2. Auth user created but registration callable times out, then retry: one profile, one acknowledgment, at most one claimed roster record and same QR payload (Tasks 3–4).
3. Minor on an approved roster with medical complete but **no verified guardian authority**: QR remains pending and public scan remains inactive (Task 6).
4. Unknown/used/incorrect enrollment code or forged school/reviewer/status fields: valid registration still gets a pending QR; no auto approval or roster-existence leak (Tasks 1–3).
5. Revoked/old/duplicate QR and cross-school reviewer: no reactivation, private data disclosure or other-school manual approval (Tasks 5–6).

---

## Read-only preflight: reconcile the actual checkout

- [ ] Run `git status --short`, `git branch --show-current`, `git rev-parse HEAD`, and `rg --files | rg 'AGENTS\.md|registration|school|qr|medical|firestore|emulator'`. Read any checkout `AGENTS.md` and preserve unrelated edits. Do **not** reset/clean the worktree.
- [ ] Inspect the exact existing contracts: `functions/src/registration/{registration_contract,create_student_registration}.ts`, `functions/src/school/{approval_contract,approve_student_qr,revoke_student_qr}.ts`, `functions/src/qr/{ensure_my_tier1_qr,resolve_tier1_qr,replace_my_tier1_qr}.ts`, `functions/src/onboarding/authorization.ts`, `functions/src/profile/get_my_student_profile.ts`, `functions/src/medical/complete_my_medical_record.ts`, and `functions/src/index.ts`.
- [ ] Inspect `lib/features/registration/{models,services,screens}`, `lib/features/qr/{screens,services,presentation}`, `firebase.json`, `firestore.rules`, `functions/package.json`, and the named tests below. Record differences from the GitHub baseline (particularly Rules and uncommitted medical/Tier 2 additions) and revise specific line edits accordingly.
- [ ] Confirm which Firebase project local *unit* tests use; `functions/test/emulator_config.ts` designates `demo-resqme`. Do not start emulators or access hosted projects at this stage.
- [ ] Establish a non-network baseline using `npm --prefix functions test`, `flutter test test/features/registration`, `flutter test test/features/qr`, and `flutter analyze` if installed. Record pre-existing failures; do not attribute historical results to this run.

## Task 1 — Required LRN and code-aware registration form

**Files:**
- Modify: `functions/src/registration/registration_contract.ts`, `functions/src/registration/create_student_registration.ts` (request mapping only at this step).
- Modify: `lib/features/registration/models/registration_draft.dart`, `lib/features/registration/registration_validators.dart`, `lib/features/registration/screens/create_student_account_screen.dart`, `lib/features/registration/widgets/registration_privacy_dialog.dart` (only privacy copy if data collection needs disclosure).
- Test: `functions/test/create_student_registration.test.ts`, `test/features/registration/registration_validators_test.dart`, `test/features/registration/registration_models_test.dart`, `test/features/registration/create_student_account_screen_test.dart`.

**Interfaces:** Extend `RegistrationInput` with `lrn: string` and `enrollmentCode?: unknown`; `validateRegistration(input)` returns normalized `lrn` (exactly `/^\d{12}$/`) and normalized optional `enrollmentCode` for server-only consumption. Extend Dart `RegistrationDraft` with `required String lrn, String? enrollmentCode`; `toProfilePayload()` adds these two fields but never credentials. Define `validateLrn(String?)` and `validateEnrollmentCode(String?)` in existing validators. Preserve `noticeVersion = 'tier1-registration-v1'` pending a separate privacy-version decision; the visible notice must disclose new fields.

- [ ] **RED:** Add TypeScript validation tests: leading-zero 12-digit string accepted; missing/11/13 characters, alphabetic, integer and whitespace-only LRN rejected. Malformed code fails *code matching*, not basic registration. Client attempts to set `status`, `schoolId`, reviewer or approved state are never trusted.
- [ ] **RED:** Add Flutter tests for required LRN field, `Enrollment code (optional for manual review)` field, safe code obscuring, empty code submission as manual review, no account creation before privacy acceptance, and 320px viewport no overflow. Update old `expect(find.text('LRN'), findsNothing)` expectation intentionally.
- [ ] Run `npm --prefix functions test` and `flutter test test/features/registration` to observe meaningful RED failures; note baseline status first.
- [ ] **GREEN:** Add fields/validation to existing form and payload. Do not change password/Auth ordering, acknowledgement, partial Auth retry or screen routing. Never log supplied code. Make the distinction “LRN required; enrollment code used for automatic school verification” explicit.
- [ ] Run the same suites plus `flutter analyze` and `git diff --check`; inspect the diff for any unrelated form edits.

**Acceptance:** The student can register with a valid LRN and no code (manual route), but not with an invalid LRN. Existing optional fields and privacy interaction still work.

## Task 2 — Five restricted emulator roster fixtures and one-use matching contract

**Files:**
- Create: `functions/src/school/roster_contract.ts` (normalization, keyed lookup and matching definitions).
- Create: `functions/test/fixtures/synthetic_school_roster.ts` (exactly five fictional test cases with school IDs, names, LRNs, local-only code strings and expected outcome metadata).
- Create: `functions/tools/seed_local_school_roster.ts` (explicit emulator-only seeding; no general production importer).
- Test: `functions/test/school_roster.test.ts`.
- Modify only if necessary: `functions/package.json` (add focused test and safe local seed script, do not rewire existing scripts).

**Interfaces:** `normalizeLrn(value: unknown): string`, `normalizeRosterName(value: string): string`, `rosterLookupId(lrn: string, key: string): string`, and `evaluateRosterClaim({roster, lrn, fullName, enrollmentCode, uid, now}): 'auto_approve'|'manual_review'|'conflict'`. Persist HMAC-keyed roster index under `schoolRosterClaims/{digest}`; include `schoolId`, normalized name, a high-entropy enrollment-code digest, claim status/UID, and timestamps. The key is injected via local emulator config or a future separately approved managed secret; never hardcode it or write it into source.

- [ ] **RED:** Test five fixture cases: three valid unclaimed school-coded auto matches, one no-code manual review, one already-claimed UID conflict. Verify normalize/padding behavior, wrong name, wrong code, same-code retry, expiry if represented, and inability to infer a roster doc path from LRN alone.
- [ ] **RED:** Test the seeder refuses absent/remote `FIRESTORE_EMULATOR_HOST`, mismatched `GCLOUD_PROJECT`, non-loopback hosts, and any project other than `demo-resqme`; refuse existing fixture collisions unless exact synthetic origin can be proved.
- [ ] Run `npm --prefix functions test`, observe failing new tests.
- [ ] **GREEN:** Implement minimal pure match functions and a seed tool with a hard `demo-resqme`/loopback guard. The fixture may expose **only fabricated** codes to local tests; the seeded roster stores code digest, never plaintext. No Cloud hosted writes are permitted in this task.
- [ ] Re-run `npm --prefix functions test`, `npm --prefix functions run build`, `git diff --check`. **Do not execute the seeder or launch the emulator until its credential blocker is cleared.**

**Acceptance:** Five synthetic test rows demonstrate the approved outcomes, with no available path to accidentally seed a live project.

## Task 3 — Atomically register, claim roster or defer to manual review

**Files:**
- Modify: `functions/src/registration/create_student_registration.ts`, `functions/src/registration/registration_contract.ts`.
- Modify: `functions/src/profile/get_my_student_profile.ts` (minimal owner-projected status; raw LRN/code excluded).
- Modify: `lib/features/registration/models/student_registration_profile.dart` and `lib/features/registration/services/firebase_student_registration_repository.dart` (decode new safe status and preserve Auth retry behavior).
- Test: `functions/test/create_student_registration.test.ts`, `functions/test/get_my_student_profile.test.ts`, `functions/test/registration_integration.test.ts`, `test/features/registration/firebase_student_registration_repository_test.dart`, `test/features/registration/registration_models_test.dart`.

**Interfaces:** Same callable request name. The transaction reads existing `studentProfiles/{uid}` and synthetic/trusted `schoolRosterClaims/{digest}` before writing; it creates `studentProfiles/{uid}` and acknowledgment atomically and updates `claimedByUid` only on a verified match. New private profile fields: `lrn` (string, server-only), `schoolApprovalStatus` (`approved` only on claim; else `pending`), `schoolAssignmentStatus` (`assigned` only from matching trusted roster; else `unassigned`), `schoolVerificationMethod` (`roster` or `null`), and a non-sensitive `schoolVerificationOutcome` for owner UI (`verified`/`manual_review`/`conflict`). Preserve the existing `status` assignment separately, subject to the documented minor-state mismatch review. `getMyStudentProfile` returns only its existing allowlist plus the new safe status, not the raw LRN or code.

- [ ] **RED:** Write callable contract/integration tests proving forged school/status/reviewer fields are rejected or ignored; valid code+LRN+name sets approved/assigned/method roster; missing/invalid code sets pending; wrong school and duplicate claim never approve; no raw code in documents or responses.
- [ ] **RED:** Test racing two UIDs for one roster row (one wins), and Auth+callable timeout followed by same-UID identical retry (one acknowledgment, no re-consume, same result). Changed immutable registration data, including LRN, must return `already-exists` without mutation.
- [ ] **RED:** Test legacy `schemaVersion:1, lrn:null` profiles still load without granting enrollment. Verify owner projection excludes raw LRN and enrollment code.
- [ ] Run `npm --prefix functions test` / relevant Flutter tests to observe RED failures. Defer emulator-only cases if blocked; mark unrun, not passed.
- [ ] **GREEN:** Extend the existing transaction; do not create a second registration callable or use a client-side roster lookup. Fail closed on roster/secret/backend unavailability: never auto-approve; decide explicitly between safe pending and rejecting the request when data integrity is uncertain (no silent partial-write success).
- [ ] Re-run focused tests, `npm --prefix functions run build`, Flutter focused tests and diff checks.

**Acceptance:** No duplicate code claims, no account takeover based on LRN alone, no elevated school status from untrusted fields; retries do not fork records.

## Task 4 — Issue and display an inert pending QR with Tier 1 available

**Files:**
- Modify: `functions/src/qr/ensure_my_tier1_qr.ts`.
- Modify: `lib/features/qr/services/tier1_qr_repository.dart`, `lib/features/qr/screens/my_unverified_qr_screen.dart`, `lib/features/registration/screens/registration_pending_screen.dart`.
- Test: `functions/test/ensure_my_tier1_qr.test.ts`, `test/features/qr/onboarding_test.dart`, `test/features/registration/registration_pending_screen_test.dart`; create `test/features/qr/my_pending_qr_screen_test.dart` if the existing widget coverage is insufficient.

**Interfaces:** Preserve `ensureMyTier1Qr({})`; return `{payload: string, verificationStatus: 'pending'|'active', issuedAt: string}`. Mint one `resqme:v1:<32 random bytes base64url>` credential per registered owner with status `pending`; its public lookup must remain absent or non-active. Flutter `Tier1QrRepository` returns a typed `{payload, verificationStatus}` result instead of hard-rejecting non-active QR. Do not treat `pending` as authorization.

- [ ] **RED:** Test registered pending/minor/adult owners get exactly one stable pending payload across repeats; no pending lookup becomes active; a second UID cannot read the payload; unauthenticated or absent profile fails closed.
- [ ] **RED:** Widget tests show the QR plus **Pending Verification**, `Go to Dashboard`/public Tier 1, scanner and logout as before, with clear “not yet active” explanation. Network/offline failure must not block the public dashboard. QR never contains student name/LRN/medical data.
- [ ] Run relevant Functions and Flutter focused tests to observe RED failures.
- [ ] **GREEN:** Preserve opaque QR generation, idempotency and existing navigation; make credential state explicit without creating duplicate QR documents, and remove only the old UI assumption that every displayed QR is active.
- [ ] Run `npm --prefix functions test`, `flutter test test/features/qr`, `flutter test test/features/registration`, `flutter analyze`, `git diff --check`.

**Acceptance:** A manual-review student immediately has a displayable *non-active* QR and every public Tier 1 feature remains available.

## Task 5 — Authorized, audited manual school review

**Files:**
- Modify: `functions/src/school/approval_contract.ts`, `functions/src/school/approve_student_qr.ts`, `functions/src/school/revoke_student_qr.ts` (retain existing names).
- Create: `functions/src/school/get_school_review_candidate.ts` (bounded same-school candidate read by exact UID; do not add broad roster search).
- Modify: `functions/src/index.ts` (export only the single new reviewer callable).
- Create: `lib/features/school/screens/school_review_screen.dart`, `lib/features/school/services/school_review_repository.dart` (minimal reviewer sign-in-gated manual flow, reuse existing Auth/Firebase client).
- Test: `functions/test/school_approval.test.ts`, `functions/test/eligibility_integration.test.ts`, `test/features/school/school_review_screen_test.dart`.

**Interfaces:** Reuse `schoolReviewers/{reviewerUid}` with `{active:true, schoolId:string}` created **only by a separately authorized operator** (emulator-only reviewer fixture permitted for local tests). `getSchoolReviewCandidate({studentUid})` returns only same-school minimal student name, review status and UID; `approveStudentQr({studentUid,requestId})` retains its idempotent audited approval. School approval checks trusted reviewer, school assignment and pending school decision **without checking medical completion**; QR activation still checks medical independently. No user-provided reviewer UID, school ID or self-approval.

- [ ] **RED:** Reviewer tests: active same-school reviewer can read and approve a pending assigned student; inactive/cross-school/student/unauthenticated caller cannot; unassigned unknown LRN cannot be approved by an arbitrary school; exact repeated request ID is idempotent; altered request ID/digest and self-review reject; revocation remains effective.
- [ ] **RED:** Approved student with incomplete medical remains QR pending; existing test that requires medical completion *for school approval* must be intentionally updated to reflect separation of concerns.
- [ ] **RED:** Flutter admin screen tests show trusted review candidate, explicit approve confirmation, loading/error/retry states, and no public route exposing candidate data. Entry uses authenticated account, **not a QR as sole login**. Student displays an owner-only copyable UID/review reference to support manual lookup; never publicly disclose it.
- [ ] Run unit/widget tests for meaningful RED; integration RED only after emulator blocker cleared.
- [ ] **GREEN:** Reuse current transaction/audit and same-school policy; create candidate callable and minimal client screen. Do not create a reviewer-registration screen or automatically grant `schoolReviewers` status. No Admin Portal QR or staff master QR in this plan.
- [ ] Re-run `npm --prefix functions test`, `npm --prefix functions run build`, `flutter test test/features/school`, `flutter analyze`, `git diff --check`.

**Acceptance:** A real reviewer *already provisioned by an authority* can approve manually, independently of the student's medical completion; no unauthorized person can.

## Task 6 — Centralize activation, minor gate and QR revocation

**Files:**
- Modify: `functions/src/onboarding/authorization.ts`, `functions/src/qr/ensure_my_tier1_qr.ts`, `functions/src/qr/resolve_tier1_qr.ts`, `functions/src/qr/replace_my_tier1_qr.ts`, `functions/src/school/revoke_student_qr.ts`.
- Create: `functions/src/qr/qr_eligibility.ts` (one authoritative predicate for activation and public resolution).
- Test: `functions/test/medical_eligibility.test.ts`, `functions/test/resolve_tier1_qr.test.ts`, `functions/test/replace_tier1_qr.test.ts`, `functions/test/eligibility_integration.test.ts`.

**Interfaces:** `evaluateQrEligibility({profile,medical,guardianAuthorization,credential}): boolean` checks schema, assigned trusted school, approved school decision, complete `studentMedicalRecords/{uid}` with `selfReported:true` and `syntheticOnly!==true`, coherent profile medical revision, a valid intact credential, and guardian proof for minors. Do not interpret guardian contact, student acknowledgment or `pending_guardian` as verified consent. `ensureMyTier1Qr` may atomically transition a *pending* credential/index to `active` only after this evaluation; `replaceMyTier1Qr` cannot bypass it. Explicitly `revoked` credential/approval never silently becomes active. `resolveTier1Qr` returns **only** `{active:boolean}`.

- [ ] **RED:** Test auto-approved adult with no medical stays inactive, adult with full medical becomes active on owner refresh, minor with full medical but no trusted guardian proof stays inactive, and revoked/old/replaced QR stays inactive. Check owner status display follows server response, not optimistic local state.
- [ ] **RED:** Test resolver for unknown/pending/revoked/active/malformed payloads has no other keys, no name/UID/LRN/medical data, and preserves existing rate limiter. Cross-account authentication cannot force activation.
- [ ] Run unit tests for RED; run integration tests only if allowed.
- [ ] **GREEN:** Extract shared eligibility function and integrate it in issuance, replacement and resolver. Keep Firestore reads/writes in transactions where concurrent approval/revocation could otherwise race. A missing guardian authorization mechanism must be treated as `false`, never simulated as approved for hosted use.
- [ ] Run `npm --prefix functions test`, `npm --prefix functions run build`, `flutter test test/features/qr`, `git diff --check`.

**Acceptance:** School approval is necessary, never sufficient, for activation. A pending QR cannot upgrade Tier 2 access; revoked QR stays revoked.

## Task 7 — Full regression, synthetic demo walkthrough and handoff

**Files:**
- Test: `functions/test/registration_integration.test.ts`, `functions/test/eligibility_integration.test.ts`, `functions/test/rules.test.ts`, `functions/test/deny_all_rules.test.ts`; pertinent existing Flutter tests.
- Create: `docs/resqme-school-verification-demo-qa.md` (short demo script, verified statuses, blockers and synthetic-resource accounting).

- [ ] **RED before final implementation signoff:** Add emulator integration cases for all five fictional fixture outcomes, two-UID races, same-UID retry, manual approval, pending QR before/after medical, revoked QR, cross-school denial and no direct Firestore client writes.
- [ ] Run `npm --prefix functions test`, `npm --prefix functions run build`, `flutter analyze`, `flutter test test/features/registration`, `flutter test test/features/qr`, `flutter test test/features/school` (if created), and `git diff --check`. State exact counts/errors; never reuse old PASS totals as fresh results.
- [ ] **Conditional only:** Once the operator confirms the isolated Firebase CLI credential issue is resolved, execute existing sanctioned emulator workflow and `npm --prefix functions run test:integration` / `npm --prefix functions run test:rules` / `npm --prefix functions run test:rules:contained`, using verified emulator-only endpoints and the exact synthetic fixture. If blocked, record **NOT RUN**, do not switch to a new emulator or hosted project.
- [ ] **Conditional only:** On attached Android device, exercise public Tier 1, registered pending QR, QR scan inactive screen, account switching and review UI against a verified safe local environment. No hosted calls, installation or settings change without separate approval. Record actual device/OS and evidence (redact QR tokens, LRN and contacts).
- [ ] Verify `firestore.rules`, `storage.rules` if present, `firebase.json`, runtime identity, App Check and approved hosted Functions were **not modified by this plan**. Inspect `git status --short` to protect pre-existing changes.
- [ ] Deliver QA report with pass/fail/blocked per scenario, exact touched files, remaining guardian authorization/admin provisioning/roster import/runtime IAM prerequisites, and recommended demo order: public Tier 1 → pending registration → three roster matches → admin manual review → QR activation for eligible adult only → inactive/revoked scan.

**Acceptance:** All runnable tests pass; any environment/authority-dependent case is honestly marked BLOCKED/NOT RUN. No unapproved hosted side effect has occurred.

---

## Implementation checkpoints (do not assume authorization to commit)

1. **Contract gate:** Required LRN and optional manual-fallback code do not break registration/Auth retry.
2. **Roster gate:** Five emulator-only rows with safe guard and atomic single use.
3. **Server gate:** Auto approval and manual reviewer approval enforce independent trust and maintain idempotency.
4. **QR gate:** Pending QR visible immediately; server-only eligibility safely gates activation, including minors.
5. **Demo gate:** Local/emulator/device results are recorded with clear NOT RUN, zero hosted mutation and remaining authorization requests.

Suggested commit boundaries, **only if the owner separately requests commits**: `(1) validation+form`, `(2) local roster+claim transaction`, `(3) pending QR`, `(4) reviewer flow`, `(5) activation+QA`. Stage exact files only. No automatic push.

## Explicit deferred decisions / hard stops

- **Real roster:** A school-provided authoritative data export, import approval, record retention rule, and secure code distribution are prerequisites for production-scale automatic verification. The five sample records are **not** real identity proof.
- **Guardian verification:** Implementation and authentic guardian consent evidence must be approved separately; minors stay pending in the meantime. Guardian contact details do not equal consent.
- **Reviewer:** An authorized school operator must separately provision an actual reviewer and school mapping; do not fabricate the account or privilege, including for hosted staging.
- **Hosted permissions and deployment:** Any Function export change, runtime `datastore.entities.update` permission, Firestore index, new secret, IAM/API and G4 deployment test requires explicit new scoped approval. Previous G4 acceptance is evidence of the older deployed candidate, **not approval to deploy these changes**.
- **Portal QR and Tier 2 master QR:** Deferred; they are not a way to bypass reviewer login or per-student Tier 2 authorization.

## Agent execution handoff

1. Read the design and plan in full.
2. Reconcile paths/status with the local Windows checkout; if materially mismatched, **pause and present a targeted plan correction**.
3. Work one task at a time using RED→GREEN→verification. Never touch unrelated files or perform hosted actions.
4. Report each gate as PASS, FAIL or BLOCKED, then request owner review before any deployment, reviewer provisioning or real-school data import.
