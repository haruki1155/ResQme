# ResQMe Tier 1 QR Camera Scanner MVP Implementation Plan

> **For engineer:** Implement the camera-scanning MVP step-by-step using TDD where practical. Preserve existing uncommitted UI edits and untracked files. Stop if design changes or hosted Firebase access are needed.

**Goal:** Enable offline camera QR scanning from the Emergency Dashboard with bundled ML Kit, strict syntactic format parsing, and safe unverified presentation.

**Architecture:** Add `mobile_scanner: ^7.5.0` (bundled ML Kit); create pure Dart parser `QrPayloadParser` with 32-byte canonical verification; implement `QrScannerScreen` with `WidgetsBindingObserver` lifecycle handling, permission fallback, and debouncing; present `UnverifiedQrModal` with zero PII; replace placeholder at `AppRoutes.scanner`.

**Spec:** `docs/superpowers/specs/2026-11-08-resqme-tier1-qr-camera-scanner-mvp-design.md`

---

## Task 1: Dependencies and Android Permissions

- [ ] Add `mobile_scanner: ^7.5.0` to `resqme/pubspec.yaml` without bumping unrelated packages.
- [ ] Ensure bundled ML Kit operation (do not set `dev.steenbakker.mobile_scanner.useUnbundled`).
- [ ] Add `<uses-permission android:name="android.permission.CAMERA" />` and `<uses-feature android:name="android.hardware.camera" android:required="false" />` to `resqme/android/app/src/main/AndroidManifest.xml`.
- [ ] Run `flutter pub get` and verify resolution with exit code 0.

---

## Task 2: QR Payload Parser (TDD)

- [ ] Create `test/features/qr/qr_payload_parser_test.dart` with RED tests:
  - Valid: `resqme:v1:012345678901234567890123456789012345678901A` (valid 32 bytes canonical base64url).
  - Non-canonical 43rd character padding bits rejected.
  - Length != 43 rejected.
  - Characters outside `[A-Za-z0-9_-]` rejected.
  - Invalid prefix: `resqme:v2:...`, `custom:v1:...`.
  - Web URLs, telephone links, plain text, empty string rejected.
  - Asserts `InvalidQr` contains only a safe `reason`, no `rawSnippet`.
- [ ] Implement GREEN in `lib/features/qr/domain/qr_payload_parser.dart`:
  - `QrPayloadParser.parse(String? raw)` returning `QrScanResult` (`ValidResQMeQr` or `InvalidQr`).
  - Strict 32-byte decode and re-encode canonical equality check.
  - Zero raw token exposure in models or logs.
- [ ] Run `flutter test test/features/qr/qr_payload_parser_test.dart`; verify PASS.

---

## Task 3: Unverified Scan Result Modal

- [ ] Create `lib/features/qr/presentation/unverified_qr_modal.dart`:
  - Support `ValidResQMeQr` presentation:
    - Title: `"RESQME QR FORMAT RECOGNIZED"`
    - Badge: `"UNVERIFIED — TEST PILOT ONLY"` (Red `Color(0xFFE92B32)`)
    - Body: `"This QR code matches the ResQMe format, but its identity and status have not been verified."`
    - Safety text: `"No personal identification, medical records, or Tier 2 emergency data are accessible offline."`
    - Action buttons: `"Scan Again"`, `"Back to Dashboard"`.
  - Support `InvalidQr` presentation:
    - Title: `"UNRECOGNIZED QR CODE"`
    - Status: `"Invalid format"`
    - Subtitle: `"This QR code does not match the ResQMe format."`
    - Action buttons: `"Scan Again"`, `"Back to Dashboard"`.
  - Zero raw payload or student data displayed.
- [ ] Create `test/features/qr/unverified_qr_modal_test.dart`.
- [ ] Run test; verify PASS.

---

## Task 4: Camera Scanner Screen & Lifecycle Observer

- [ ] Create `lib/features/qr/presentation/qr_scanner_screen.dart`:
  - `MobileScannerController` configuration (`DetectionSpeed.noDuplicates`, `autoStart: true`).
  - `WidgetsBindingObserver` pausing camera on background (`paused`/`inactive`) and resuming on foreground (`resumed`).
  - Scanning lock (`_isProcessing`) pausing camera while modal is open and resuming cleanly upon "Scan Again".
  - Permission-denied fallback view with helpful explanation and return to dashboard.
  - Camera-unavailable error fallback.
  - Viewfinder cutout and red corner styling.
  - Torch toggle button.
  - Resource disposal on unmount.
- [ ] Create `test/features/qr/qr_scanner_screen_test.dart` testing permission fallback, error fallback, and back navigation.
- [ ] Run test; verify PASS.

---

## Task 5: App Routing Integration

- [ ] In `lib/app/resqme_app.dart`, update `AppRoutes.scanner`:
  - Replace `Tier1PendingScreen` placeholder with `QrScannerScreen()`.
- [ ] Verify Dashboard bottom bar "Scan QR" button navigates to `QrScannerScreen`.
- [ ] Verify Guest user access without login.
- [ ] Verify return navigation to Dashboard.

---

## Task 6: Full Verification & Build Validation

- [ ] Run `flutter analyze` and resolve any lints.
- [ ] Run `flutter test` and record test results (differentiating new tests from the 3 existing UI deltas).
- [ ] Run `flutter build apk --debug` and verify successful compilation.
- [ ] Run `git diff --check`.
- [ ] Commit scanner MVP changes: `feat(qr): add local unverified camera scanner mvp`.
