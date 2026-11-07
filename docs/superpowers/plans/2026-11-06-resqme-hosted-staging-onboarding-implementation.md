# ResQMe Hosted Staging Onboarding and Unverified QR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the existing registration experience to hosted Firebase staging, add a skippable private **synthetic-only** medical-record screen with a dashboard reminder, and issue one stable **unverified** QR for each pending account without changing public emergency access.

**Architecture:** Reuse existing Flutter registration/Auth, the `createStudentRegistration` callable, pending account statuses and fail-closed Firestore Rules. New trusted callable operations save owner-only test records (restricted to QA UIDs) and issue opaque, non-authorizing QR references; Flutter handles the optional medical step and reminder. **No remote deployment until a separate project-owner go/no-go.**

**Tech Stack:** Existing Flutter/Dart Android app; Firebase Auth, Firestore and Cloud Functions TypeScript (configured Node 22 runtime); Firebase Emulator Suite, Flutter tests and Android debug build. Local Node 24 may run tests, with parity caveats documented.

**Spec:** `docs/superpowers/specs/2026-11-06-resqme-hosted-staging-onboarding-synthetic-medical-design.md` — owner-approved 2026-11-06. Preserve the baseline `docs/superpowers/specs/2026-11-04-resqme-tier1-registration-design.md` except for the two explicit synthetic-medical/unverified-QR overrides in the newer spec.

## Global Constraints

- **Synthetic-only medical testing.** Never accept or intentionally import real students' conditions, allergies, contact details, or medical records. No real-data rollout; the school privacy/authorization review remains pending.
- **Status:** Under 18 → `pending_guardian`; 18+ → `pending_review`; neither grants verified school identity. The synthetic medical acknowledgment and unverified QR do not change these states.
- **QR:** Opaque, versioned, cryptographically random, owner-bound and **UNVERIFIED**; no PII or medical content. Not a login credential, public verification result, or Tier 2 key.
- **Consent:** Existing `tier1-registration-v1` notice unchanged. New `synthetic-medical-v1` test acknowledgment is separate. A minor's checkbox never creates `guardianConsentGranted` or `guardianVerified`.
- **Medical:** `unknown`, `none_known`, or `listed` for both conditions and allergies; `listed` requires bounded details. Emergency contact remains private and uses the existing canonical profile representation.
- **Access:** Medical save is restricted server-side to a trusted staging QA UID allowlist or equivalent existing entitlement. Do not let a self-registered client assign tester privileges. A newly registered tester can immediately **Skip** and get an unverified QR; a QA operator must allowlist that UID before test-record saving.
- **Guest:** Public dashboard, first aid, hotlines and DRRM remain accessible without an account, QR, medical completion or network-dependent identity checks.
- **Environment:** `demo-resqme`/loopback-only for emulator tests; explicit `resqme-943ee` for hosted staging debug. No implicit emulator→hosted fallback, release/production Firebase enablement, real-data import, QR scanning, admin roles or Tier 2 features.
- **Git:** Preserve original checkout, user edits and untracked `docs/mockups/`. No new worktrees without permission, no destructive Git, no `git add -A`, no push/merge or remote deployment as part of local commits.

## Review Focus

The following high-risk cases must have tests in their owning task:

1. **QA entitlement:** a newly created account cannot save synthetic medical data until allowlisted; it may still Skip, receive its unverified QR and enter the dashboard (Tasks 2 and 5).
2. **Unknown vs none-known:** a blank condition/allergy answer never becomes “no known”; `listed` with blank details is rejected and valid selections persist (Tasks 2 and 3).
3. **Minor acknowledgment:** the student's checkbox never yields `guardianVerified`, `approved` or a medical/Tier 2 permission (Tasks 2 and 5).
4. **Concurrent sessions:** replayed or stale medical saves cannot silently overwrite a newer entry, and two QR issuance requests produce exactly one credential (Tasks 2 and 4).
5. **Public/private separation:** a guest or different account cannot read medical content, private contacts or QR ownership; public emergency routes work without login (Tasks 2, 4 and 5).

---

## Repository Integration Gate (read-only, before Task 1)

**This planning workspace is not the live Windows ResQMe Git repository.** Paths below are **proposed integration targets**, not proof that corresponding files exist. First inspect the actual repository and conform to its established routing, DI/state, Firebase version and Functions export conventions.

- [ ] Read `AGENTS.md` if present, both specs, this plan, `docs/registration-milestone-results.md`, `docs/registration-local-testing.md`, `pubspec.yaml`, `lib/features/registration/`, existing router/dashboard, `functions/src/`, `functions/package.json`, `firestore.rules` and `firebase.json`.
- [ ] Run `git status --short`, `git log -8 --oneline`, and inspect previous registration/Task 2.5 commits; identify unrelated changes and explicitly preserve them.
- [ ] Map existing `RegistrationDraft`, `StudentRegistrationProfile`, `StudentRegistrationRepository`, `createStudentRegistration`, pending routing and debug Firebase config. Record the actual paths before editing; do not duplicate any component.
- [ ] Read the agent's prior backend metadata-omission and concurrent-session mutation-race findings. Decide whether they affect the new authenticated saves or QR ownership; reproduce with a failing test before any repair.
- [ ] Confirm the local test scripts and project-ID/loopback guards. Record a read-only environment/path summary. Proceed if consistent; stop and ask on a material spec conflict or user-change collision.

### Proposed responsibility map

| Unit | Proposed file or existing integration point |
|---|---|
| Staging selection | Existing debug-only Firebase bootstrap/config + focused environment-selection tests |
| Medical contract | `lib/features/medical/models/synthetic_medical_draft.dart`, `synthetic_medical_record.dart` |
| Medical trusted API | `functions/src/medical/save_synthetic_medical_record.ts` and existing Functions export |
| Medical private access | `firestore.rules`, `functions/test/synthetic_medical_record.test.ts`, `functions/test/medical_rules.test.ts` |
| Medical Flutter adapter | `lib/features/medical/services/synthetic_medical_repository.dart` |
| Medical UI/reminder | `lib/features/medical/screens/synthetic_medical_screen.dart`, `widgets/finish_medical_record_reminder.dart` |
| QR trusted API | `functions/src/qr/ensure_my_tier1_qr.ts` and existing Functions export |
| QR Flutter adapter/view | `lib/features/qr/services/tier1_qr_repository.dart`, `screens/my_unverified_qr_screen.dart` |
| Navigation | Existing registration success, student-profile and public dashboard routes; no second router |
| Tests | Matching `test/features/medical/*_test.dart`, `test/features/qr/*_test.dart`, and existing registration/public tests |

## Task 1 — Hosted staging config and registration compatibility

**Files:** Existing debug Firebase bootstrap/router, `test/` config/auth tests, existing registration repository/Functions if a demonstrated defect requires a narrow fix.

**Interfaces:** Consumes existing Auth `createUserWithEmailAndPassword` + trusted `createStudentRegistration`; produces the same pending profile, safe retry and logged-in state on explicit `resqme-943ee` debug/staging routing.

- [ ] **RED:** Add focused config tests: emulator mode uses `demo-resqme` loopback only; staging mode explicitly uses `resqme-943ee`; invalid/unspecified mode fails closed and cannot silently contact hosted services.
- [ ] Run the focused tests and verify RED for a real gap (do not intentionally break passing code).
- [ ] Reuse existing configuration and implement only required explicit staging routing. Preserve debug-only behavior; do not enable release/profile Firebase or change Functions `engines.node` merely because local Node 24 is installed.
- [ ] **RED:** Add one repository test verifying Auth-created/profile-incomplete retry does **not** repeat signup and does not falsely mark approved. Add a failing regression for any substantiated backend metadata/race defect.
- [ ] Make minimal corrections, run focused tests GREEN, `flutter analyze` and `git diff --check`.
- [ ] Commit scoped changes only if any: `feat(resqme): support explicit hosted staging registration`.

## Task 2 — Private synthetic medical backend, test entitlement and Rules

**Files:** `functions/src/medical/save_synthetic_medical_record.ts` (or established equivalent), Functions export, Firestore Rules, `functions/test/synthetic_medical_record.test.ts`, `functions/test/medical_rules.test.ts`.

**Interfaces:** Suggested `saveMySyntheticMedicalRecord(request)` requiring Auth UID and trusted QA entitlement. Request fields: `conditions:{state:'unknown'|'none_known'|'listed',details?:string}`, `allergies` same, optional canonical `emergencyContact`, `acknowledgment:{version:'synthetic-medical-v1',syntheticDataConfirmed:true,minorNoticeAcknowledged?:true}`, `expectedRevision:number`, `requestId:string`. Server derives pending/minor status and creates a private `completed_synthetic` record with `syntheticOnly:true`, `guardianAuthorizationStatus:'not_verified'`, timestamps and revision. An owner-only read returns the trusted record/status. `clearMySyntheticMedicalRecord()` removes test details and returns to `not_started` while maintaining appropriate audit metadata.

- [ ] **RED:** Unit tests reject unauthenticated, non-QA UID, wrong version, missing synthetic acknowledgment, missing minor acknowledgment, unexpected fields (`uid`, `status`, `lrn`, `guardianVerified`), unsupported state and oversized data; `listed` requires nonblank details.
- [ ] **RED:** Test saved adult/minor records retain pending registration status, do not grant medical staff/Tier 2 roles, record server-controlled `not_verified`, and never log contents.
- [ ] **RED:** Test identical `requestId` replay is idempotent, altered same-ID replay is rejected, and `expectedRevision` conflict prevents stale concurrent overwrite. Test clear/reset status and retry.
- [ ] **RED:** Rules tests: anonymous/cross-user medical and acknowledgment reads/writes denied; owner read allowed; **all client writes denied**; test-only QA permission is checked by callable, not client input.
- [ ] Run focused Functions/Rules suites and observe the expected RED cases.
- [ ] Implement minimal callable transaction, QA allowlist check (trusted backend config only), normalized field validation, canonical emergency-contact update and owner read/clear support. Avoid copying medical fields into `studentProfiles`, public data or QR. Use Admin SDK only after authenticated/authorized checks.
- [ ] Run focused and existing Functions tests, integration tests and Rules tests GREEN; run `npm --prefix functions run build` and `git diff --check`.
- [ ] Commit scoped files: `feat(resqme): store synthetic medical records privately`.

## Task 3 — Optional medical form and dashboard reminder

**Files:** `lib/features/medical/models/synthetic_medical_draft.dart`, `services/synthetic_medical_repository.dart`, `screens/synthetic_medical_screen.dart`, `widgets/finish_medical_record_reminder.dart` and matching widget/repository tests.

**Interfaces:** `SyntheticMedicalRepository.loadMine()`, `.save(SyntheticMedicalDraft draft, {required int expectedRevision, required String requestId})`, `.clearMine()`. UI actions: **Complete now / Skip for now**, **Save Test Record**, dashboard **Finish Medical Record** / **Later** / **View or Update Medical Record**.

- [ ] **RED:** Widget tests for the exact synthetic-only banner and checkbox text in the approved design, optional conditions/allergies/contact fields, unknown/none/listed distinction, disabled Save until test acknowledgment(s), and no medical write on Skip/Decline.
- [ ] **RED:** Under-18 widget tests require the extra **not-verified guardian** acknowledgment; adult does not. Email-verification UI must not claim to send/verify; if shown, disabled `Coming later`.
- [ ] **RED:** Repository tests map permission denial (new QA UID), offline, stale revision and server error to a safe message; no medical content in logs. User can still Skip and reach dashboard/QR.
- [ ] **RED:** Reminder tests show only for signed-in `not_started/incomplete`, do not appear for guests or saved state, are dismissible/snoozable without nagging on every rebuild, and allow later open/edit/clear.
- [ ] Run the focused suites RED, implement UI in existing ResQMe phone/tablet styling, then run GREEN, `flutter analyze` and `git diff --check`. Record narrow-phone and tablet visual QA with synthetic labels only.
- [ ] Commit scoped UI/tests: `feat(resqme): add optional synthetic medical form and reminder`.

## Task 4 — Secure idempotent unverified QR backend

**Files:** `functions/src/qr/ensure_my_tier1_qr.ts`, Functions export, Firestore Rules, `functions/test/ensure_my_tier1_qr.test.ts`, focused QR Rules/integration tests.

**Interfaces:** `ensureMyTier1Qr()` accepts **no client UID/status/token/approval input**; Auth UID and an existing server-created `pending_guardian|pending_review` profile are required. Returns `{payload:string, verificationStatus:'unverified', issuedAt}`. `payload` is a versioned, high-entropy opaque identifier (e.g., random 32-byte base64url component); no public verification endpoint or domain assumption. Private credential is stored once by a trusted transaction keyed by UID.

- [ ] **RED:** Tests reject no Auth, no profile, unknown/rejected/deactivated status and any forged ownership/approved/role/token/medical claims.
- [ ] **RED:** Tests prove two simultaneous calls and repeated calls across sign-in/retry return **one unchanged credential**; no duplicate minting or silent rotation.
- [ ] **RED:** Tests prove QR payload contains no email, name, age, LRN, contact, condition or allergy, and cannot be used to read a private profile or unlock Tier 2.
- [ ] **RED:** Rules tests deny anonymous/other-user QR record reads and every client create/update/delete; owner QR access is via authenticated read/callable only.
- [ ] Run RED tests, implement minimal authenticated callable/transaction + private Rules, then focused Functions/integration/Rules GREEN, build, diff check.
- [ ] Commit scoped files: `feat(resqme): issue unverified tier1 account qr`.

## Task 5 — My QR, onboarding integration and public-access regression

**Files:** `lib/features/qr/services/tier1_qr_repository.dart`, `screens/my_unverified_qr_screen.dart`; existing registration success, dashboard/profile and router integration; matching widget/navigation tests.

**Interfaces:** `Tier1QrRepository.ensureMine()` retrieves server-issued QR; `MyUnverifiedQrScreen` renders that payload with **UNVERIFIED — not proof of school enrollment** and Retry/Go to Dashboard actions. No QR scan/verify or Tier 2 access.

- [ ] **RED:** Integration widget test `register → Complete now (QA-enabled) or Skip → ensure unverified QR → Dashboard`; medical failure/QA denial still permits Skip and QR.
- [ ] **RED:** Tests for partial Auth/profile failure and QR callable timeout: no duplicate Auth account, registration profile or QR; safe Retry; signed-in restart displays same QR.
- [ ] **RED:** Tests for login/logout/profile switching, private medical/reminder isolation, and unknown state; no private data displayed on guest or public screens.
- [ ] **RED:** Confirm Splash → Terms/Privacy → guest dashboard, first aid, hotlines and DRRM still work without registration or medical completion.
- [ ] Run focused tests RED, integrate screens/routes in the **existing** app architecture, then focused/full Flutter tests GREEN, `flutter analyze`, `flutter build apk --debug`, `git diff --check`.
- [ ] Commit scoped files: `feat(resqme): connect staging onboarding medical skip and my qr`.

## Task 6 — Full acceptance and staged deployment handoff

**Files:** Existing local runbook plus `docs/registration-staging-onboarding-acceptance.md` if no suitable checklist exists. Do not invent a production-release pipeline.

- [ ] Run `flutter test`, `flutter analyze`, `flutter build apk --debug`, `npm --prefix functions test`, `npm --prefix functions run build`, `npm --prefix functions run test:integration`, and `npm --prefix functions run test:rules` with the **documented emulator-safe invocation** and `demo-resqme` loopback checks; record exact exits/pass counts. Missing emulator/device is **not PASS**.
- [ ] Recheck security matrix: owner-only medical/QR; QA UID restriction; no client status/guardianVerified writes; medical never in QR, public query, crash logs or notifications; pending status unchanged; guest public features intact.
- [ ] Recheck staging project selection `resqme-943ee`, configured Node 22 deployment runtime vs local Node 24, Auth provider/App Check/debug requirements, exact Functions + Rules changes, and any metadata/concurrency issue left unresolved.
- [ ] Produce a precise **staging deployment manifest**: resources to deploy, commands, expected billing/permissions risk, smoke cases, rollback steps, and confirmation that no production or unrelated Functions will be changed.
- [ ] **STOP and request a separate owner go/no-go for hosted staging changes.** Local code/test commits do not authorize deployment. Do not change IAM, billing, provider settings or project-wide rules outside reviewed scope.
- [ ] Once explicitly approved, deploy only listed staging resources and run synthetic Auth/profile/medical Skip/QA allowlist→Save/QR/login/logout/restart/reset/guest-dashboard phone/tablet smoke. Record installed APK hash, selected project, pass/fail, and any unverified device check. Never use real student medical information.
- [ ] Provide final commits, `git status --short`, validation matrix, deployed resource IDs (if approved), remaining parity/privacy/retention/guardian blockers and the next separate QR scanner/verification milestone.

## Final milestone gate

Successful local implementation means **all tasks' automated tests pass**, no non-synthetic medical data were introduced, all newly registered accounts remain pending, and only non-authorizing unverified QR is issued. It does **not** mean the school has approved medical processing, guardian email verification is working, QR public verification exists, or the app is ready for real-student use.

**Recommended execution method:** Native sequential execution in the current checkout with one final whole-branch review, because the tasks share Auth, Firestore Rules, staging routing and navigation. It minimizes duplicated worktrees and storage. Implementation approval and the later **hosted staging deployment approval** should be recorded separately.
