# ResQMe Tier 1 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stock Flutter app with the safe, themed ResQMe Tier 1 foundation and local Firebase Emulator Suite setup.

**Architecture:** Flutter uses built-in named routes and a small injectable consent repository. Firebase initialization is centralized and debug builds connect only to the local Emulator Suite before requests. The minimal TypeScript Functions project exists solely to satisfy the local emulator configuration; it exposes no endpoint.

**Tech Stack:** Flutter 3.44/Dart 3.12, Material 3, Firebase Core/Auth/Firestore/Functions, SharedPreferences, Firebase CLI 15.34, TypeScript, Node.js 22 runtime target.

**Spec:** `docs/superpowers/specs/2026-10-28-tier-1-foundation-design.md`

## Global Constraints

- `resqme-943ee` is staging-only; do not deploy, alter billing, or use production Firebase resources.
- Preserve Android package ID `com.example.resqme` because it is the registered Firebase Android app.
- Debug client connections use local emulators only: `10.0.2.2` on Android emulators and `localhost` on other local targets.
- Release/profile builds must not silently enable live Firebase access.
- Store only the local consent flag in this slice; no medical data, QR payload, student record, or audit event is introduced.
- Do not add a routing or state-management package. Do not add scanner, QR, or dialing dependencies in A0.
- Add Firebase dependencies at these constraints: `firebase_auth ^7.0.1`, `cloud_firestore ^7.1.0`, `cloud_functions ^7.0.1`, `shared_preferences ^2.5.6`; retain `firebase_core ^5.1.0`.

## Review Focus

- First launch with no stored preference must show Terms & Privacy, not the dashboard. Tested in Task 2.
- A stored acceptance flag must bypass consent on the next app creation. Tested in Task 2.
- Tapping acceptance must persist the flag before navigating to the dashboard. Tested in Task 3.
- An Android emulator must use `10.0.2.2`, not loopback. Tested in Task 1.
- Firebase must configure emulator endpoints before authentication, Firestore, or Functions can receive a client request. Tested in Task 1 through the injected connector call sequence.

---

### Task 1: Stage-safe Firebase and Emulator foundation

**Files:**
- Create: `.firebaserc`
- Modify: `firebase.json`
- Create: `firestore.rules`
- Create: `firestore.indexes.json`
- Create: `functions/package.json`
- Create: `functions/tsconfig.json`
- Create: `functions/src/index.ts`
- Create: `functions/test/config.test.ts`
- Modify: `pubspec.yaml`
- Create: `lib/core/config/firebase_environment.dart`
- Create: `test/core/config/firebase_environment_test.dart`

**Interfaces:**
- Produces `FirebaseEmulatorEndpoints.forPlatform(TargetPlatform)` with `authHost`, `firestoreHost`, and `functionsHost` string fields.
- Produces `configureFirebaseForDebug(FirebaseConnector connector, TargetPlatform platform) -> Future<void>`; the connector exposes three endpoint-registration methods so emulator wiring can be tested without Firebase plugins.
- Produces a TypeScript Functions package that compiles with `npm.cmd run build` and contains no exported callable or HTTP functions.

- [ ] **Step 1: Write the failing Dart endpoint-selection tests**

Add tests asserting Android receives `10.0.2.2` and Windows receives `localhost`, both using Auth `9099`, Firestore `8080`, and Functions `5001`; add a fake connector asserting registration order is Auth, Firestore, Functions.

- [ ] **Step 2: Run the endpoint-selection test to verify it fails**

Run: `flutter test test/core/config/firebase_environment_test.dart`

Expected: FAIL because `FirebaseEmulatorEndpoints` and `configureFirebaseForDebug` do not exist.

- [ ] **Step 3: Implement the minimal emulator environment API**

Create `lib/core/config/firebase_environment.dart` with the interfaces above. Use only debug-only caller invocation; never choose live-service configuration as a fallback.

- [ ] **Step 4: Run the endpoint-selection test to verify it passes**

Run: `flutter test test/core/config/firebase_environment_test.dart`

Expected: PASS.

- [ ] **Step 5: Add Firebase packages and local Emulator Suite files**

Add the four package constraints from Global Constraints. Create `.firebaserc` with `staging` mapped to `resqme-943ee`. Extend (do not replace) `firebase.json` with Auth, Firestore, Functions, and Emulator UI entries. Add deny-by-default Firestore Rules and empty indexes. Create the TypeScript-only `functions/` scaffold using Node 22 target and no Functions exports.

- [ ] **Step 6: Build the Functions scaffold and start emulator configuration validation**

Run: `npm.cmd install` then `npm.cmd run build` in `functions`; run `firebase.cmd emulators:exec --only auth,firestore,functions "echo emulator-ready"` from repository root.

Expected: Functions TypeScript compilation succeeds; Emulator Suite starts locally and prints `emulator-ready`. Report the known FlutterFire `firebase.json` warning if Firebase CLI emits it.

- [ ] **Step 7: Commit the safe Firebase foundation**

```powershell
git add .firebaserc firebase.json firestore.rules firestore.indexes.json functions pubspec.yaml pubspec.lock lib/core/config/firebase_environment.dart test/core/config/firebase_environment_test.dart
git commit -m "feat: add staging emulator foundation"
```

### Task 2: Theme, consent persistence, and route bootstrap

**Files:**
- Create: `lib/app/app_routes.dart`
- Create: `lib/app/resqme_app.dart`
- Create: `lib/app/resqme_theme.dart`
- Create: `lib/features/welcome/data/consent_repository.dart`
- Create: `lib/features/welcome/data/shared_preferences_consent_repository.dart`
- Create: `lib/features/welcome/presentation/splash_screen.dart`
- Create: `lib/features/welcome/presentation/terms_privacy_screen.dart`
- Create: `test/features/welcome/resqme_app_test.dart`
- Modify: `lib/main.dart`
- Delete: `test/widget_test.dart`

**Interfaces:**
- Produces route constants `AppRoutes.terms` and `AppRoutes.dashboard`.
- Produces `ConsentRepository.hasAcceptedTerms() -> Future<bool>` and `ConsentRepository.acceptTerms() -> Future<void>`.
- Produces `ResQMeApp({required ConsentRepository consentRepository})` for plugin-free widget testing.

- [ ] **Step 1: Write the failing bootstrap widget tests**

Create a fake `ConsentRepository`. Test that a false `hasAcceptedTerms()` result renders `Terms & Privacy`; test that true renders the dashboard route target. Assert the stock counter text is absent in both tests.

- [ ] **Step 2: Run the bootstrap widget tests to verify they fail**

Run: `flutter test test/features/welcome/resqme_app_test.dart`

Expected: FAIL because `ResQMeApp` and `ConsentRepository` do not exist.

- [ ] **Step 3: Implement the minimal themed app shell**

Create the route table, accessible Material 3 ResQMe theme, splash, terms screen, SharedPreferences repository, and root widget. The splash resolves consent once and replaces itself with Terms & Privacy or the dashboard route. Update `main.dart` to initialize Firebase and configure emulators only in debug builds before creating the real consent repository and running `ResQMeApp`.

- [ ] **Step 4: Run the bootstrap widget tests to verify they pass**

Run: `flutter test test/features/welcome/resqme_app_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit the app shell**

```powershell
git add lib/main.dart lib/app lib/features/welcome test/features/welcome test/widget_test.dart
git commit -m "feat: add ResQMe consent app shell"
```

### Task 3: Consent action and public emergency dashboard

**Files:**
- Create: `lib/features/emergency/presentation/emergency_dashboard_screen.dart`
- Modify: `lib/features/welcome/presentation/terms_privacy_screen.dart`
- Modify: `test/features/welcome/resqme_app_test.dart`

**Interfaces:**
- Consumes `ConsentRepository.acceptTerms() -> Future<void>` from Task 2.
- Produces `EmergencyDashboardScreen`, a public Tier 1 landing screen with visible labels for Scan QR, First Aid, Emergency Hotlines, and DRRM Guidance; non-implemented destinations are not interactive.

- [ ] **Step 1: Write the failing acceptance widget test**

Add a test that taps `I Agree`, awaits settling, asserts the fake repository recorded acceptance, and finds the `Emergency Support` dashboard heading plus the four public destination labels.

- [ ] **Step 2: Run the acceptance widget test to verify it fails**

Run: `flutter test test/features/welcome/resqme_app_test.dart`

Expected: FAIL because the acceptance action and dashboard do not exist.

- [ ] **Step 3: Implement the consent action and dashboard**

Make the Terms & Privacy primary action await `acceptTerms()` and replace the navigation stack with `AppRoutes.dashboard`. Implement the dashboard as a responsive Material layout following the supplied mockup's accessible, emergency-first visual direction without fabricating QR, hotline, or medical-access behavior.

- [ ] **Step 4: Run the acceptance widget test to verify it passes**

Run: `flutter test test/features/welcome/resqme_app_test.dart`

Expected: PASS.

- [ ] **Step 5: Run the focused Flutter verification**

Run: `flutter analyze` then `flutter test`.

Expected: both exit 0; report test count and any warnings.

- [ ] **Step 6: Commit the dashboard slice**

```powershell
git add lib/features/emergency lib/features/welcome test/features/welcome
git commit -m "feat: add public emergency dashboard"
```

### Task 4: Android debug verification and A0 handoff

**Files:**
- Modify: `README.md`

**Interfaces:**
- Documents the exact local command sequence to build Functions, start emulators, and run the Android debug app against them. It must state that no production connection or deployment occurs.

- [ ] **Step 1: Add the failing documentation acceptance checklist**

Add an A0 README checklist that requires `functions` build, `firebase emulators:start`, and `flutter run` with an Android emulator; include the fixed staging project ID and emulator ports.

- [ ] **Step 2: Verify the documented commands against the workspace**

Run: `npm.cmd run build` in `functions`; run `firebase.cmd emulators:exec --only auth,firestore,functions "flutter test"`; run `flutter build apk --debug`.

Expected: all commands exit 0. If no Android emulator/device exists, APK build is the automated Android validation and the missing interactive run is reported as BLOCKED, not passed.

- [ ] **Step 3: Commit the A0 handoff**

```powershell
git add README.md
git commit -m "docs: add A0 emulator runbook"
```

## Self-review

- **Spec coverage:** Task 1 covers the staging alias, local emulators, Firebase package configuration, and Functions scaffold. Task 2 covers splash, Terms & Privacy, theme, and initialization. Task 3 covers accepted-consent navigation and the public emergency dashboard. Task 4 proves reproducibility and Android compilation. Tier 2 remains absent.
- **Step scan:** Every implementation task starts from a specific failing test, uses named interfaces, then verifies behavior before committing.
- **Type consistency:** `ConsentRepository` is defined in Task 2 and consumed identically in Task 3. `FirebaseEmulatorEndpoints` and `FirebaseConnector` are defined and tested solely in Task 1.
- **Review Focus:** All five focus items are explicitly owned by Task 1, 2, or 3 test steps.
- **Proportion:** Four independently reviewable tasks produce the smallest vertical A0 slice; scanner, QR, hotline, DRRM, enrollment, locking, admin, calling, alerting, rules, and audit work are deferred to later Tier 1 plans.
