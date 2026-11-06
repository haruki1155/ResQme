# Local synthetic staging onboarding acceptance — 2026-11-06

Local implementation is complete; hosted deployment and native-device acceptance are pending. No hosted accounts, emails, entitlement changes, medical writes or deployment were performed. All integration fixtures were fictional and confined to `demo-resqme` loopback services.

## Commits

| Task | Commit | Result |
| --- | --- | --- |
| 1 explicit backend/session safety | `a31531b` | Debug-only emulator/staging choice; no fallback; shared account-operation serialization |
| 2 private medical backend | `59dc83e` | QA entitlement, validation, revision/replay protection, canonical contacts, private Rules |
| 3 medical UI/reminder | `d1f1d6e` | Optional save/skip, exact notice, separate minor acknowledgment, safe QA-denial message |
| 4 unverified QR backend | `233e5be` | Auth + pending profile; one transactionally persistent opaque reference |
| 5 onboarding integration | `2dc1fe2` | Actual QR rendering, medical skip/save → QR → dashboard; account-scoped reminder and status refresh |
| 6 validation/handoff | This documentation commit | Local validation and separately gated deployment proposal |

## Verified final checks

| Command/check | Result | Exit |
| --- | --- | --- |
| `flutter test` | 61 passed | 0 |
| `flutter analyze` | No issues | 0 |
| `flutter build apk --debug --dart-define=RESQME_BACKEND=staging` | APK built | 0 |
| `npm.cmd --prefix functions test` | 12 passed, including build | 0 |
| `npm.cmd --prefix functions run build` | TypeScript compiled | 0 |
| `npm.cmd --prefix functions run test:integration` | 9 passed, 0 failed/skipped | 0 |
| `npm.cmd --prefix functions run test:rules` | 4 passed, 0 failed/skipped | 0 |
| `git diff --check` | Clean | 0 |

Final emulators: one controlled `demo-resqme` session, Auth `127.0.0.1:9099`, Firestore `127.0.0.1:8080`, Functions `127.0.0.1:5001`; readiness verified before tests. Test harness rejects mismatched project IDs and non-loopback/wrong-port endpoints. Unit/build ran before startup. Integration does not rebuild watched files. Rules denial messages are expected successful assertions, not failed tests.

Shutdown passed: only the identified session root PID 19292 and its descendants were stopped; ports 8080/9099/5001 were then confirmed free. Unrelated processes were preserved.

APK: `build/app/outputs/flutter-apk/app-debug.apk`, SHA256 `B101E6AD66137A063DE63325B05B50652C1A827759EDD22E657274679A479AC8`. This staging-selected artifact was built only, not installed or connected to hosted Firebase.

Evidence logs (local temporary files): `resqme-final-flutter-test.log`, `resqme-final-integration.log`, `resqme-final-rules.log`, `resqme-final-20261106090955.log` and its `-error.log` under `%TEMP%`. Logs contain diagnostics/fixture identifiers and are not committed.

## Security and review results

- Ages 17/18 stay `pending_guardian`/`pending_review`; contact listing and student acknowledgment never grant guardian authorization.
- Medical save requires trusted Admin-managed QA entitlement; default deny. Unknown is distinct from none-known. Skip writes nothing. Clear removes medical detail fields, preserves contacts and minimal revision/retry/acknowledgment metadata.
- Replays are idempotent; altered replays, stale revisions and stale canonical contacts cannot overwrite originals. Anonymous/non-QA writes and cross-user reads are denied.
- QR contains only a random opaque reference and remains unverified. Concurrent requests reuse one credential; no medical prerequisite, public scanner, school approval or Tier 2 permissions were added.
- Auth/profile partial-failure recovery and guest public emergency routes remain covered. Existing hotline/scanner placeholders remain visibly unavailable.
- One independent whole-change review found no substantiated authorization or overwrite defects. Two UI findings were fixed after failing regression tests: dashboard medical state reloads on route return; registration-status action reloads the trusted profile. Both tests and the full suite now pass. No deferred minor findings.

Ruling: QA entitlement uses Admin-managed `qaTesters/{uid}` documents instead of a runtime environment allowlist. Emulator parameter defaults overrode launcher environment; transactional document reads also make revocation conflict with an in-flight save. Cost if wrong: hosted deployment needs an explicit approved operator process for UID grants/revocation. No automatic entitlement exists.

## Remaining acceptance gates

- No Android devices were attached (`adb devices` empty). Native phone/tablet rendering, actual QR camera readability, lifecycle/session timing and Flutter-to-emulator/device acceptance remain pending; widget tests are not device proof.
- Hosted Email/Password, App Check, deployed registration version, billing and Rules compatibility are unverified. See [exact deployment manifest](resqme-staging-deployment-manifest.md). No hosted smoke was run.
- Local Node 24.18.0 tests pass; configured Node 22 deployment-runtime parity is pending. Current APK build passes with plugin Kotlin migration warnings; no unrelated dependency migration was performed.
- Existing registration metadata omissions (`emailNormalized`, `ageCategoryAtRegistration`, extra acknowledgment metadata) were not expanded without demonstrated need; medical contact changes now set profile `updatedAt`. Registration backend implementation remains unchanged.
- Real-data privacy/retention clearance, verified school/guardian approval and full QR lifecycle/scanner/printing/replacement policies require separate design approval.

The existing checkout and commits were preserved. Untracked owner specifications/plans/prompts and `docs/mockups/` were not staged. No push, merge, remote configuration change or deployment occurred.
