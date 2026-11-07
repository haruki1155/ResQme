# ResQMe Tier 1 Registration Completion and QR-Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` to implement this plan task by task. Use `superpowers:test-driven-development`, `superpowers:systematic-debugging` on failures, and `superpowers:verification-before-completion` before declaring a task complete. Every executable step below is a checkbox.

**Goal:** Complete the approved Tier 1 registration milestone (Tasks 3–6), verify its security and user experience on Android phones/tablets, and prepare a **separate, reviewable QR feature design** without prematurely issuing or approving QR credentials.

**Architecture:** Existing Firebase Auth + authenticated `createStudentRegistration` callable + private Firestore profile remain the sole registration trust path. Flutter receives an injectable repository, drives a versioned privacy-acknowledgment form, displays pending states, and gates protected navigation. QR eligibility remains server-controlled and disabled until a separately designed verified approval path exists.

**Tech Stack:** Existing ResQMe Flutter/Dart Android app, Firebase Auth, Firestore, Cloud Functions TypeScript, Firebase Emulator Suite, Flutter tests, Functions tests, Firestore Rules tests, debug APK, Android phone/tablet or emulator.

**Approved specification:** `docs/superpowers/specs/2026-11-04-resqme-tier1-registration-design.md`.

**Existing detailed plan:** `docs/superpowers/plans/2026-11-05-resqme-tier1-registration-implementation.md`. **This is a completion addendum, not a replacement**. If it conflicts with that plan or the approved specification, stop and present the exact difference before changing product behavior.

## 1. Reported baseline and what is not yet done

| Work | Reported status | Evidence given by project owner |
|---|---|---|
| A0 public foundation | Previously implemented | Splash, Terms/Privacy, public dashboard and emergency resources; earlier tests/debug APK reported passed |
| Task 1: registration contract/validators | **Committed** | `7cafaf6` — model, validators and minor/adult calculation |
| Task 2: protected backend and Rules | **Committed** | `adae29c` — 7 Functions unit, 3 callable integration, 2 Rules tests, build and diff check passed |
| Task 3: client repository/recovery | **Not started** | No client Auth/callable repository implementation reported |
| Task 4: registration UI/dialog | **Not started** | No themed form/dialog implementation reported |
| Task 5: sign-in/pending UI | **Not started** | No sign-in/recovery/pending screens reported |
| Task 6: access gate/regression | **Not started** | No registration navigation/device acceptance reported |
| QR issuance/verification/replacement | **Outside this milestone** | Requires separate reviewed authority, privacy and QR lifecycle specification |

These statuses are based on the owner's reports, not a direct inspection of the development checkout. The executing agent must verify them locally before acting.

## 2. Hard boundaries and workflow rules

1. **No duplicate worktree:** Use the existing checkout and preserve the pre-existing untracked `docs/mockups/` and all unrelated changes. Inspect `git status --short`, branch, latest commit, `AGENTS.md`, and actual project paths first. Never reset, clean, force-push, or stage unrelated files. Stage explicit task files, not `git add -A`.
2. **No remote side effects:** Do not push, merge, deploy, initialize release/profile Firebase, import real school records, create live users, change IAM/billing, or send messages. Use local synthetic fixtures and the project's existing debug-only setup.
3. **Already completed means completed:** Do not rewrite Tasks 1–2 or require rerunning the earlier integration suite before beginning Task 3. Re-run relevant checks at the final gate. Change a Task 2 contract only if a failing test proves it necessary, with a scoped fix and regression test.
4. **Node compatibility:** Installed local Node `24.18.0` is acceptable for existing local tests; configured Functions runtime `22` is a separate deployment-parity requirement. Do not automatically install Node 22, alter `engines.node`, or stop UI work simply because Node 22 is not installed. Record the runtime mismatch as a predeployment check. If a test actually fails because of the mismatch, investigate and report concrete evidence.
5. **One task at a time:** For each task, add failing tests (RED), implement smallest change (GREEN), refactor safely, run focused tests, inspect diff, and commit with the specified message. If the existing working tree overlaps a task, first isolate and protect user changes; stop for direction if safe integration cannot be established.
6. **Registration does not establish enrollment:** `pending_guardian` (under 18) and `pending_review` (18+) are the only new registration outcomes. No school review logic, email verification, guardian verification, account claim, `approved` mutation, QR minting, or Tier 2 access is allowed.
7. **Keep data minimal:** Required name, age, email, password and confirmation; optional gender, student's contact number, guardian contact details, secondary emergency-contact pair. No Student ID, `studentIdClaimed`, LRN entry, academic, medical, physician, biometrics, nurse-role or Tier 2 fields. A listed guardian is a contact, **not authorization**.
8. **No contact leaks:** Passwords are Auth-only, never written to profile or logs. Names, email, age and contact details are private and may not appear in public QR or anonymous routes. Unknown state or failed profile read must fail closed while retaining public emergency features.

## 3. Preflight: confirm integration points (read-only)

- [ ] Check `git status --short`, `git log -3 --oneline`, branch, and presence of commits `7cafaf6` / `adae29c`. Preserve `docs/mockups/`; do not commit it accidentally.
- [ ] Read repository `AGENTS.md`, the approved specification, existing implementation plan, `pubspec.yaml`, app router/dashboard, `lib/features/registration/`, Functions callable export, `firestore.rules`, `firebase.json` and test commands.
- [ ] Map proposed paths below to the actual project layout. Prefer the existing Dependency Injection, state management, error types, routing and theme. Do not introduce a second Firebase initializer or duplicate router.
- [ ] Confirm callable request/response names, error codes, emulator project ID (`demo-resqme`) and ports from Task 2's tests. Reject unsafe endpoint/project fallback; do not connect to staging by accident.
- [ ] Establish a fast baseline: `flutter test test/features/registration/registration_validators_test.dart`, `npm --prefix functions test` and `npm --prefix functions run build` if tools are available; report pre-existing failures separately. This is a check, not a reason to restart Task 2.
- [ ] Publish a brief preflight note naming actual integration paths and any mismatches before editing code. Proceed automatically if they are consistent.

## 4. Task 3 — Flutter registration repository and safe partial-failure recovery

**Create or adapt:**

- `lib/features/registration/services/student_registration_repository.dart`
- `lib/features/registration/services/firebase_student_registration_repository.dart`
- `test/features/registration/firebase_student_registration_repository_test.dart`

**Contract:** An injectable interface supporting `register(RegistrationDraft, {required bool acknowledged})`, `signIn(email, password)`, `sendPasswordReset(email)`, `loadOwnProfile()` and sign-out as appropriate for existing app conventions. Use typed results for `pending`, `authCreatedProfileIncomplete`, `offline`, `failure`; do not return an unrestricted/approved identity.

- [ ] **RED — acknowledgment:** Test `acknowledged:false` makes **zero** Auth/callable requests, and the full notice version `tier1-registration-v1` is supplied on the accepted path.
- [ ] **RED — success:** Test exactly one Auth account creation, then exactly one authenticated callable invocation; verify only allowed non-password fields go into its request.
- [ ] **RED — errors:** Test duplicate email, bad credentials, offline/unavailable callable, malformed/absent own profile and a safe user-facing retry message with no leaked internals.
- [ ] **RED — partial write:** Simulate Auth creation succeeding and callable failing; require `authCreatedProfileIncomplete`. On retry with the authenticated user, invoke **only** the callable; never create another Auth account or allow protected navigation.
- [ ] **RED — idempotency and leakage:** Simulate repeat submit/taps; password, confirmation, contacts and tokens must not leak through diagnostics. No automatic profile overwrite or status elevation.
- [ ] Run `flutter test test/features/registration/firebase_student_registration_repository_test.dart` and confirm meaningful failures.
- [ ] Implement the smallest injectable adapter using existing project Firebase clients and Task 2's exact callable contract. Firebase Auth handles credentials; registration payload is minimized.
- [ ] Re-run the focused suite, `flutter analyze` for touched code, and `git diff --check`. Fix problems or stop with an evidence-backed blocker.
- [ ] Stage only Task 3 files and commit `feat(resqme): add student registration service and safe retry`.

**Acceptance:** A network fault between Auth and profile creation cannot create a duplicate Auth user, cannot misrepresent an account as approved, and can recover through an explicit retry.

## 5. Task 4 — Registration form and independent privacy acknowledgment

**Create or adapt:**

- `lib/features/registration/screens/create_student_account_screen.dart`
- `lib/features/registration/widgets/registration_privacy_dialog.dart`
- `test/features/registration/create_student_account_screen_test.dart`

- [ ] **RED — form:** Test required name, integer age, email, password, confirmation; optional gender, personal phone and guardian contact fields; secondary contact name+phone pair; inline validation. Confirm Student ID, LRN, school/academic, medical, physician and Tier 2 fields are absent.
- [ ] **RED — dialog:** Test exact approved title `Data Privacy & Registration Authorization`, explicit description of fields/processing, full Privacy Notice access, notice version, **unchecked** checkbox, and disabled `Agree & Create Account` until checked.
- [ ] **RED — no false consent:** Test `Decline` and closing the dialog create neither Auth user nor profile. For under-18 age, explicitly state that the student's checkbox is **not** guardian authorization; guardian status remains pending.
- [ ] **RED — responsiveness:** Test scroll/keyboard interactions and legible scaling at narrow phone and tablet widths; no overflow, lost submit button, or duplicate submissions.
- [ ] **RED — feedback:** Test loading, inline validation, offline retry, email-in-use, partial Auth success/callable failure and success routing; avoid false “account complete” confirmation.
- [ ] Run focused widget tests and confirm meaningful RED failures.
- [ ] Implement one scrollable, themed form with sections `Personal information`, `Emergency contacts (optional)`, `Account credentials`, and privacy dialog before any Auth call. Keep secrets obscured and in transient form state.
- [ ] Run focused tests, `flutter analyze`, `git diff --check` and synthetic phone/tablet screenshot or available visual check. Record any device limitation.
- [ ] Commit only Task 4 files as `feat(resqme): add basic student registration and privacy dialog`.

**Acceptance:** Registration is easy on Android phones/tablets and does not falsely claim that student acknowledgment grants guardian enrollment authorization.

## 6. Task 5 — Sign-in, password reset and pending-state screens

**Create or adapt:**

- `lib/features/registration/screens/student_sign_in_screen.dart`
- `lib/features/registration/screens/registration_pending_screen.dart`
- `test/features/registration/student_sign_in_screen_test.dart`
- `test/features/registration/registration_pending_screen_test.dart`

- [ ] **RED — sign-in:** Test valid and invalid email/password, loading, generic bad-credential feedback, links to Create account and Forgot password, and signing out.
- [ ] **RED — recovery:** Test Firebase email/password reset request and non-disclosing confirmation. This must never mark the user's email, school enrollment or guardian authorization verified.
- [ ] **RED — adult pending:** Verify `pending_review` displays `Registration received — pending school review` and does not expose My QR, Tier 2, approval, or school-verification actions.
- [ ] **RED — minor pending:** Verify `pending_guardian` displays `Registration received — guardian authorization pending` with a clear explanation that this milestone does **not** perform guardian verification.
- [ ] **RED — owner actions:** Test `Return to public dashboard`, `View registration status`/refresh, `Sign out`, and an initially collapsed owner-only read-only `Review submitted details`. Do not show private details in anonymous mode.
- [ ] Run both focused widget suites to observe RED failures; implement screens in established ResQMe theme/navigation.
- [ ] Run focused tests, `flutter analyze`, and `git diff --check`; capture UI QA if possible.
- [ ] Commit only Task 5 changes as `feat(resqme): add student sign-in and pending screens`.

**Acceptance:** A pending adult or minor can sign in, see their actual pending status, recover their password and use public resources without gaining restricted access.

## 7. Task 6 — Route/access integration and full Tier 1 regression

**Create or adapt:**

- `lib/features/registration/widgets/student_access_gate.dart`
- Existing top-level router / public-dashboard entry points identified at preflight (do not invent a parallel router)
- `test/features/registration/student_access_gate_test.dart`
- Existing splash, privacy, public dashboard and navigation tests

- [ ] **RED — route matrix:** Test anonymous→public/dashboard or sign-in entry; signed-in `pending_review`→adult pending; `pending_guardian`→minor pending; signed-in with missing profile→restricted recovery; unknown/malformed/rejected/deactivated state→public-only/restricted fallback.
- [ ] **RED — privilege guards:** Assert no QR/Tier 2 route for anyone in this milestone, **including a synthetic `approved` field**. Signed-in state, entered age and owner-profile read are not sufficient authorization.
- [ ] **RED — privacy:** Test unauthorized profile reads/contacts do not appear in public screens and that auth/rules errors do not reveal records.
- [ ] **RED — regression:** Verify existing Splash → Terms/Privacy → public emergency dashboard remains available without account. First aid, hotlines and DRRM remain reachable; preserve their documented offline behavior.
- [ ] Implement gate using current routing/state management, server-owned status and explicit profile load/reload on startup/sign-in. Deny during loading/unknown/offline; allow public functions regardless.
- [ ] Run focused route tests to GREEN, then `flutter test`, `flutter analyze`, and `flutter build apk --debug`. Record exact pass/fail and exit status.
- [ ] Revalidate backend: `npm --prefix functions test`, `npm --prefix functions run build`, `npm --prefix functions run test:integration`, and `npm --prefix functions run test:rules` **with the project's documented emulator-safe runners**. Prevent port collisions, test against `demo-resqme` on loopback only, and never point at real Firebase. Record skipped/unavailable checks explicitly.
- [ ] Run `git diff --check`, inspect actual staged paths, and verify no unrelated `docs/mockups/` content was staged.
- [ ] Perform synthetic-data phone + tablet or emulator acceptance: unchecked/declined privacy, 17 and 18 registrations, Auth created/profile write failure and retry, repeat taps, login, reset, sign-out, pending screens, offline, and anonymous public resources. If not available, mark **device acceptance pending**, not passed.
- [ ] Commit scoped Task 6 files as `feat(resqme): gate pending student accounts and preserve public access` **only after the required automated tests pass**. If tests fail, do not mark complete; give a precise blocker and preserve work.

**Acceptance:** The new navigation integrates with existing public Tier 1 functionality and is fail-closed across missing profiles, bad server state and offline conditions.

## 8. Milestone gate: safe to design QR, not yet safe to issue QR

Before announcing “registration complete”:

- [ ] Confirm Tasks 3–6 each have a focused, reviewed commit and tests were rerun after the final code changes.
- [ ] Provide evidence that students cannot self-approve, cannot client-write `status`/LRN, and cannot access other profiles or restricted routes.
- [ ] Confirm privacy acknowledgment and guardian authorization are separate; all minor accounts remain `pending_guardian` and adult accounts `pending_review`.
- [ ] Confirm there is **no** QR issuance, verification, admin approval, Excel import or Tier 2 behavior in this registration milestone.
- [ ] Report any outstanding device acceptance, Node 22 runtime parity and school/legal/privacy review as explicit **release blockers**, not hidden implementation failures.
- [ ] Stop and request QR design approval; do **not** proceed to QR code by implication.

### QR Phase Q0 — next separate *design* package

After the registration gate, prepare a **new Superpowers QR design specification for review**. It should resolve the following decisions before creating QR code or allowing a status transition:

| Topic | Required decision or design guard |
|---|---|
| Eligibility | QR issuance only after a **trusted, verified `approved` state**; pending accounts never receive a QR. School and guardian verification rules are deferred and must be specified before real approvals. |
| Identifier | Opaque random/non-guessable QR reference or short-lived signed lookup token; never raw LRN, UID, email, or medical data in the QR payload. |
| Public result | Minimum authorized identity/status response only; no email, phone, guardian, private profile, academic or medical details. Exact public fields need approval. |
| Scanner states | Camera permission granted/denied, scanning, no camera, loading, offline, invalid/unknown, locked, revoked and expired. |
| Lifecycle | Server-side issue, expiry, rotation, lock/unlock, lost-ID reporting, replacement and old-token invalidation; define replay and printed copy behavior. |
| Student UI | My QR display, save/print/share policy, regeneration confirmation, locked/replaced/expired states; only when eligible. |
| Staff/admin | Role and tenant-scoped lookup and lock/replacement actions; audit and step-up authorization policy. No pretend master-admin role. |
| Data separation | Public QR verification service must not read Tier 2 records or unprotected registration profiles. |
| Testing | Emulator Rules/callable abuse cases, ID guessing, cross-tenant reads, unauthorized issue/unlock, retired QR rejection, offline and camera-permission UX. |

**Fast parallel preparation allowed:** The agent may draft Q0 questions, screen inventory and synthetic tests *as a separate non-executable proposal* while finalizing Task 6. It may not implement issuance, create approved users in live data, or relax security gates.

## 9. Agent operating instructions and reporting template

Implement **Tasks 3 → 4 → 5 → 6 sequentially**. Do not ask for permission at each passing test/commit; ask only on actual authorization, product-contract or conflicting-user-change blockers. Use the existing checkout (no new worktree). After each task return a concise checkpoint:

```text
Task N: COMPLETE | BLOCKED
Commit: <hash or none>
Files changed: <scoped paths>
Tests: <command> — <pass/fail count> — exit <code>
Security: <specific guard proven>
Unresolved: <specific issue or none>
Next task: N+1 (only if current task complete)
```

At final handoff, include branch, complete commit sequence, changed-file summary, full validation matrix, Android phone/tablet acceptance (pass/pending), Node 24 local vs Node 22 deployment runtime caveat, `git status --short`, and a QR Q0 review checklist. **No push, merge, remote deployment or real-student imports without new authorization.**

### Copy-paste kickoff prompt for the executing coding agent

> Work in my existing ResQMe Flutter/Firebase checkout. Read `AGENTS.md`, the approved registration design at `docs/superpowers/specs/2026-11-04-resqme-tier1-registration-design.md`, the original plan at `docs/superpowers/plans/2026-11-05-resqme-tier1-registration-implementation.md`, and this completion plan. Task 1 (`7cafaf6`) and Task 2 (`adae29c`) have been committed and reported tested. Verify the current checkout, preserve `docs/mockups/` and other user changes, then implement **only Tasks 3–6** in order, using Superpowers execution, TDD, systematic debugging on failure, focused tests, scoped commits and verification before completion. Do not create another worktree, require Node 22 as a prerequisite for Flutter UI work, or modify the Node 22 Functions target merely because local Node 24 is selected. Use `demo-resqme`/loopback-only services for synthetic backend validation and prevent remote Firebase fallback. Never add LRN, Student ID, academic, medical or Tier 2 registration fields. The privacy checkbox records student acknowledgment only; guardian authorization and school approval are deferred. All users stay pending and must have **no QR/Tier 2 access**. Preserve the public dashboard. Record test commands, exact outcomes, commits and remaining gaps. Do not push, deploy, import real students, or implement QR. Stop after Task 6 and present the separate QR Phase Q0 design questions for my approval.
