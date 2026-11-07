# ResQMe Tier 1 QR Camera Scanner MVP Design

Status: **Revised for final owner approval on 2026-11-08**  
Author: Senior Flutter Engineer  
Scope: Local offline camera-scanning MVP for ResQMe Tier 1.  

---

## 1. Goal and Core Invariants

Implement a functional, local-only camera QR scanner wired to the "Scan QR" button on the ResQMe Emergency Dashboard (`AppRoutes.scanner`).

### Core Invariants
1. **Public & Guest Accessibility:** The scanner must remain accessible to guests and unauthenticated users without logging in, matching public emergency resource availability.
2. **Offline-Only Operation:**
   - Bundled ML Kit barcode detection (`com.google.mlkit:barcode-scanning`). No dynamic cloud model download on first use.
   - Purely local syntactic format checking. No network calls, no Firestore reads, no Cloud Functions invocations, and no remote verification endpoints.
3. **Explicitly UNVERIFIED Presentation:**
   - Display title: `"RESQME QR FORMAT RECOGNIZED"`
   - Status badge: `"UNVERIFIED — TEST PILOT ONLY"`
   - Explanation: `"This QR code matches the ResQMe format, but its identity and status have not been verified."`
   - **Zero PII:** Never display student names, medical conditions, allergies, emergency contacts, or Tier 2 emergency records.
   - **No Raw Token Exposure:** Raw QR payloads, base64 tokens, or substrings are never displayed in the UI, printed in error dialogs, or emitted to logs.
   - **No Verification Claim:** Never label a QR code as verified.
4. **Preservation:** Preserve existing uncommitted UI edits (`lib/app/resqme_app.dart`, `emergency_dashboard_screen.dart`, `account_dashboard_panel.dart`, `student_access_gate.dart`), G1 containment artifacts, and untracked docs.

---

## 2. Dependencies & Android Configuration

### Package Selection
- Add `mobile_scanner: ^7.5.0` to `resqme/pubspec.yaml`.
  - Non-retracted modern release (retracted `6.0.4` avoided).
  - Compatible with Flutter `3.44.4`, Dart `3.12.2`, and Android SDK `36.1.0`.
  - Zero transitive constraint conflicts with existing dependencies.
  - Avoids unrelated package upgrades.
  - Built-in permission handling; no third-party permission plugins needed.

### Bundled ML Kit Offline Guarantee
- Uses default bundled Google ML Kit dependencies.
- `dev.steenbakker.mobile_scanner.useUnbundled` remains unset (defaults to false), ensuring barcode models are packaged directly within the APK and functional without internet connectivity on first launch.

### Android Manifest
In `resqme/android/app/src/main/AndroidManifest.xml`:
- Add camera permission:
  ```xml
  <uses-permission android:name="android.permission.CAMERA" />
  <uses-feature android:name="android.hardware.camera" android:required="false" />
  ```
- `android:required="false"` ensures devices without autofocus or hardware camera restrictions can still run the emergency application.

---

## 3. Architecture & Components

```
lib/features/qr/
├── domain/
│   └── qr_payload_parser.dart        # Pure Dart: strict regex, 32-byte decode & canonical check
└── presentation/
    ├── qr_scanner_screen.dart        # Camera preview, lifecycle observer, permission fallback
    └── unverified_qr_modal.dart      # Bottom sheet displaying unverified format recognition

test/features/qr/
├── qr_payload_parser_test.dart       # Parser unit tests
├── qr_scanner_screen_test.dart       # Scanner lifecycle & widget tests
└── unverified_qr_modal_test.dart     # Modal UI presentation tests
```

### Component 1: `QrPayloadParser` (`lib/features/qr/domain/qr_payload_parser.dart`)
- **Validation Rules:**
  1. Exact prefix: Must begin with `resqme:v1:`.
  2. Length check: Reference portion must be exactly 43 characters long.
  3. Character set: Reference must consist strictly of URL-safe base64 characters `[A-Za-z0-9_-]`.
  4. 32-Byte Reference & Canonical Encoding:
     - Decode reference bytes: `base64Url.decode(base64.normalize(reference))`.
     - Length of decoded bytes must equal exactly 32.
     - Canonical verification: `base64Url.encode(bytes).replaceAll('=', '') == reference`. Ensures no dirty/hidden bits exist in the 43rd character's padding bits.
  5. Fail closed: Rejects empty strings, arbitrary URLs (`http://`, `https://`), unsupported versions (`resqme:v2:...`), and malformed encoding.
- **Result Model:**
  ```dart
  sealed class QrScanResult {
    const QrScanResult();
  }

  class ValidResQMeQr extends QrScanResult {
    const ValidResQMeQr();
  }

  class InvalidQr extends QrScanResult {
    const InvalidQr({required this.reason});
    final String reason;
  }
  ```
  *(Note: `rawSnippet` and raw tokens are excluded from all models to prevent credential leakage).*

### Component 2: `QrScannerScreen` (`lib/features/qr/presentation/qr_scanner_screen.dart`)
- Replaces `Tier1PendingScreen` at `AppRoutes.scanner`.
- Controller: `MobileScannerController` with:
  - `detectionSpeed: DetectionSpeed.noDuplicates`
  - `formats: const [BarcodeFormat.qrCode]`
  - `autoStart: true`
- **Lifecycle Management (`WidgetsBindingObserver`):**
  - Pauses camera (`controller.stop()`) when app is in background or inactive (`AppLifecycleState.paused` / `inactive`).
  - Resumes camera (`controller.start()`) when app returns to foreground (`AppLifecycleState.resumed`).
  - Cleans up and disposes controller and observer in `dispose()`.
- **Scanning & Modal Lifecycle:**
  - `_isProcessing` boolean lock prevents duplicate triggers.
  - Pauses camera scanning while result modal is open.
  - Resumes scanning cleanly when "Scan Again" is pressed.
- **Permission & Error States:**
  - Handled via `mobile_scanner`'s built-in `errorBuilder` / authorization state listener.
  - When camera permission is denied, displays a clear explanation: `"Camera access is needed to scan emergency QR codes in the field."` with `"Try Again"` and `"Back to Dashboard"` buttons.
  - Clean error card if camera hardware is unavailable.
- **Viewfinder Styling:**
  - Darkened overlay with transparent scanning viewport.
  - Red corner brackets (`Color(0xFFE92B32)`).
  - Torch toggle button in app bar.
  - Back navigation to Dashboard.

### Component 3: `UnverifiedQrModal` (`lib/features/qr/presentation/unverified_qr_modal.dart`)
- Modal bottom sheet presented upon detection:
  - For `ValidResQMeQr`:
    - Title: `"RESQME QR FORMAT RECOGNIZED"`
    - Red badge: `"UNVERIFIED — TEST PILOT ONLY"` (`Color(0xFFE92B32)`)
    - Subtitle: `"This QR code matches the ResQMe format, but its identity and status have not been verified."`
    - Safety text: `"No personal identification, medical records, or Tier 2 emergency data are accessible offline."`
    - Actions:
      - Filled Button: `"Scan Again"` (dismisses modal, resumes camera).
      - Outlined Button: `"Back to Dashboard"` (dismisses modal, navigates back).
  - For `InvalidQr`:
    - Title: `"UNRECOGNIZED QR CODE"`
    - Status: `"Invalid format"`
    - Subtitle: `"This QR code does not match the ResQMe format."`
    - Actions: `"Scan Again"` and `"Back to Dashboard"`.
  - **Zero PII & Zero Token Display:** Does not display any raw payload, student name, or medical details.

---

## 4. Test Organization & Verification Plan

All tests are placed strictly under `test/features/qr/` (never inside `lib/`):
1. **`test/features/qr/qr_payload_parser_test.dart`:**
   - Valid 32-byte canonical base64url payloads (`resqme:v1:<43-chars>`).
   - Non-canonical padding bits rejected.
   - Non-32-byte references rejected.
   - Invalid versions (`resqme:v2:...`, `qr:...`) rejected.
   - Web URLs (`https://...`), phone numbers, plain text rejected.
   - Null, empty, and whitespace rejected.
   - Verifies no raw payload snippet exists in `InvalidQr`.
2. **`test/features/qr/unverified_qr_modal_test.dart`:**
   - Valid format recognized copy verified.
   - Unrecognized QR copy verified.
   - Callback actions verified ("Scan Again", "Back to Dashboard").
   - Asserts absence of raw token strings and PII fields.
3. **`test/features/qr/qr_scanner_screen_test.dart`:**
   - Permission-denied fallback rendering.
   - Camera-unavailable error fallback rendering.
   - Back navigation returns to Dashboard.
4. **Existing Test Failure Isolation:**
   - Pre-existing 3 test failures documented as outdated test expectations stemming from preserved user UI edits.
   - Full suite execution recorded cleanly without masking or weakening existing tests.
