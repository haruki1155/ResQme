# Scanner Entry Navigation Implementation Plan

> Execute sequentially with superpowers:executing-plans, test-driven development and verification-before-completion. Owner approved the companion design and requested the flow correction.

Goal: implement the supplied Splash/Terms/Scanner Entry branching flow using existing services.
Architecture: existing named routes plus one entry screen; explicit registration intent in StudentAccessGate; existing PilotAccountScreen and My QR reused. No backend change.
Spec: docs/superpowers/specs/2026-11-08-resqme-scanner-entry-navigation-design.md

Constraints: preserve unrelated dependency changes, public access, pending statuses, QA restrictions and local-only scanner. No deployment or hosted access.
Review focus: signup auth events must not lose medical intent; returning users without QR go straight to QR; logout failure stays restricted; scanner destination must be dashboard; camera route must remain escapable.

- [x] Task 1 RED/GREEN: test startup consent routing and four entry actions in test/app/scanner_entry_flow_test.dart; add ScannerEntryScreen, entry/register routes, and change Splash/Terms destinations. Adapt existing startup/public route tests to explicitly enter the guest dashboard. No camera auto-start at entry.
- [x] Task 2 RED/GREEN: test registration success through optional Save/Skip versus sign-in/Profile direct QR; update StudentAccessGate, StudentSignInScreen, PilotAccountScreen and MyUnverifiedQrScreen. Pass registration-completed intent explicitly, retain recovery, show Scan another QR/Logout without private management controls. Test successful logout to entry and failure feedback. Remove the dashboard private medical reminder surface from app wiring while preserving its existing isolated implementation/tests.
- [x] Task 3 RED/GREEN: test offline scanner result/error dashboard actions; add explicit scanner dashboard callback for app route while retaining standalone back behavior. Add small-screen entry test.
- [x] Task 4: run focused/full Flutter tests, analyzer, debug APK and diff check; final independent read-only review; commit only flow files, tests and these docs. Device camera and hosted acceptance remain not run.

Commands: flutter test --no-pub test/app/scanner_entry_flow_test.dart; flutter test --no-pub; flutter analyze --no-pub; flutter build apk --debug --no-pub; git diff --check. Expected exit0; capture failures before fixes. No source security assertions inferred from widget tests.

## Execution evidence

- Initial new route suite: 7 failed as expected before implementation (missing Scanner Entry).
- Final full Flutter suite: 85 passed, exit 0. Includes consent persistence, four entry actions, guest public routes, registration Auth events, synthetic Save/Skip, direct sign-in/Profile QR, recovery, sign-out success/failure, scanning without account mutation and narrow/large text.
- `flutter analyze --no-pub`: no issues, exit 0.
- `git diff --check`: exit 0.
- Independent final read-only review: no important issues found.
- Existing status-details navigation test was replaced by the approved private-data-free Profile flow assertions. Public resource tests now explicitly choose Continue as Guest.
- Smallest supporting fix: scroll account-unavailable fallback so large text does not overflow.
- Registration intent is retained through intermediate Auth changes and consumed after medical Save/Skip; subsequent account refresh/sign-in does not repeat onboarding.
- Backend contracts, Firebase configuration, security artifacts and unrelated launcher/plugin changes remain untouched. Backend/emulator suites were not rerun for this navigation-only change.
- Native camera/dialer/device acceptance and hosted onboarding were not run or authorized. No backend availability claim follows from UI tests or APK compilation.
- Final flutter build apk --debug --no-pub: exit 0; APK at build/app/outputs/flutter-apk/app-debug.apk. Build retains existing Flutter/Kotlin plugin migration warnings.
