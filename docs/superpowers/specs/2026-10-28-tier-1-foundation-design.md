# ResQMe Tier 1 foundation design

## Intent

Build a simple, Android-first ResQMe pilot for synthetic data. Tier 1 provides
public emergency support and QR-based student identification without putting
medical data in QR payloads, public screens, or logs. Tier 2 medical-data
access is explicitly out of scope.

## Goals

- Establish an app shell for the Tier 1 screens: splash, consent, public
  dashboard, scanner entry point, first aid, hotlines, DRRM, and student
  entry points.
- Make `resqme-943ee` the staging-only Firebase project and ensure local
  development uses Firebase emulators.
- Keep Firebase access behind thin services so later QR, enrollment, locking,
  admin, and emergency-contact workflows can be implemented and tested safely.
- Preserve the existing Android application ID, `com.example.resqme`, because
  it matches the registered Firebase Android app.

## Non-goals

- Tier 2 medical information or medical-data storage.
- A production Firebase connection, deployment, billing change, or real
  student records.
- A claim that ordinary `tel:` dialing masks private contact details.
- New architecture frameworks, global state-management packages, or a routing
  package.

## Approaches considered

1. Feature-first Flutter structure with Flutter's built-in navigation and
   small Firebase service boundaries. Chosen: it keeps the pilot simple while
   preventing later security-sensitive work from becoming coupled to widgets.
2. A single-file or prototype-style app. Rejected: it would entangle the
   public scanner, student enrollment, and future privileged paths.
3. A framework-heavy layered app with external routing and state management.
   Rejected: it adds setup and concepts without providing needed Tier 1 value.

## Foundation design

### Client structure

```text
lib/
  main.dart                         # Firebase bootstrap and app launch
  app/
    resqme_app.dart                 # theme and Navigator route table
    app_routes.dart                 # route names only
  core/
    config/firebase_environment.dart # emulator-only local configuration
  features/
    welcome/                        # splash and Terms & Privacy
    emergency/                      # Tier 1 dashboard placeholder
```

This is intentionally small. New feature folders will be added only when a
Tier 1 slice is implemented.

### Navigation and user flow

On first launch, show the ResQMe splash then the Terms & Privacy screen. After
acceptance, persist only the acceptance flag locally and open the public
emergency dashboard. The dashboard presents public-support destinations; the
scanner and student enrollment remain future routes rather than fake features.

### Firebase and local development

- Add a Firebase CLI project alias named `staging` for `resqme-943ee`.
- Add Emulator Suite configuration for Authentication, Firestore, Functions,
  and the Emulator UI, plus the minimal TypeScript Functions scaffold that
  Emulator Suite requires. No callable endpoint or deployment is part of A0.
- In debug builds, connect the Flutter Firebase SDKs only to emulators before
  any Firebase request: `10.0.2.2` from an Android emulator and `localhost`
  from other supported local targets. A staging project ID alone must not make
  the client connect to live services.
- Production/release Firebase access is not enabled by this foundation.
- Retain the existing FlutterFire metadata in `firebase.json` and add Emulator
  Suite entries around it. The Firebase CLI warning for its `flutter` key is
  known and will be reported, not hidden.

### Dependencies

Add only the foundation dependencies in this slice: `firebase_auth ^7.0.1`,
`cloud_firestore ^7.1.0`, `cloud_functions ^7.0.1`, and
`shared_preferences ^2.5.6`. Keep `firebase_core ^5.1.0`.

Defer `mobile_scanner ^7.4.2`, `qr_flutter ^4.1.0`, and `url_launcher ^6.3.3`
until the scanner, QR display, and hotline slices. This avoids unused platform
permissions and dependencies in A0.

### Security boundary

The app foundation does not authorize privileged operations. Later QR creation,
verification, locking, replacement, contact calling, and audit logging require
Cloud Functions plus Firestore Rules tests. The public UI never receives or
stores medical details.

### Testability

The local consent preference is accessed through an injectable repository.
Widget tests use an in-memory implementation, so they verify first-launch and
returning-user navigation without Firebase plugins or an emulator process.

## Acceptance criteria for A0

- The default counter screen is replaced with the ResQMe themed splash,
  consent, and public dashboard navigation.
- Firebase initializes and debug clients point to local emulators.
- The project has an explicit `staging` alias for `resqme-943ee` and Emulator
  Suite configuration, without deployment.
- Widget tests cover first-launch consent navigation and returning-user
  navigation; tests are first written red, then made green.
- `flutter analyze` and `flutter test` pass. Firebase emulator startup and
  focused configuration checks are reported separately.

## Open constraints

The supplied scope and mockup PDFs could not be rendered in this environment:
Poppler and a usable Python PDF library are absent, and no browser surface is
available. Their product content remains reference material, not authority to
override this approved design or the user request.
