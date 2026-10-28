# Tier 1 architecture and repository inventory

Status: M0 inventory, 2026-10-25. This is a proposal, not an implemented or approved production design. The [requirements matrix](requirements.md) and [decision log](decisions.md) define the next gates.

## Confirmed repository baseline

- `lib/main.dart` is the Flutter template counter app. It has one `MaterialApp` home screen, local `setState` for the counter, and no route or state-management framework to preserve.
- `pubspec.yaml` declares Flutter, `cupertino_icons`, `flutter_test`, and `flutter_lints`. It declares no Firebase, camera, QR, calling, or content dependencies or assets.
- `test/widget_test.dart` only verifies counter increments. There are no feature, integration, or security-rules tests.
- Android, iOS, web, and Windows runner scaffolds exist. Their presence does not establish supported or tested product targets. Android uses the template `com.example.resqme` application ID and debug signing for release. Neither Android nor iOS declares camera permission or deep-link handling.
- No `firebase.json`, `.firebaserc`, FlutterFire options, Firestore rules, Cloud Functions, CI workflow, or `AGENTS.md` exists in this folder. No Firebase project or environment is configured here.
- This folder and its parent do not contain a `.git` repository. Git status, history, branch creation, and reviewable commits are unavailable until the project owner supplies or initializes the intended repository. Do not initialize Git merely to imply this copy has project history.
- `flutter analyze` passed with no issues; `flutter test` passed the one template counter test. Neither result validates a Tier 1 feature.

## Proposed additive structure

Keep `lib/main.dart` as the bootstrap and introduce focused feature directories under `lib/features/` as each milestone starts. Use Flutter's existing `Navigator` and local state initially; add a state package only if a concrete flow needs it. Add `functions/`, `firestore.rules`, and emulator configuration during M1. Put approved, versioned public resources under `assets/` during M4/M5. No Tier 2 medical data model, screen, or seed data belongs in Tier 1.

| Flow | Trust boundary and proposed behavior |
| --- | --- |
| Public help | Bundled approved hotline/guide content is available without authentication or a QR. Public phone numbers may open the platform dialer. |
| Student/admin | Firebase Auth identifies the actor; a trusted backend provisions roles and school/ownership links. Client navigation is only presentation. |
| QR issuance | An authenticated owner or authorized admin requests a server-generated random token. Backend verifies consent/ownership, stores only its digest and status, audits issuance, and returns an HTTPS QR URL for rendering/printing. |
| QR scan | Scanner parses an expected HTTPS URL and sends the opaque token to a rate-limited resolver. The backend checks current status online and returns only a minimal, nonmedical view model. Locked, revoked, malformed, and offline states fail closed; public help stays reachable. |
| Protected contact | A verified private contact stays server-side. An active QR can request a guarded, rate-limited call through an approved relay. Neither Flutter, resolver output, nor dialer receives the private number. This flow remains blocked until provider and policy decisions are made. |
| QR lifecycle | Backend authorizes owner reporting and admin lock/reactivation/replacement, performs atomic state transitions, and writes an audit event. Replacement permanently invalidates the old token. |

Firestore rules should default deny, allow at most narrowly scoped reads of published public resources and safe own-user fields, and deny all direct client credential/contact/audit writes. Server functions must verify all privileged operations because the Admin SDK bypasses rules. Logs, analytics, errors, and caches must not contain raw QR tokens, phone numbers, or medical data. App Check may add abuse protection but is not authorization.

## Dependency sequence

M1: isolated dev Firebase/emulators, trusted identity and roles, restrictive rules, rules tests. M2: consent-backed enrollment and credential issuance. M3: resolver/scanner/safe dashboard. M4/M5: reviewed public calls and offline guides. M6: approved relay integration. M7: explicit nonfunctional medical-alert boundary. M8: audited lost-ID and QR lifecycle. M9: integrated security, device, accessibility, content, and release evidence. Decisions in `decisions.md` gate any flow relying on real school contacts, student data, medical content, or telephony.

## First safe M1 implementation slice

After the intended Git repository and a dedicated **development** Firebase project are identified, add Emulator Suite configuration, a default-deny `firestore.rules`, and emulator tests proving anonymous and authenticated clients cannot read or write `students`, `emergencyContacts`, `qrCredentials`, or `auditLogs`. Use only synthetic fixtures. This slice needs no real enrollment, privileged function, or deployment. Authentication, role provisioning, and limited safe reads follow once their policy is approved.
