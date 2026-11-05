# Registration milestone results — 2026-11-06

Implemented Task 2.5 and Tasks 3–6 in the existing checkout on `main`. Native device acceptance remains pending; this is a synthetic-data development milestone, not approval for release or real enrollment.

## Corrective work and commits

| Task | Commit | Result |
|---|---|---|
| 2.5 | `9781da3` | Added missing draft/profile models; normalized and persisted all approved optional fields; compared complete normalized contact data on retries |
| 3 | `0831bfb`, `f4127bd` | Injectable Firebase repository, typed restricted states, consent guard, safe Auth/profile retry, safe errors; separate analyzer cleanup commit |
| 4 | `d612be2` | Responsive form, approved privacy disclosure/version, unchecked acknowledgment, independent guardian explanation |
| 5 | `76e05b1` | Sign-in, non-disclosing reset, pending status and collapsed private submission details |
| 6 | Commit titled `feat(resqme): gate pending student accounts and preserve public access` | Existing public-route integration, fail-closed gate, demo-only bootstrap, Android loopback policy and regression tests |

Root causes: Task 1 originally committed validators without the planned models. Task 2's validation/persistence whitelist omitted optional inputs, and retry comparison covered only name/age. Task 6 review found a completion callback using a disposed sign-in context after an Auth event; a controlled regression test reproduced it, and capturing the navigator before opening the form fixed it. FlutterFire's default Android host mapping would remap loopback; explicit mapping disablement and documented `adb reverse` preserve local routing.

## Final validation

| Command | Result | Exit code |
|---|---|---|
| `flutter test --reporter expanded` | 46 passed, 0 failed | 0 |
| `flutter analyze` | No issues | 0 |
| `flutter build apk --debug` | `build/app/outputs/flutter-apk/app-debug.apk` built | 0 |
| `npm.cmd --prefix functions test` | 9 passed | 0 |
| `npm.cmd --prefix functions run test:integration` | 4 passed | 0 |
| `npm.cmd --prefix functions run test:rules` | 2 passed | 0 |
| `npm.cmd --prefix functions run build` | TypeScript compiled | 0 |
| `git diff --check` | Passed | 0 |

Backend tests used `demo-resqme` and loopback Auth 9099 / Firestore 8080 / Functions 5001. Synthetic fixtures were used; the owned emulator process tree was stopped and those listeners were absent afterward. No deployment, push, real-data import, school/guardian verification or QR implementation occurred. The Firebase CLI did fetch public update/MOTD metadata at startup; it did not access project student data. The runbook now sets `CI=true` to suppress that public lookup on future starts.

The independent review's navigation finding has a failing-then-passing regression test. Deferred minor: registration is serialized, while other session mutations are not serialized with it; add a focused session-binding race test before real-data rollout. Native Android HTTP connectivity and visual behavior were not inferred from APK compilation.

## Changed files

- Backend: `functions/src/registration/registration_contract.ts`, `functions/src/registration/create_student_registration.ts`, `functions/test/create_student_registration.test.ts`, `functions/test/registration_integration.test.ts`.
- Models/validation: `lib/features/registration/models/registration_draft.dart`, `lib/features/registration/models/student_registration_profile.dart`, `lib/features/registration/registration_validators.dart`.
- Client services: `lib/features/registration/services/student_registration_repository.dart`, `lib/features/registration/services/firebase_student_registration_repository.dart`.
- UI: `lib/features/registration/screens/create_student_account_screen.dart`, `lib/features/registration/screens/student_sign_in_screen.dart`, `lib/features/registration/screens/registration_pending_screen.dart`, `lib/features/registration/widgets/registration_privacy_dialog.dart`, `lib/features/registration/widgets/student_access_gate.dart`.
- Integration: `lib/main.dart`, `lib/app/resqme_app.dart`, `lib/core/config/firebase_environment.dart`, `android/app/src/debug/AndroidManifest.xml`, `android/app/src/debug/res/xml/local_emulator_network_security.xml`.
- Dart tests: `test/features/registration/registration_models_test.dart`, `firebase_student_registration_repository_test.dart`, `create_student_account_screen_test.dart`, `student_sign_in_screen_test.dart`, `registration_pending_screen_test.dart`, `student_access_gate_test.dart` in that same test directory; `test/app/public_navigation_test.dart`, `test/core/config/firebase_environment_test.dart`.
- Documentation: `docs/registration-local-testing.md`, this result record. User-supplied specs and `docs/mockups/` remain untracked and untouched.

## Remaining gates and owner decisions

- No Android phone/tablet or emulator was attached (`adb devices` empty). Native UI, Flutter-to-emulator account creation/recovery, keyboard and screenshots remain pending. Widget width tests are not device acceptance.
- Local Node 24.18.0 passed; configured deployment runtime remains Node 22. Node 22 parity is a separate release check.
- School privacy/retention and guardian-authorization requirements remain unapproved for real data. The supplied processing disclosure is shown in full; no separate school-approved legal notice was invented.
- Proposed backend `emailNormalized`, `ageCategoryAtRegistration`, `updatedAt` and extra acknowledgment metadata were reported and left unchanged outside the bounded Task 2.5 correction. Existing acknowledgments retain the versioned document ID, actor UID, affirmative action and server timestamp.
- Hotline content remains the existing unavailable destination, as previously deferred. Public first aid, DRRM and the Tier 2 restricted boundary remain reachable.
- All registration outcomes remain pending; no student approval, QR issuance or Tier 2 read was added.

Before QR Phase Q0 implementation, approve a separate design covering trusted approval authority and guardian evidence; opaque token format and exact public fields; expiry/rotation/printed-copy behavior; lost-ID locking, recovery and replacement invalidation; tenant-scoped staff roles, step-up and audit retention; print/save/share permissions; and offline/camera/invalid/locked/revoked scanner states. No QR development is authorized by this milestone.
