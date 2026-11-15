# ResQMe Final Tier 2 Completion and Acceptance Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` for native sequential implementation after owner approval. No additional agents or worktrees are authorized. Steps use checkboxes for tracking.

**Status:** Owner approved native local execution and subsequently authorized the focused backend/navigation corrections on baseline `main` / `7ea3b1f`. Local automated verification now passes (150 Functions tests, 154 Flutter tests, clean analysis). Current results are in `docs/qa/resqme-tier2-completion-acceptance.md`. Deployment and physical acceptance remain separately gated; the controlled demo is not yet ready.

**Goal:** Complete the existing Tier 2 biometric flow and establish evidence-backed readiness for a fictional-data-only controlled school demonstration.

**Architecture:** Retain Firebase account authentication, the Android Keystore auth-per-use signing key, existing challenge/read callables, and explicit account-password fallback. Make small corrections to existing error handling and sensitive-view invalidation. QR scanning grants only public Tier 1 access; it never authenticates the QR owner's Firebase account.

**Tech stack:** Existing Flutter/Dart, Android Kotlin BiometricPrompt, Firebase Auth and callable Functions, Firestore transactions, and existing test tools. No dependency changes.

**Specs:** Owner's Final Tier 2 Completion and Acceptance directive (2026-11-15); `docs/superpowers/specs/2026-11-10-resqme-qr-tier2-security-design.md`; `docs/superpowers/specs/2026-11-10-resqme-school-verification-design.md`; G6 execution record, section 14 of `docs/resqme-g6-active-qr-and-tier2-deployment-manifest.md`. Later school-verification constraints supersede earlier school-only/minor eligibility snapshots. Preserve existing minor fail-closed behavior.

## Global constraints and approval boundaries

- Baseline: `main`, HEAD `cd5d9f2a412e3bcb6aa501a5729824ea6685dc73`, 109 existing Git status entries. Preserve all owner work; record incremental changes separately.
- This planning task creates this document only. Product changes require owner approval of this plan.
- Approved implementation method: native, sequential. No agents, branches, worktrees, commits, pushes, unrelated refactors, dependency installation, or emulator-infrastructure investigation.
- No deployment, IAM, Rules, App Check, billing, or artifact-cleanup change. Preserve the dedicated runtime identity and deny-all Rules.
- No real identities/medical information. No passwords, tokens, raw QR payloads, full UIDs, key proofs, or private records in retained evidence.
- No Firebase CLI/emulator startup is included. Offline tests are separate from HTTP, hosted, and device evidence.
- Before staging testing, explicitly approve the bounded read-only inventory scope; do not assume earlier authorizations cover a new session. Before hosted writes, obtain one separate bounded synthetic-resource creation/use/cleanup authorization.
- Use the existing debug build for initial acceptance. If a client correction requires a rebuilt APK, record package/signer/hash and request device-update authorization before installation. Never claim device acceptance for code absent from the installed build.
- No school-demo readiness until every required row has evidence and synthetic cleanup is verified. Controlled demo readiness never authorizes real-student rollout.

## Audit findings and evidence limits

1. G6 section 14 records 13 ACTIVE Node 22 staging Functions, the runtime update permission, successful active-QR scanning/rotation, password Tier 2 access/locking, device-key enrollment and challenge issuance on 2026-11-12. Biometric medical read was NOT VERIFIED. These are historical local records, not fresh cloud verification.
2. The same record states both disposable Auth accounts and all 15 named documents were removed. Do not assume reusable accounts remain or repeat provisioning without authorization. Its older PROPOSAL/OPEN headings conflict with the later execution record and need annotated reconciliation.
3. `Tier2AuthorizationRepository.readWithBiometrics()` and `enrollWithPassword()` catch all errors. Enrollment can reauthenticate and enroll successfully, then fail during signing while showing a password-error message. Native `onAuthenticationError` also collapses cancellation, lockout and availability into one code. Cause of misleading text is confirmed by source; physical outcomes are not freshly reproduced.
4. `Tier2AccessScreen` clears records on paused/hidden, logout/account change and disposal. `_run()` accepts late results based on mounted/current UID only; there is no operation generation check. A pause or A→B→A transition during an outstanding request may allow repopulation. Confirm with deterministic delayed-future tests before fixing.
5. Repository `_call()` snapshots the user at each call, rather than pinning the entire enrollment/challenge/sign/read operation to its starting account. Test account changes between awaits before deciding whether additional guards are needed.
6. Android creates auth-per-use P-256 signing keys, invalidated by biometric enrollment changes. The current cancellation signal is not retained for lifecycle cancellation, and terminal callbacks have no explicit once-only completion guard. Test/review these paths; do not treat a nonterminal bad-fingerprint attempt as successful or automatically switch to password.
7. Existing backend unit tests cover recent authentication, field allowlisting and signature owner binding. They do not establish full transactional challenge replay/expiry/device-replacement behavior. The backend biometric path currently requires recent auth (default 300 seconds), password fallback uses 120 seconds, and challenges expire after 60 seconds. Preserve those limits; surface reauthentication rather than extending them to make a demo pass.
8. Repeated `ensureMyTier1Qr` reuses an existing valid credential; explicit `replaceMyTier1Qr` creates a new lookup and revokes the previous one. Two replacements could explain two revoked rows, but the extra historical row's cause is unproven. Do not claim it was harmless or remove historical lookups as a fix.
9. Registration already starts with an unchecked privacy checkbox, disables acceptance until checked, and only registers after the dialog returns true. The remaining finding is evidence attribution, unless tests reveal a bypass.

## Approach and dependencies

Use small client/native corrections plus targeted regressions, then owner-assisted device acceptance against the existing server architecture. Acceptance-only execution first would leave confirmed misleading errors and the late-result risk unaddressed; a new authentication architecture would exceed the directive. This plan proposes neither.

Order: Task 1 → Task 2 → Task 3 → Task 4 → Task 5. Tasks 3/4 may end with a documented blocker instead of a code fix. Material backend/security-contract mismatches require an explicit amendment before production backend changes or redeployment.

## Review focus

- A biometric cancellation during enrollment must not masquerade as an incorrect password or release data (Task 1).
- A delayed success/error after pause, lock, logout, A→B→A, or disposal must not revive sensitive state (Task 2).
- Device changes, replayed/expired/wrong-owner/wrong-operation proofs and stale authentication must be denied server-side (Task 3).
- Rebuild/retry/navigation must not trigger unconfirmed QR replacement, and dialog dismissal must not register (Task 4).
- Native biometric prompts can produce transient lifecycle events; privacy must hold without making every valid fingerprint completion unusable (Tasks 2/5).

### Task 1 — Preserve biometric/password failure distinctions

**Product files (only if regressions justify edits):**
- `lib/features/medical/services/tier2_authorization_repository.dart`
- `lib/features/medical/services/platform_tier2_key.dart`
- `android/app/src/main/kotlin/com/example/resqme/MainActivity.kt`

**Tests:** Create `test/features/medical/tier2_authorization_repository_test.dart` and `test/features/medical/platform_tier2_key_test.dart` using existing Flutter test facilities and hand-written fakes. No mocking dependency.

**Interfaces:** Keep `readWithBiometrics()`, `enrollWithPassword(String)`, `readWithPassword(String)` and the `resqme/tier2_key` channel methods. Preserve public signatures and backend requests; use stable native failure codes and `Tier2AuthorizationFailure` for safe UI messages.

- [ ] Write failing regressions for native cancellation, unavailable/no-enrollment, lockout, invalidated/missing key, signing failure, incorrect password, server denial, stale auth, rate limiting and interrupted enrollment. Assert no protected record is returned and fallback requires an explicit password action.
- [ ] Run the two new Flutter test files; establish the expected failures before product edits.
- [ ] Map errors by operation stage; do not blanket-map server/network/signing errors to wrong password. Native callbacks must complete a method result at most once. A bad fingerprint may remain retryable within the OS prompt; terminal failure must remain locked.
- [ ] Re-run focused tests. Compile Kotlin using the existing toolchain without installing dependencies (`android/gradlew.bat :app:compileDebugKotlin`, from `android`). Record unavailable/offline build dependencies as BLOCKED.

**Acceptance:** Correct non-sensitive messages; no auto-unlock/fallback on cancel; preserved auth-per-use signing, enrollment invalidation and server authorization. Native callback/lifecycle behavior still requires Task 5 device proof.

### Task 2 — Prevent stale sensitive data and account-operation crossover

**Product files:** `lib/features/medical/screens/tier2_access_screen.dart`, `lib/features/medical/services/tier2_authorization_repository.dart`; `MainActivity.kt` only if lifecycle cancellation regression requires it. Inspect `lib/app/resqme_app.dart` and existing sign-out routing; change them only for a demonstrated affected-path defect.

**Tests:** Create `test/features/medical/tier2_access_screen_test.dart`; extend Task 1 repository/channel tests.

**Interfaces:** Keep `Tier2AccessScreen(repository: ...)`, repository methods and existing auth stream. Use a local operation generation/invalidation check rather than adding a session-management framework. Pin account identity across challenge/sign/enroll/read awaits.

- [ ] Add delayed-future widget tests: load→Lock; pending load→pause/hidden→resume; pending load→logout; A→B→A; navigate away/dispose; late success and late error after invalidation. Confirm stale record/messages/password are absent.
- [ ] Add repository tests for account changes after reauthentication, token refresh, device-ID retrieval, key generation, enrollment and signing. Old operations must not enroll a key into or read for the replacement account.
- [ ] Reproduce failing cases, then minimally invalidate pending completions and clear record/password/error state on security transitions. Prevent completion while backgrounded from populating the screen. Guard each sensitive operation against account changes.
- [ ] Preserve native prompt compatibility: do not treat every `inactive` transition as proof the app left the foreground. Verify pause/hidden and actual prompt transitions independently; invalidate/cancel when truly backgrounded. Require a fresh action after an invalidated operation.
- [ ] Run Task 1/2 tests and existing registration/account-gate tests. No arbitrary new timeout or weakened recent-auth window is introduced. If the approved design requires an additional display-session expiry, settle its exact duration before adding it.

**Acceptance:** Records cannot reappear from stale futures, survive a security lock, or cross accounts. Lock/background/logout/disposal clears sensitive state, including password text. UI behavior remains unchanged apart from correctness/messages.

### Task 3 — Pin backend authorization and identify unresolved contract gaps

**Inspect:** `functions/src/medical/{tier2_challenge,issue_tier2_challenge,read_my_tier2_record,read_my_tier2_with_password,enroll_tier2_device,revoke_my_tier2_device}.ts`, `functions/src/onboarding/authorization.ts`, and current school/medical eligibility contracts.

**Tests:** Extend `functions/test/tier2_authorization.test.ts`; create `functions/test/tier2_handler_authorization.test.ts` only where transaction/handler coverage is missing. Use local doubles for Firestore/Auth and real crypto operations; no emulator or hosted requests. If the installed architecture cannot safely inject those doubles, document the integration gap rather than introducing a production test seam without review.

**Interfaces:** Existing callable contracts, signed message `uid\ndeviceId\nread_medical\nchallengeId\nnonce`, 60-second single-use challenge, biometric recent-auth 300 seconds, password recent-auth 120 seconds, password read limit five per ten minutes. Medical response keys remain exactly conditions/allergies/primaryContact.

- [ ] Run existing `tier2_authorization` tests under Node 22 and add independent rejection cases for absent auth, wrong UID/device/operation/key/signature, expired/consumed challenges, replaced/revoked device, stale/future auth, unapproved/revoked/incomplete profiles, synthetic-only medical data, and private-field exclusion.
- [ ] Inspect transaction ordering and assert that replay or concurrent proof consumption cannot authorize a second read where local doubles can model it meaningfully. Label simulated transaction tests accurately; reserve real concurrency proof for separately authorized integration.
- [ ] Compare Tier 2 eligibility against current school assignment, medical revision and guardian requirements. Do not silently make the shorter Tier 2 predicate equivalent to QR eligibility or relax either one. Record any proven divergence and its exact impact; obtain a plan amendment before production backend correction.
- [ ] Run `npm.cmd --prefix functions test` with the verified Node 22 toolchain first on PATH and offline npm mode. Explicitly run any newly added compiled test not included in that command. TypeScript build must pass. Never equate `.run()`/mock tests with HTTP or deployed acceptance.

**Acceptance:** Existing backend gates remain intact and their covered rejection cases pass. Any important uncovered or contradictory gate remains an explicit demo blocker. No backend deployment/configuration change is authorized by this task.

### Task 4 — Resolve QR/registration findings and reconcile QA history

**Inspect/conditional minimal fixes:** `lib/features/qr/screens/my_unverified_qr_screen.dart`, `lib/features/qr/services/tier1_qr_repository.dart`, `functions/src/qr/{ensure_my_tier1_qr,replace_my_tier1_qr}.ts`, `lib/features/registration/{screens/create_student_account_screen,widgets/registration_privacy_dialog}.dart`.

**Tests:** Extend `test/features/qr/onboarding_test.dart`, `test/features/registration/create_student_account_screen_test.dart` and `functions/test/replace_tier1_qr.test.ts`. Reuse current fake clients. Do not edit the resolver to conceal a failed test.

- [ ] Add/verify separate tests: repeated ensure and rebuild/re-entry preserve the payload; cancel replacement produces no call; one confirmed replacement produces one client call; rapid repeated confirmation cannot launch duplicate client replacement; deliberate subsequent replacement remains explicit.
- [ ] Review available sanitized G6 evidence for lookup creation ordering. Retain UNKNOWN if it cannot attribute the extra historical row. Backend retries/replacement idempotency must be assessed separately from UI call counts; no fake transaction test establishes real concurrency safety.
- [ ] If a defect is reproduced, write a failing regression and apply the smallest client correction after review. Any necessary backend change requires the Task 3 amendment gate. Do not delete revoked rows or weaken revocation.
- [ ] Verify unchecked/decline/dismiss/back/privacy-review paths never register; explicit checked confirmation registers once with acknowledgment. Preserve notice wording/version pending privacy review.
- [ ] Update dated QA annotations in `docs/qa/resqme-school-verification-local-qa.md`, `docs/qa/resqme-school-verification-device-qa.md`, `docs/qa/resqme-test-contract-reconciliation.md`, and the G6 manifest. Preserve historical results; identify exactly which environment/date each result covers. Distinguish demonstrated rotation from terminal school revocation, which G6 section 14 does not independently prove.

**Acceptance:** New tests establish current repeat/replacement behavior; historical attribution is honest. Privacy acknowledgment remains mandatory. QA documents stop presenting superseded deployment blockers as current facts without fresh evidence.

### Task 5 — Consolidated verification and owner-assisted device acceptance

**New report:** `docs/qa/resqme-tier2-completion-acceptance.md`. Record implementation deltas, test counts, device build provenance, individual scenario evidence, cleanup and final readiness.

**Interfaces/environment:** Existing `resqme-943ee` staging only, expected number `519076598217`, dedicated runtime `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com`, existing 13-function G6 allowlist. No redeployment is assumed.

- [ ] After plan approval, run focused Flutter tests from Tasks 1/2/4, relevant registration/QR regressions, `flutter analyze`, Node 22 Functions tests/build and `git diff --check`. Run broader existing suites once when warranted by the auth/session changes; do not repeat passed checks without a new reason. Report tooling blockers instead of installing/upgrading dependencies.
- [ ] Review incremental security diffs against this plan. Owner prohibits extra agents: perform native review and disclose that independent review has NOT RUN unless separately authorized. Resolve important findings before device testing.
- [ ] With explicit bounded read-only staging authorization, verify project, all 13 Function names/state/runtime/service account against G6, Rules/App Check posture, and exact expected disposable-resource absence/presence. Metadata-only verification cannot prove deployed source matches the dirty worktree; compare recorded artifacts/revisions where evidence exists. Stop on security/identity/configuration mismatch.
- [ ] Present one concrete synthetic-session request: at most two disposable fictional adults (student plus reviewer/auth-only second account), one maximum-60-minute session, exact per-UID student/profile/acknowledgment/medical/approval/QR/lookup/device/challenge/rate-limit/receipt paths, Route A trusted assignment/reviewer writes, permitted challenge reads/rejections and exact cleanup. Do not invent guardian consent, use real data, overwrite preexisting records, or reuse old approval as authorization. Account-switching can also use the reviewer account; no third account is implied.
- [ ] After that authorization and build/device provenance checks, capture registration-dialog before/after states without retaining passwords or private form values. Use existing Route A approval and medical-completion flow, then check one active QR and explicit rotation while recording only sanitized counts/outcomes.
- [ ] Ask the owner to complete the actual fingerprint prompt. Verify a biometric-authorized allowlisted read, Lock, cancellation, retryable wrong fingerprint, interruption/background/resume, explicit correct/incorrect password fallback, logout and account switching. Never change OS fingerprint enrollment or intentionally induce lockout without separate permission. Test unavailable/no-enrollment/lockout via automated simulations; mark physical versions BLOCKED/NOT RUN if not safely exercised. Do not claim simulations as device evidence.
- [ ] Verify server rejection of expired/replayed/mismatched challenges with test-owned proofs only if included in the session approval. Device biometrics must never substitute for server authorization. Retain outcome labels, not signatures/challenges/medical values.
- [ ] Cleanup only verified run-owned resources, including lookup/challenge/receipt documents, then both exact Auth users. Verify every tracked path/user absent. Preserve uncertain resources for owner direction; no collection-wide hosted deletes, device data clearing, or automatic configuration rollback.
- [ ] Check final Git baseline plus scoped changes and source fingerprints, record all results and classify `CONTROLLED_DEMO_READY` only when every required criterion is evidenced. Otherwise use `CONTROLLED_DEMO_BLOCKED` with exact gaps. Real-school provisioning/guardian/privacy/security review remain outside this milestone.

## Acceptance matrix to populate (no new results claimed)

| Scenario | Current evidence | Required final evidence |
|---|---|---|
| Fingerprint medical read | NOT VERIFIED in G6 | Physical prompt succeeds; server authorizes; exact allowed fields |
| Cancellation/failure/unavailability/lockout/no enrollment | Not independently accepted | Independent automated rows plus device cancellation/failure; disclose simulated-only cases |
| Password fallback/incorrect password | Success historically recorded; other cases unverified | Explicit fallback, wrong-password denial, no automatic unlock |
| Lock/background/resume/logout/account switching/late result | Lock historically passed; other cases need proof | Independent widget regressions plus safe physical session checks |
| Challenge expiry/replay/owner/device/operation mismatch | Partial unit evidence | Focused handler regressions; integration limits explicit |
| QR repeat/replacement/extra revoked row | Rotation passed; extra row unexplained | Call counts and state invariants, historical cause or remaining uncertainty |
| Registration acknowledgment | Server record exists; tap attribution unclear | Unchecked/dismiss/decline tests and observed explicit confirmation |
| Staging metadata, build provenance, cleanup | Historical G6 evidence only | Authorized fresh verification and exact synthetic absence checks |

## Planning validation and next gate

This plan was checked against the owner's completion criteria and current call paths. No test/build/device/cloud operation was needed to claim planning completion; historical test counts are not fresh results. The next action is one owner approval of this five-task plan. That approval permits sequential local implementation/verification only; hosted writes, APK installation, backend deployment/configuration changes, and additional agents remain separately gated as stated above.
