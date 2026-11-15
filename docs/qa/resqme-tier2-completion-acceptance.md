# ResQMe Tier 2 completion and acceptance — 2026-11-15

**Latest readiness: CONTROLLED_DEMO_BLOCKED.** The three backend eligibility regressions and Flutter navigation assertion were corrected locally in the resumed execution below. The earlier failure results in this dated report are preserved as historical evidence. Deployment and physical-device acceptance for the corrections remain outstanding.

## Scope and implementation

Owner approved the five-task plan for native local execution. No agents or new worktrees were used. No hosted read/write, Firebase CLI invocation, emulator startup, APK installation, deployment, IAM/Rules/App Check/dependency change, device action, commit, or push occurred. No credential files were inspected or modified.

| Task | Actual outcome |
|---|---|
| 1 — Error handling | Local corrections complete; physical native callback acceptance pending |
| 2 — Sensitive session state | Local corrections and deterministic widget/repository regressions pass |
| 3 — Backend authorization | Existing covered gates pass; three additional eligibility requirements fail and require a separate backend amendment |
| 4 — QR/registration QA | New client-call/confirmation regressions pass; historical extra-lookup attribution remains unknown; privacy tap needs new physical evidence |
| 5 — Consolidation/device acceptance | Automated results below; no physical/staging acceptance performed; no readiness approval |

### Product changes

- `lib/features/medical/services/tier2_authorization_repository.dart`: stage-appropriate messages preserve cancellation, lockout, key/signature failure, password failure, stale authentication, server denial and rate limiting. Raw exception messages are not displayed. Each multi-await operation watches its starting account and checks identity before/after sensitive awaits. An observed A→B→A transition remains invalidated. Subscriptions are cancelled after each operation. Explicit password fallback remains a separate operation; no second password system or automatic fallback was introduced.
- `lib/features/medical/screens/tier2_access_screen.dart`: generation checks invalidate late records and errors after background/hidden transitions, account changes, Lock and disposal. Security transitions clear records, messages and password text. The app cannot start a protected action while backgrounded. `inactive` alone is not treated as backgrounding, so an OS biometric prompt can complete normally; actual device transitions still require acceptance.
- `android/app/src/main/kotlin/com/example/resqme/MainActivity.kt`: distinguish cancellation and lockout from other unavailability, complete the method result at most once, retain the cancellation signal and cancel it on activity stop/destruction. Nonterminal failed fingerprint attempts stay within the OS prompt. Auth-per-use key requirements and biometric-enrollment invalidation remain unchanged.

Tests added: `test/features/medical/{tier2_test_fakes,tier2_authorization_repository_test,tier2_access_screen_test,platform_tier2_key_test}.dart`; `functions/test/tier2_handler_authorization.test.ts`; `functions/test/tier2_eligibility_contract.diagnostic.ts`. Existing QR onboarding and registration-screen tests were extended; no test was removed. No backend production file was edited.

## Fresh verification

| Check | Result | Evidence/limit |
|---|---|---|
| Focused Flutter medical/channel/session + QR/registration/account-gate tests | PASS: 63, zero failed | Final focused run after fixes; hand-written fakes and synthetic strings only |
| Full Flutter suite | FAIL: 153 passed, 1 failed | Untouched `test/app/scanner_entry_flow_test.dart:231`, described below |
| Flutter analysis | PASS | `flutter analyze --no-pub`: no issues |
| Android Kotlin compilation | PASS | `gradlew.bat :app:compileDebugKotlin --offline`: BUILD SUCCESSFUL; no APK installed |
| Configured Functions build/unit command | PASS: 90, zero failed | `npm.cmd test` with Node 22.23.4 and npm offline; includes TypeScript build |
| New Tier 2 handler regressions | PASS: 14, zero failed | Explicit Node 22 test invocation; mocked database boundary, real signatures; NOT HTTP/emulator evidence |
| Pending eligibility diagnostic regressions | FAIL: 0 passed, 3 failed | Explicit separate invocation; assertions retained, not weakened or silently skipped |
| HTTP/emulator/staging/device tests | NOT RUN | No fresh hosted deployment/security verification or fingerprint acceptance |

The configured npm command explicitly lists its existing tests; it does not automatically discover either newly added test file. The new handler file and pending diagnostic were invoked explicitly. A green 90-test result therefore does NOT clear the three known security-contract failures.

Test-first evidence: the initial repository error suite had 9 failures/2 passes; the misleading-error fixes made all 11 pass. Account-transition regressions then failed before the operation guards; screen regressions demonstrated stale records/errors before generation invalidation. Test-harness lifecycle transitions were corrected to Flutter's valid inactive/hidden/paused sequence; scroll targeting was corrected for the lazily built Lock button. These harness corrections did not weaken privacy assertions. An initial Kotlin build caught an unsupported constant reference; it was removed and the final offline compilation passed.

## Blocking backend finding — separate amendment required

`functions/src/medical/tier2_challenge.ts:requireTier2Eligible(profile, medical)` only requires profile schema version 1, school approval, completed profile/medical status, self-reporting, and non-synthetic medical data. Unlike current school/QR eligibility, it does not check trusted school assignment, profile/medical revision equality, or independent guardian authorization for minors.

Three explicit offline desired-contract regressions call this guard and expect `permission-denied`; all fail with **Missing expected exception**:

1. Approved/complete profile with `schoolAssignmentStatus: unassigned`.
2. Approved/complete profile whose `medicalRevision` does not match the medical document revision.
3. Approved/complete minor without independently verified guardian authorization.

This confirms a local guard gap. It is not evidence that an arbitrary client can write those server-owned fields, a hosted exploit, or a fresh reproduction against deployed code. Device proofs and recent-auth checks still apply. School/QR fail-closed eligibility alone does not establish equivalent protection for a directly invoked Tier 2 callable.

The 14 passing handler tests separately establish mocked-unit rejection of expired/consumed/wrong-owner/wrong-device/wrong-operation challenges, revoked devices, replaced keys, invalid signatures, unapproved/revoked school status, incomplete/synthetic medical data and stale auth. A successful unit proof returns only the medical allowlist and a second use is rejected. The fake transaction does not establish real concurrent Firestore behavior.

**Proposed minimum amendment, not implemented:** extend the existing shared Tier 2 eligibility guard with the approved trusted-school, valid-age/medical-revision and independently verified guardian requirements, supplying authenticated UID and guardian data at each enrollment/challenge/medical-read caller. Expected affected production paths are `tier2_challenge.ts`, `enroll_tier2_device.ts`, `issue_tier2_challenge.ts`, `read_my_tier2_record.ts`, and `read_my_tier2_with_password.ts`. Keep challenge consumption/eligibility checks transactionally safe; do not require eligibility merely to revoke one's device. Preserve response allowlists, password fallback limits and challenge bounds. Add regressions before changes, retain missing/invalid/legacy-state denial, and request a separately reviewed deployment if hosted code must change. No additional IAM or API change is inferred.

## Existing Flutter failure

The untouched scanner-entry composite test `pending sign-in requires medical and school approval before QR` expects `Medical information` and a missing QR immediately after sign-in. Its first assertion fails. Current school-verification design allows inert pending QR issuance before medical completion, and the independent pending-QR widget tests pass. This is consistent with an older navigation/test contract, but this session did not amend that test or change application routing to make it green. A focused reconciliation should preserve the requirement that medical/school completion gates activation. The failed composite's later assertions were not executed.

## QR and privacy findings

- New widget regressions confirm the observed client behavior: rapid UI replacement taps show one visible confirmation; cancelling sends no replacement call; one confirmed replacement sends one call; rebuilding the screen does not issue replacement. These fakes establish client call counts only, not backend idempotency, persisted index counts or concurrency.
- Existing backend source reuses the credential during ensure and creates a new index/revokes the prior index during explicit replacement. The historical extra revoked row cannot be attributed from the available sanitized evidence. Its cause remains UNKNOWN. No QR production behavior or historical row was modified.
- Registration tests now independently cover valid-form acceptance, decline and outside-dialog dismissal. Opening the notice or leaving its checkbox unchecked does not authorize registration. The physical before/after attribution requested by G6 remains NOT RUN. Notice version/legal review is unchanged.

## Physical-device acceptance matrix

| Scenario | Current status |
|---|---|
| Fingerprint-authorized medical read | BLOCKED — not exercised; requires owner-assisted session after backend resolution |
| Biometric cancel/lockout/unavailable/missing key/sign failure | Automated channel/repository checks PASS; physical checks NOT RUN |
| Explicit password fallback/incorrect password | G6 success is historical; local error regressions PASS; fresh physical check NOT RUN |
| Lock/background/resume/logout/account switch/late completion | Local widget/repository checks PASS; physical check for updated client NOT RUN |
| Expired/replayed/mismatched proof | Mocked handler checks PASS; fresh hosted/device acceptance NOT RUN |
| Registration privacy confirmation attribution | Automated checks PASS; new physical evidence NOT RUN |
| QR extra lookup explanation | UNKNOWN; current client tests do not prove historical causality |
| Current 13 Functions/runtime/Rules/App Check | G6 historical record only; not freshly queried |
| Synthetic resource cleanup | No new Firebase users or records created; no deletion needed in this session |

## Historical evidence and remaining gates

The 2026-11-10 emulator result (12/14 integration PASS, 4/4 Rules PASS) and later observer/listener work remain historical, environment-specific evidence. G6 section 14 independently reports successful staging active-QR/password-access/rotation checks on 2026-11-12, but it does not prove physical biometric medical read or terminal school revocation. No older emulator startup was repeated and no historical failure was erased.

Next: authorize the narrow backend eligibility amendment and targeted scanner-test reconciliation, complete the pending local regressions, then seek the one bounded synthetic staging session and any required APK update approval. Verify actual Function metadata and the installed build before relying on the recorded G6 state. Use fictional adult data, owner-assisted fingerprint confirmation, privacy-safe evidence and exact resource cleanup. No real-school rollout is implied; trusted provisioning, minors' guardian workflow and privacy/security review remain separate gates.

## Preservation and review

Start: `main`, HEAD `cd5d9f2a412e3bcb6aa501a5729824ea6685dc73`, 110 Git entries including the approved plan. All original status entries are retained. All 23 backend production-source fingerprints match the pre-edit baseline. Incremental product edits are limited to the three client/native files above; test/document edits are scoped to this plan. Native incremental review was performed; independent agent review was NOT RUN under the owner's no-agent instruction. Protected-state/native prompt behavior still needs actual device acceptance; no overall correctness or school-demo readiness is claimed.

## Resumed execution — reconciled baseline `7ea3b1f`

The owner confirmed that the concurrent commits were intentional and authorized. The read-only audit found a clean `main` at `7ea3b1f0813893a64f26f1c4df8a7f6818310979`; no reset/revert or recovery operation was necessary. The previous 110-entry dirty baseline was committed into the intervening history, including the local biometric/session corrections and tests. Relative to `782afb4`, the new HEAD adds QA documentation plus the handler assertion that reads the actual post-operation challenge row. The older preservation statement above describes its original checkpoint only; it is not the current Git baseline. No existing commits were changed in this resumed task.

Fresh baseline reruns reproduced exactly three backend eligibility failures (17 other backend checks passed) and passed all 38 focused biometric/channel/session tests. Inspection confirmed the missing checks were in the server eligibility guard, not in biometric key signing or the Flutter error corrections. The scanner-entry failure was independently reproduced before changing its test.

### Corrections

1. Extracted the existing trusted student eligibility policy in `functions/src/qr/qr_eligibility.ts` as `evaluateStudentEligibility`. QR eligibility still adds its separate canonical credential and lookup-status checks. Tier 2 now uses the same assigned-school, approved enrollment, valid age/schema, completed and matching medical revision, medical-form validity and independently verified guardian policy. A QR remains public Tier 1 access only; it is not authentication or a new prerequisite for an owner-authenticated Tier 2 read.
2. `requireTier2Eligible` now needs an authenticated-owner context and trusted guardian data; absent context fails closed. Minor guardian records must match the student, name a different nonempty guardian identity, use the independent-verification method and contain a valid date. Invalid dates fail closed; adults do not require guardian authorization.
3. Updated device enrollment, challenge issuance, biometric read and password read to load only the authenticated owner's profile/medical/guardian records. Eligibility reads are in the Firestore transaction governing enrollment/challenge creation or protected read. Biometric proof consumption remains in that transaction. Device revocation remains available without eligibility, preserving the owner's ability to disable a device.
4. Kept recent-auth limits (300 seconds biometric/enrollment/challenge; 120 seconds password), single-use 60-second challenges, signature binding, response allowlists and five-per-ten-minute password read limits. Missing authentication now receives the normal unauthenticated guard before any database initialization on biometric read.
5. Corrected only the obsolete scanner-entry test: sign-in displays an inert Pending Verification QR and an explicit Complete Medical Information action. The test verifies no active label or medical record, and that the explicit action opens the existing medical form. No Flutter navigation/product code was changed in this resumed task.
6. Added authoritative-record coverage across all four Tier 2 entry points, positive adult/verified-minor fixtures, invalid/missing guardian/assignment/revision cases and unchanged password rate/fresh-auth checks. The existing diagnostic filename is preserved, but both that security suite and handler suite are now included in the normal `npm test` command. No assertion was removed to obtain a passing run; valid fixtures now include all required authoritative metadata.

### Fresh final automated results

| Check | Result | Boundary |
|---|---|---|
| Functions configured build and unit/security suite | PASS — 150 tests, zero failures/skips | Node 22.23.4, npm offline; includes former diagnostics and all handler regressions |
| Flutter full suite | PASS — 154 tests, zero failures | `flutter test --no-pub`; includes biometric/session regressions and corrected navigation contract |
| Flutter analysis | PASS — no issues | `flutter analyze --no-pub` |
| Patch whitespace | PASS | `git diff --check`; existing Git LF/CRLF warnings are not failures |
| Emulator/hosted/deployed behavior | NOT RUN | No Firebase CLI invocation, emulator, hosted read/write or deployment |
| Physical fingerprint and updated-build acceptance | NOT RUN | Checklist prepared; no APK install/device state change |

Handler database transactions are local doubles and proofs use local crypto. They establish branch/authorization behavior, not real Firestore contention, emulator HTTP metadata, deployed source identity or physical biometric behavior. No guardian provisioning workflow was implemented and no hosted guardian record was created.

### Remaining gates and next action

**CONTROLLED_DEMO_BLOCKED**, despite passing automated tests. The corrected backend is local only. Prepare/review the updated artifact and exact affected Functions, then obtain separate deployment authorization before testing these fixes on staging. Fresh staging metadata and build provenance need explicit bounded authorization; fictional account provisioning/use/cleanup and any APK installation are separately gated. Follow [the physical-device checklist](resqme-tier2-physical-device-checklist.md) after those prerequisites. Historical extra revoked-QR attribution and the physical privacy-confirmation evidence remain unresolved. Real-student rollout remains outside scope.

Preservation: HEAD remains `7ea3b1f` on `main`; changes are uncommitted, scoped backend/test/script/document deltas. The existing committed biometric/client/native implementation is preserved. No commits, pushes, new worktrees, dependency changes, MindMate access, credential inspection, hosted configuration or device operations occurred. Independent agent review was not performed under the native/no-agent instruction.
