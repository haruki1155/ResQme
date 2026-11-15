# ResQMe Tier 2 completion and acceptance — 2026-11-15

**Readiness: CONTROLLED_DEMO_BLOCKED.** Local client corrections are implemented. Three pending backend eligibility-contract regressions fail, one existing Flutter navigation assertion fails, and biometric/device acceptance has not been performed for these changes.

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
