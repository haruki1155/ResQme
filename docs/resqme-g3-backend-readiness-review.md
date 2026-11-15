# ResQMe G3 backend readiness and G4 deployment preparation

Date: 2026-11-09 (Checkpoint 1 IAM applied and verified; local Node 22 candidate rebuilt; read-only staging Auth metadata verified.)
Decision: **G3 GO for the controlled debug-only staging pilot. G4 deployment and hosted synthetic testing remain NOT AUTHORIZED until separate approval.** G2 remains accepted under the owner-attestation exception, not technically verified as empty.

## Scope and evidence boundary

This review covers the current local worktree, fresh local Node 22 build/tests, Firebase CLI package preparation, official Firebase/Google Cloud documentation, and owner-authorized staging metadata for exactly `resqme-943ee`. Under explicit Checkpoint A approval, only Cloud Build, Artifact Registry, and Cloud Run APIs were enabled. Under the later explicit Checkpoint 1 approval, the dedicated runtime service account and its exact custom role/binding were created and verified. No deployment, Rules/App Check change, hosted account creation, business Function invocation, or application-data access occurred. Hosted reads remained limited to project/API/IAM/service-account, Function inventory, App Check, Rules, and Auth provider metadata. No credentials or tokens were printed or disclosed.

The active target was confirmed as `resqme-943ee` (project number `519076598217`, lifecycle `ACTIVE`). The last hosted Rules metadata read showed Firestore and default Storage deny-all; no Rules operation occurred during API enablement. Cloud Functions inventory remains empty. All local emulator tests were pinned to `demo-resqme` and loopback endpoints. For the earlier Node 22 rerun, the existing listener on 8080/9150 was left untouched; test-owned emulator processes on alternate ports were stopped.

## Repository state

- Branch: `main`; local `HEAD` is `47fd30e`; `origin/main` is `50670a2`, one commit behind. Local worktree is authoritative; no GitHub source was used.
- `.firebaserc` maps both `default` and `staging` to `resqme-943ee`. `firebase.json` selects Functions runtime `nodejs22`, deploys `firestore.rules`, and contains **no Storage Rules configuration**.
- Existing local worktree changes were preserved. `functions/package.json` has owner changes to test scripts only; `pubspec.yaml`/`pubspec.lock` and generated Windows plugin files are also modified. Existing untracked docs and `functions/test`/`functions/tools` files were not removed or altered.
- The prior readiness review had not changed production `functions/src` or Flutter `lib`; the subsequent locally approved profile correction is documented below. No hosted deployment followed.

## Registration and QR data flow

1. The Flutter registration screen validates the form and obtains the privacy acknowledgment. `FirebaseStudentRegistrationRepository.register` creates the Firebase Authentication email/password account directly through `createUserWithEmailAndPassword`; the registration Function does **not** create the Auth account.
2. The client calls the `createStudentRegistration` v2 callable with a 10-second client timeout. The callable requires `request.auth`, derives UID only from the verified callable context, validates/normalizes fields and acknowledgment server-side, and ignores client-supplied approval status/LRN. It does not require `email_verified` and has no App Check enforcement option.
3. In a Firestore transaction, the Function creates `studentProfiles/{uid}` and `studentProfiles/{uid}/acknowledgments/tier1-registration-v1`. Status is server-derived: under 18 becomes `pending_guardian`; otherwise `pending_review`. Existing identical registration is idempotent; conflicting existing profile data returns `already-exists` rather than overwriting it.
4. **Before the approved local correction**, the Flutter client independently read `studentProfiles/{uid}` from the Firestore server after the registration callable returned. Under the reported hosted deny-all Rules, that direct read failed. The locally implemented `getMyStudentProfile` callable now replaces this direct registration-profile read; it is not deployed. If registration itself fails after Auth account creation, the account is retained and the UI offers “Complete registration”/retry; a repeat with the same data is safe.
5. After registration, the app opens its medical step; the user can skip it and proceed to the QR. Saving/clearing medical data uses separate QA-entitled callables and is not required for a registration→skip→QR smoke test.
6. `ensureMyTier1Qr` requires authentication and a pending profile. A transaction creates or reuses `studentQrCredentials/{uid}` with a random 32-byte base64url opaque value and `verificationStatus: unverified`; client-supplied UID/authority fields are rejected. Repeated/concurrent calls return the same stored QR. The QR does not contain profile or medical fields.
7. The current QR screen retrieves/creates the reference through the callable. `Tier1QrRepository.loadMine` also exists and performs a direct client Firestore read, but the reviewed UI uses `ensureMine` rather than `loadMine`. The scanner is offline: it validates only canonical payload syntax/length and does not resolve identity or enrollment. No lost-ID lock, revocation, or regeneration workflow was found.
8. No Firebase Storage SDK use, upload, download, or Storage-backed QR is present. `storageBucket` values in generated Firebase options are configuration values only; there is no local `storage.rules` file or Storage deployment stanza.

### Original Rules incompatibility — corrected locally; hosted deployment pending

The checked-in [firestore.rules](../firestore.rules) permits owner reads of profiles, acknowledgments, medical records, and QR credentials; it denies all client writes and defaults to deny. Its SHA-256 is `A5B5F8A8F00F7E96E15C231B4DDF2895CF86D6F26969C4CB6A24AA71593E1B5B`. This is **not** deny-all. If the reported deployed deny-all Rules are active, current Flutter registration cannot complete its post-callable profile read and sign-in/profile refresh will also fail. The QR screen’s callable path can still return the stored QR, but the account UI cannot reach it without a loaded profile. The direct `loadMine` QR method would also fail under deny-all.

This describes the incompatibility at the pre-implementation baseline. The current local registration repository no longer reads its profile directly: it calls the approved authenticated `getMyStudentProfile` endpoint. That source correction has not been deployed, so the hosted registration/profile flow remains blocked until its separately approved deployment and synthetic acceptance. Sign-in/profile refresh in the local source uses the callable; deny-all Rules remain unchanged. The separate dashboard medical repository still reads `studentProfiles/{uid}` and `studentMedicalRecords/{uid}` directly, so those medical views remain incompatible with hosted deny-all Rules.

Do not deploy the local Rules to “fix” this: it would grant owner reads, including medical data, and would change the owner-reported deny-all policy. The owner selected the server-mediated profile approach and approved its response allowlist; the callable is implemented locally. The earlier narrowly scoped owner-only profile `get` Rule remains only a rejected comparison and was not applied. QR retrieval remains through the existing `ensureMyTier1Qr` callable; the direct `loadMine` QR method is unused by the reviewed QR screen and would fail under deny-all.

## Function dependency map

All current exports are v2 `onCall` handlers. Source does not set `region`; the Flutter client uses `us-central1`, which is the intended/default region and must be confirmed from hosted metadata. `firebase.json`/`functions/package.json` target Node.js 22.

| Export | Trigger/authentication | Firestore and dependencies | App Check / environment |
| --- | --- | --- | --- |
| `createStudentRegistration` | Callable; requires Firebase Auth `request.auth`; no server-side Auth account creation | `studentProfiles/{uid}`, profile `acknowledgments/{noticeVersion}`; Admin SDK transaction | `enforceAppCheck` absent. No user secret/config; Admin SDK uses runtime identity. |
| `getMyStudentProfile` | Callable; requires Firebase Auth and rejects request fields; derives UID only from `request.auth.uid` | Reads only `studentProfiles/{auth.uid}` through Admin SDK; returns the approved allowlist | `enforceAppCheck` absent. No user secret/config. |
| `ensureMyTier1Qr` | Callable; requires Auth UID and pending profile | Reads `studentProfiles/{uid}`, creates/reuses `studentQrCredentials/{uid}`; Node `crypto` | `enforceAppCheck` absent. No user secret/config. |
| `saveMySyntheticMedicalRecord` | Callable; requires Auth UID, pending registration and `qaTesters/{uid}` with `enabled:true` and `syntheticOnly:true` | `studentProfiles`, `studentMedicalRecords/{uid}`, its `requests` and `acknowledgments`, and `qaTesters` | `enforceAppCheck` absent. No user secret/config. |
| `clearMySyntheticMedicalRecord` | Same Auth and QA gates | Same profile, medical record, request receipt and acknowledgment paths | `enforceAppCheck` absent. No user secret/config. |

`onboardingDatabase` checks `GCLOUD_PROJECT`/`GOOGLE_CLOUD_PROJECT` against the fixed demo/staging IDs for the QR and medical Functions. Registration relies on the selected Firebase project/default Admin SDK rather than its own equivalent project guard, so exact deployment targeting is essential. No triggers or dependencies on external HTTP APIs, Storage, scheduled jobs, or Pub/Sub appear in Function source.

## G3 readiness report

| Component | Status | Evidence | Required action |
| --- | --- | --- | --- |
| Target project | **PASS** | Hosted metadata confirms project `resqme-943ee`, number `519076598217`, lifecycle `ACTIVE`; local aliases agree. | Keep every future command explicitly pinned to this project. |
| Registration backend | **PASS locally / FAIL hosted (absent)** | `createStudentRegistration` and the local `getMyStudentProfile` callable pass unit/emulator tests. The fresh hosted inventory returned no Functions, so neither endpoint is deployed. | A Functions-only deployment requires separate G4 approval. |
| Persistent QR backend | **PASS locally / FAIL hosted (absent)** | Idempotent Firestore-backed `ensureMyTier1Qr`; no Storage use; QR emulator tests pass. The fresh hosted inventory returned no Functions; `ensureMyTier1Qr` is not deployed. | Any deployment requires separate G4 approval. |
| Firebase APIs | **PASS — approved deployment APIs enabled** | Cloud Functions, Cloud Build, Artifact Registry, and Cloud Run are enabled. The last three were enabled after explicit Checkpoint A approval; no other API was explicitly enabled. | No further API changes without separate approval. |
| IAM | **FAIL — owner strategy decision and workload audit required** | Operator is project Owner. Cloud Build default is the Compute account with project Editor. Firebase CLI-compatible option: replace Editor with `roles/run.builder`, but usage by other workloads is unknown. Dedicated builder via gcloud source deployment is supported but not validated against the reviewed package. Runtime role is mapped to three Firestore permissions. No Functions exist to verify deployed runtime/invoker identity. Service-agent detail reads failed with `iam.serviceAccounts.get`. | Select a build strategy; audit the shared Compute identity before any permission reduction. Approve only the exact operator/build/runtime role bindings and per-service invokers; no IAM change is authorized yet. |
| App Check | **BLOCKED — explicit residual-risk acceptance needed for G3 GO** | Provider configurations exist, but enforcement is `UNENFORCED`; Flutter has no initialization, callable handlers do not enforce it, and token readiness was not tested. No Functions are deployed. | Keep enforcement unchanged. Owner must explicitly accept this staging posture and residual abuse/attestation risk before G3 GO. Any debug-token or enforcement action requires separate approval. |
| Node.js 22 | **PASS — current source verified locally** | Official Node `v22.23.4` / npm `10.9.9` downloaded to a temporary directory and SHA-256 matched official `SHASUMS256.txt` and the previously recorded value. Current build/configured Functions suite passed **64/64**; isolated Auth/Firestore/Functions integration passed **10/10**; checked-in Rules passed **4/4**; deny-all containment passed **2/2** on a fresh isolated port. | No Node blocker remains for the local candidate. Preserve the system Node installation; the temporary runtime was removed after testing. |
| Firestore Rules | **PASS for restrictive posture; local profile route corrected, deployment pending** | The last authorized active `(default)` release `projects/resqme-943ee/releases/cloud.firestore` points to ruleset `aa4be7e8-ce25-44d1-afd8-c10654658bab`; source denies all reads and writes. The Flutter registration client now uses the authenticated server callable instead of a direct profile document read. A local deny-all fixture test passes; the checked-in `firestore.rules` is a separate owner-read policy and was not changed. | Preserve hosted deny-all. Deploying the new callable requires G4 approval; no Rules deployment or grant is proposed. |
| Storage Rules | **PASS for restrictive posture** | Active default bucket `resqme-943ee.firebasestorage.app` release points to ruleset `f0786fa3-4195-4c87-93ed-bde65612a8c0`; source denies all reads and writes. Local repo has no Storage Rules config/file and the app does not use Storage. | Keep these deployed Rules untouched. Do not add a Storage deployment target. |
| Existing hosted Functions | **BLOCKER — none deployed** | Fresh `gcloud functions list --v2 --project=resqme-943ee` returned no entries. No Function names, regions, runtimes, revisions, service identities, or invoker policies exist. No Function was invoked. | Registration, profile, and QR endpoints must be deployed before hosted flow acceptance; deployment is not authorized. |
| Billing | **PASS — billing enabled** | Read-only billing metadata reports `billingEnabled: true` for `resqme-943ee`. No billing account details are needed in this report. | Confirm expected costs in the final G4 manifest; no billing change is authorized. |

**Overall: G3 NO-GO.** Historical current-source Node 22 build/tests and emulator suites passed; they were not rerun in this IAM review. Checkpoint A enabled Cloud Build, Artifact Registry and Cloud Run. Remaining blockers include the broad active Owner grant, unknown impact of reducing the shared Cloud Build Compute account's Editor role, selection of Firebase CLI versus dedicated gcloud build identity, creation/approval of the runtime identity and exact operator grants, absent deployed Functions/invoker metadata, and explicit acceptance of App Check's unenforced staging posture. The three-Function candidate and Firebase CLI payload are hashed but remain unapproved and undeployed; they are not yet verified for the alternative gcloud path. G2 remains accepted under the owner-attestation exception; no data emptiness was checked in this preflight.

## Local Node.js 22, App Check and profile/QR review (2026-11-08)

### Historical pre-profile Node.js 22 verification

The repository declares Functions engine `22` and Firebase runtime `nodejs22`. The system Node installation was left untouched. For local-only validation, the official Node.js `v22.23.4` Windows x64 ZIP from `https://nodejs.org/dist/v22.23.4/node-v22.23.4-win-x64.zip` was verified against the official `SHASUMS256.txt`; actual SHA-256 was `cbc74b5e0982c9dbb41525fd8fb5dcd32fbee237863f7829072f4639a1ce5f20`. It reported Node `v22.23.4` and npm `10.9.9`. No dependency install, dependency-version change, or system-wide runtime change was performed.

Commands ran with the temporary Node directory first on `PATH`:

| Command | Result |
| --- | --- |
| From `functions`: `npm.cmd test` | Exit 0; TypeScript build passed and **60 passed, 0 failed, 0 skipped**. This includes the new alternate-loopback endpoint validation tests. |
| From the repository root: `firebase.cmd emulators:exec --config firebase.integration.node22.json --project demo-resqme --only auth,firestore,functions "node --test --test-concurrency=1 functions/lib/test/registration_integration.test.js functions/lib/test/onboarding_integration.test.js"` with Node 22 first on `PATH` and `GCLOUD_PROJECT=demo-resqme`, `GOOGLE_CLOUD_PROJECT=demo-resqme`, `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:19099`, `FIRESTORE_EMULATOR_HOST=127.0.0.1:18080`, `FUNCTIONS_EMULATOR_HOST=127.0.0.1:15001` | Exit 0; **9 passed, 0 failed**. Emulator output confirmed `Using node@22 from host`; Auth, Firestore, and Functions endpoints were on the isolated loopback ports. |
| From the repository root: `firebase.cmd emulators:exec --config firebase.integration.node22.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules"` with Node 22 first on `PATH` and `GCLOUD_PROJECT=demo-resqme`, `GOOGLE_CLOUD_PROJECT=demo-resqme`, `FIRESTORE_EMULATOR_HOST=127.0.0.1:18080` | Exit 0; **4 passed, 0 failed**. Exercises the checked-in local Rules only, not the deployed deny-all Rules. |

Firebase CLI emitted its standard warning that Application Default Credentials were detected and non-emulated services could use them. The test processes used the explicit `demo-resqme` project and local Auth/Firestore/Functions emulator endpoints; no hosted operation was part of these test cases. This historical run preserved the then-existing process PID 3024 on 127.0.0.1:8080 and :9150. The runtime and config used in that earlier run were removed. Current-source verification is recorded next.

### Current-source Node.js 22 verification and package refinement (2026-11-08 23:15 +08:00)

The official Node.js `v22.23.4` Windows x64 archive was downloaded from `https://nodejs.org/dist/v22.23.4/node-v22.23.4-win-x64.zip`. Its SHA-256 matched both the official published `SHASUMS256.txt` entry and the previously recorded value: `cbc74b5e0982c9dbb41525fd8fb5dcd32fbee237863f7829072f4639a1ce5f20`. It ran from an isolated temporary directory as Node `v22.23.4`, npm `10.9.9`; the system Node installation and dependency manifests/versions were not changed.

| Exact command / environment | Result |
|---|---|
| In `functions`, with the temporary Node 22 directory first on `PATH`: `npm.cmd test` | Exit **0**. TypeScript build passed; **64 tests passed, 0 failed, 0 skipped**. |
| From repository root, Node 22 first on `PATH`, `GCLOUD_PROJECT=demo-resqme`, `GOOGLE_CLOUD_PROJECT=demo-resqme`, emulator hosts Auth `127.0.0.1:19099`, Firestore `127.0.0.1:18080`, Functions `127.0.0.1:15001`: `firebase.cmd emulators:exec --config firebase.integration.node22.tmp.json --project demo-resqme --only auth,firestore,functions "npm.cmd --prefix functions run test:integration"` | Exit **0**; **10 passed, 0 failed**. Emulator output confirmed the demo project and `Using node@22 from host`. The test flow covers registration, authenticated owner profile retrieval/allowlisting, foreign-UID input rejection, and persistent/repeated QR behavior. |
| With Node 22 and `demo-resqme`: `firebase.cmd emulators:exec --config firebase.rules.node22.tmp.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules"`; config used `firestore.rules`, Firestore `127.0.0.1:18180`, websocket `19115` | Exit **0**; **4 passed, 0 failed**. Confirms the checked-in owner-read Rules regression suite. |
| First deny-all containment attempt: `firebase.cmd emulators:exec --config firebase.integration.node22.tmp.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules:contained"` | Exit **1** before tests ran: the Firestore emulator child from the preceding integration run remained on `18080/19015` after CLI shutdown. No process was terminated for this failed attempt; the retry used fresh ports. |
| Retry with Node 22 and `demo-resqme`: `firebase.cmd emulators:exec --config firebase.rules.node22.tmp.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules:contained"`; updated temporary config used `firestore.containment.rules`, Firestore `127.0.0.1:18280`, websocket `19280` | Exit **0**; **2 passed, 0 failed**. Confirms authenticated and unauthenticated direct client access remains denied in the deny-all fixture. |

All emulator configs were temporary and removed. The emulator child processes left by these commands were individually matched to the just-completed `demo-resqme` tests (their ports were free before launch) and stopped; no unrelated process was stopped. System Node remains unchanged. The downloaded Node archive/runtime was removed after verification.

Fresh Flutter regression after the test-harness adjustment (no Flutter product source changed): `flutter analyze` passed with no issues; `flutter test test\features\registration test\features\qr` passed **49 tests**.

### App Check readiness

- The Flutter app initializes Firebase Auth, Firestore, and Functions, but has no `firebase_app_check` dependency or `FirebaseAppCheck.activate()` call. It selects `us-central1` for callable Functions.
- The registration and QR exports are callable v2 Functions without `enforceAppCheck`. The hosted App Check services observed earlier are `UNENFORCED`; no Functions are deployed, and no Cloud Functions enforcement setting was observed.
- Therefore, App Check enforcement is **not currently blocking** these source callables. If `enforceAppCheck: true` is added to either callable before the debug client obtains and sends a valid token, Firebase will reject its registration/QR calls. Authenticated callable access alone does not satisfy App Check.
- Minimum debug-only path, only if enforcement is separately approved: add and initialize `firebase_app_check` immediately after Firebase initialization and before Firebase service use; use `AndroidProvider.debug` for the approved Android debug test device (and the documented debug provider for any other supported platform); privately register that device's generated token for the exact staging app. Never store the token in source, repository logs, screenshots, or this report, and never ship a debug provider/token in release builds. The official Flutter guide documents Play Integrity/DeviceCheck/reCAPTCHA for production providers and the debug provider for test environments. Windows is not listed among those documented Flutter provider platforms; do not assume Windows debug-provider support without a separate platform-specific verification.
- No debug token was requested, generated, registered, or exposed. No provider, enforcement setting, or hosted configuration was changed. Do not enable production attestation for this debug-only pilot unless separately selected and approved.
- Official guidance: [Flutter default App Check providers](https://firebase.google.com/docs/app-check/flutter/default-providers), [Flutter debug provider](https://firebase.google.com/docs/app-check/flutter/debug-provider), and [callable Functions enforcement](https://firebase.google.com/docs/app-check/cloud-functions).

### Authenticated profile and QR retrieval

1. **Profile and displayed name:** `createStudentRegistration` writes the profile with the Admin SDK, then returns only `status` and `profilePath`. After registration, and again after sign-in/status refresh, `FlutterFireRegistrationClient.readOwnProfile` performs a server-only direct read of `studentProfiles/{currentAuthUid}`. The UI displays the student's `fullName` and submitted registration/contact details. There is no preferred-name or nickname field or retrieval path in the current model.
2. **QR:** `MyUnverifiedQrScreen` calls `Tier1QrRepository.ensureMine`, which invokes the authenticated `ensureMyTier1Qr` callable. The callable derives UID from `request.auth`, verifies the pending profile, reads/creates `studentQrCredentials/{uid}` with the Admin SDK, and returns only `payload`, `verificationStatus: unverified`, and `issuedAt`. The payload is an opaque reference; no name, profile, contact, or medical data is returned. `Tier1QrRepository.loadMine` and `FirebasePilotClient.readMine('studentQrCredentials')` provide an unused direct Firestore-read route; the QR screen does not use it.
3. **Rules impact:** Hosted Firestore deny-all blocks direct client reads from the medical repository. The registration profile read now uses the local authenticated server callable, which bypasses Rules through the Admin SDK, but that callable is not deployed; the required hosted Functions are absent. Rules do not impose Firestore client permissions on Admin SDK calls inside Functions. The QR callable response remains private to the authenticated caller at the function layer.

**Approved and implemented locally:** Keep deployed deny-all Rules and use an authenticated server-side `getMyStudentProfile` callable. Derive the document path exclusively from `request.auth.uid`; reject client UID/authority input; reject missing or malformed profiles; and construct a fresh allowlisted response. The owner approved `schemaVersion`, `fullName`, `ageYearsAtRegistration`, `status`, optional valid `gender` and `personalContactNumber`, and only `emergencyContacts.primary.{fullName,relationship,phoneNumber}` and `emergencyContacts.secondary.{fullName,phoneNumber}`. LRN, acknowledgments, medical data, QR credentials, internal metadata, and unrecognized fields are excluded. There is no preferred-name/nickname field; the existing full name is retained.

This approach preserves Firestore deny-all and lets the backend enforce response minimization, but requires a new Function, Flutter repository rewiring, and deploy/invoker readiness. Compare the alternative narrowly scoped owner-only Rules grant below: it is smaller to implement and retains direct reads, but exposes every field in the profile document to that student and changes the client authorization surface; field-level response minimization is not possible with a document read rule. The owner-only Rules alternative must not be combined with the callable by default. In either design, QR retrieval remains exclusively through the existing `ensureMyTier1Qr` callable; do not change its response or grant QR-document reads.

Candidate rule addition under `match /databases/{database}/documents` (not applied):

```text
match /studentProfiles/{uid} {
  allow get: if request.auth != null && request.auth.uid == uid;
}
```

Keep the existing catch-all deny; that candidate rule intentionally grants no list, create, update, delete, acknowledgment-subcollection, medical-record, QR-document, or other-user access. It remains a comparison only and is not the preferred design for this review. If the owner selects it instead, add/retain emulator assertions that the owner can `get` exactly their profile while anonymous/other UIDs, collection listing, client writes, and unrelated document paths are denied, then review the exact deployed change and all Firestore effects for separate approval.

The dashboard's medical repository separately reads `studentProfiles/{uid}` and `studentMedicalRecords/{uid}` directly. The implemented profile callable addresses the registration/profile read only; medical reads and writes remain subject to deny-all and are outside this profile/QR correction. Before claiming full account/medical-dashboard readiness, decide separately between keeping that feature unavailable and an approved narrowly scoped server-mediated/Rules path. The current deployed Rules and backend have not been changed.

### Approved profile implementation and local verification

**Files changed for the implementation:**

- `functions/src/profile/get_my_student_profile.ts` (new) and `functions/src/index.ts`.
- `lib/features/registration/services/firebase_student_registration_repository.dart`.
- `functions/test/get_my_student_profile.test.ts`, `functions/test/profile_integration.test.ts`, and `functions/test/deny_all_rules.test.ts` (new); `functions/package.json` test selectors and `test/features/registration/firebase_student_registration_repository_test.dart`.
- No changes to the registration data model/schema, `functions/src/qr/ensure_my_tier1_qr.ts`, the QR repository/UI, medical/Tier 2 logic, Firestore Rules, or Storage Rules.

The callable uses the existing project/auth guard, derives the only profile path from the Firebase Auth UID, rejects all request fields, performs one document get, validates required and optional profile values, and constructs a new response. Emulator tests exercise unauthenticated, foreign-UID input, missing/malformed profile, exact top-level/nested response keys, registration-to-profile retrieval, and the unchanged QR callable's persistent repeat behavior. The test emulator uses `firestore.containment.rules`; its direct-client read/write denial tests pass while Admin SDK callables still work. The original owner-read `firestore.rules` suite also passes unchanged. The production Flutter registration client no longer directly gets `studentProfiles/{uid}`; its existing profile model and detail-review behavior remain unchanged.

At the time of this earlier local verification, Node `v24.18.0` / npm `12.0.2` were available. The current-source Functions build and configured unit suite passed **64/64**; isolated Auth/Firestore/Functions integration passed **10/10**; deny-all containment Rules passed **2/2**; the original local Firestore Rules suite passed **4/4**; Flutter analyze passed; and registration/QR Flutter tests passed **50/50**. A later owner authorization enabled a fresh Node 22 run, recorded in the current-source Node 22 section above; its test results also passed. All emulator tests used `demo-resqme` and isolated loopback ports; no hosted service was used.

**App Check debug-only staging sequence (no change authorized or made):**

1. Keep current behavior unchanged: hosted App Check is unenforced and source callables do not set `enforceAppCheck`; a prior emulator run logged App Check as `MISSING` while Auth was `VALID`, and calls passed because enforcement is off. This is not current-source Node 22 verification.
2. If a debug-only pilot is selected, first choose a supported test platform. Candidate local changes are `pubspec.yaml`/`pubspec.lock` to add the official Flutter App Check plugin and `lib/main.dart` to initialize it after Firebase and before Firebase service use. Select a debug provider only for the approved staging debug build; do not activate that provider in release/profile builds. Windows provider support is not established by the reviewed Flutter docs.
3. Generate and register a debug token only under separate approval, keep it out of source, logs, screenshots and this report, and prove authenticated registration/profile/QR callable requests carry valid App Check tokens while unauthenticated requests remain rejected.
4. Only after a separate approval, add callable enforcement for the specifically selected staging functions and repeat the synthetic local/staging acceptance tests. Do not add production attestation requirements to this debug-only pilot; never weaken Firebase Auth or UID ownership checks.

**Remaining G4 prerequisites and rollback:** G3 remains NO-GO. Cloud Build, Artifact Registry, and Cloud Run are now enabled under Checkpoint A; however the active operator still has broad Owner permissions, the default Cloud Build executor is a project-Editor Compute account, no least-privilege Functions runtime identity is selected, and no Functions or invoker policies exist. Read-only service-agent detail was partly denied. The CLI-prepared package is verified but the dirty source tree does not identify a reviewed immutable revision. The current App Check unenforced posture and its risk need explicit acceptance. Obtain approval for an exact IAM plan, reviewed source/artifact identity, and deployment command; hosted synthetic tests and cleanup remain a separate Checkpoint D. No prior Function revision exists in the fresh inventory, so establish and review a known-good artifact and recovery plan before deployment. Rollback must not delete accounts, Firestore data, or QR credentials.

## Hosted read-only preflight evidence (2026-11-08; pre-Checkpoint A snapshot)

- **Project/database:** `resqme-943ee` is `ACTIVE`, project number `519076598217`. The `(default)` database is Firestore Native in `nam5`. No collection or document was read.
- **Firestore Rules:** The active default release source is exactly `allow read, write: if false` for all documents. The release was created `2026-11-05T16:16:31Z`. This confirms the owner-reported deny-all posture and the incompatibility of the pre-correction direct profile-read flow. The callable correction is local and not deployed.
- **Storage Rules:** The default bucket is `resqme-943ee.firebasestorage.app`; the active release source is exactly `allow read, write: if false` for all objects. The release was created `2026-11-05T16:18:48Z`. No object was listed or read.
- **App Check (prior inspection, superseded below):** The earlier provider-status query did not surface provider entries for the four apps. The fresh provider-config endpoint checks below found configured provider resources. App Check service enforcement remains `UNENFORCED`; debug-token names or values were not queried.
- **APIs:** In this historical pre-Checkpoint A snapshot, `cloudfunctions.googleapis.com` was enabled, while Cloud Build, Artifact Registry, and Cloud Run were disabled/not listed. The configured gcloud default project is `mind-mates-cd2cf`; every staging request explicitly targeted `resqme-943ee`. The authorized API change is recorded in the later post-approval section.
- **IAM:** Project-level IAM includes `roles/owner` for the configured operator. The Firebase Admin SDK service account has the roles listed in the table above. Managed Firebase service-agent bindings were present. `gcloud iam service-accounts list` returned the `firebase-adminsdk-fbsvc` service account; this does not establish which identity any hosted Function would use.
- **Functions:** `gcloud functions list --project=resqme-943ee --format=json` returned an empty array (`[]`). A later v2 inventory check also found no Functions. No Function was invoked or deployed. The required registration and QR endpoints remain absent.
- **Billing:** Billing is enabled. No billing setting was modified.

## Fresh G3 hosted metadata recheck (2026-11-08 23:05 +08:00; pre-Checkpoint A snapshot)

All commands and metadata API requests were explicitly scoped to `resqme-943ee` / project number `519076598217`; no application records or callable endpoints were accessed. The gcloud configured default project still points to `mind-mates-cd2cf`, so explicit project flags remain mandatory. A rules/App Check API request initially required a per-request quota-project header; the request was retried with `X-Goog-User-Project: resqme-943ee`. No local gcloud quota setting or hosted configuration was changed.

| Area | Fresh result |
|---|---|
| Project and database | Project ID `resqme-943ee`, number `519076598217`, state `ACTIVE`. Firestore `(default)` is Native mode in `nam5`. Default Storage bucket is `resqme-943ee.firebasestorage.app`, location `US-EAST1`. |
| Firestore Rules | Active release `projects/resqme-943ee/releases/cloud.firestore`, ruleset `aa4be7e8-ce25-44d1-afd8-c10654658bab`, update time `2026-11-06T10:04:54Z`. Retrieved source still denies all reads and writes. No document was read. |
| Storage Rules | Active release `projects/resqme-943ee/releases/firebase.storage/resqme-943ee.firebasestorage.app`, ruleset `f0786fa3-4195-4c87-93ed-bde65612a8c0`, update time `2026-11-08T12:34:36Z`. Retrieved source still denies all reads and writes. No object was listed or read. |
| APIs | At this snapshot, Cloud Functions, Firestore/Datastore, Identity Toolkit, Firebase App Check, Firebase Storage, Cloud Logging, and Service Usage were enabled. Cloud Build (`cloudbuild.googleapis.com`), Artifact Registry (`artifactregistry.googleapis.com`), and Cloud Run (`run.googleapis.com`) were disabled/not listed. No API had yet been changed. |
| Operator IAM | The active gcloud account matches the project's `roles/owner` binding. Read-only `testIamPermissions` returned true for Functions create/update, Cloud Build create, Artifact Registry upload, Cloud Run create/update, `iam.serviceAccounts.actAs`, `serviceusage.services.use`, project get, and Rules/App Check metadata reads. These permissions are broad Owner access, not a least-privilege deployment design. |
| Service accounts | At this pre-Checkpoint A snapshot, two user-managed accounts were listed: App Engine default and Firebase Admin SDK. The App Engine default had project `roles/editor`; Firebase Admin SDK had its existing Auth/App Check, token-creator, Storage Admin and SDK-agent bindings. No deployed Function existed to identify its runtime identity. A Cloud Build default executor was not yet observed; later post-approval identity findings are recorded separately. |
| Functions | Fresh `gcloud functions list --project=resqme-943ee` returned `[]`; no name, generation, runtime, region, revision, or invoker metadata exists. No Function was invoked. |
| App Check provider config | Four registered apps were listed (Android, iOS, and two Web apps). Provider configuration resources are present: Android Play Integrity (minimum device recognition `NO_INTEGRITY`); iOS App Attest and DeviceCheck; each Web app has reCAPTCHA v3 and reCAPTCHA Enterprise configuration. Provider reads used response field masks that omitted private keys and secret values; configuration validity/completeness was not assessed. No debug-token endpoint or token was queried. |
| App Check enforcement | `firestore.googleapis.com`, `firebasestorage.googleapis.com`, `identitytoolkit.googleapis.com`, and `oauth2.googleapis.com` all report `UNENFORCED`. Callable enforcement cannot be confirmed from hosted Function metadata because no Functions are deployed; local callable options omit `enforceAppCheck`. Provider configuration is not proof of working client attestation. |
| Billing | Billing is enabled. No billing configuration was changed; no billing-account identifier is included in this report. |

### Node 22 and package check

After the hosted metadata recheck, separate owner authorization enabled a fresh local Node 22 download. The official Node.js v22.23.4 Windows x64 archive SHA-256 matched both the published Node `SHASUMS256.txt` and the authorized expected value: `cbc74b5e0982c9dbb41525fd8fb5dcd32fbee237863f7829072f4639a1ce5f20`. Runtime was Node `v22.23.4`, npm `10.9.9`; system Node remained `v24.18.0`.

| Exact command and environment | Exit/result |
|---|---|
| From `functions/`, `npm.cmd test` (Node 22 first on `PATH`) | Exit **0**; build passed and configured suite **64 passed, 0 failed, 0 skipped**. |
| From repository root, `firebase.cmd emulators:exec --config firebase.integration.node22.tmp.json --project demo-resqme --only auth,firestore,functions "npm.cmd --prefix functions run test:integration"`; demo project and isolated loopback ports (Auth 19099, Firestore 18080, Functions 15001) | Exit **0**; **10 passed, 0 failed**. |
| `firebase.cmd emulators:exec --config firebase.rules.node22.tmp.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules"`; checked-in Rules on Firestore 18180/websocket 19115 | Exit **0**; **4 passed, 0 failed**. |
| First deny-all attempt: `firebase.cmd emulators:exec --config firebase.integration.node22.tmp.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules:contained"` | Exit **1** before tests due to a test-owned emulator child still occupying 18080/19015; no unrelated process was interrupted. |
| Retry: `firebase.cmd emulators:exec --config firebase.rules.node22.tmp.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules:contained"`; deny-all fixture on 18280/websocket 19280 | Exit **0**; **2 passed, 0 failed**. |

Temporary emulator configs and the isolated Node runtime were removed after verification. The original 11-entry candidate was refined into a 10-entry package with only the three approved callable exports. Its SHA-256 is `099cc7aa1caec651ae6d8509ac0d79cc17aabfe9adbf464307e1a454e6b3b5ef`; the exact list, preserved dependency lock, internal dependency closure, and export check are documented in the package section below.

## Post-approval API enablement and read-only IAM/package verification (2026-11-08 ~23:46 +08:00)

Before mutation, `gcloud projects describe resqme-943ee --format="value(projectId,projectNumber)"` returned `resqme-943ee 519076598217`. The three specifically approved APIs were each `DISABLED_OR_NOT_LISTED`; `cloudfunctions.googleapis.com` was enabled. The only mutation command was:

```powershell
gcloud.cmd services enable cloudbuild.googleapis.com artifactregistry.googleapis.com run.googleapis.com --project=resqme-943ee
```

It completed successfully. Post-checks reconfirmed project ID/number and all four APIs enabled. No extra API was explicitly requested. A complete pre-change API inventory was not retained, so this check does not claim that every unrelated API's state was compared.

The user-managed service-account list changed from two entries to three:

| Identity | Observed state / role |
|---|---|
| `resqme-943ee@appspot.gserviceaccount.com` | Existing App Engine default; project `roles/editor`. |
| `firebase-adminsdk-fbsvc@resqme-943ee.iam.gserviceaccount.com` | Existing Firebase Admin SDK account; retains existing Firebase Auth/App Check, Storage Admin, token-creator, and SDK-agent bindings. Not selected as a Functions runtime. |
| `519076598217-compute@developer.gserviceaccount.com` | Newly listed after API enablement; project `roles/editor`. `gcloud builds get-default-service-account --project=resqme-943ee` identifies it as the current Cloud Build default execution identity. No one manually created it. This broad identity is not acceptable as the proposed least-privilege Functions runtime or build identity without separate review. |

The post-change project IAM policy contains `roles/cloudbuild.serviceAgent` for `service-519076598217@gcp-sa-cloudbuild.iam.gserviceaccount.com`, `roles/run.serviceAgent` for `service-519076598217@serverless-robot-prod.iam.gserviceaccount.com`, and the Cloud Functions service-agent binding. It also contains `roles/cloudbuild.builds.builder` for the legacy `519076598217@cloudbuild.gserviceaccount.com`; that is not the identity returned by `get-default-service-account`. An Artifact Registry service-agent account `service-519076598217@gcp-sa-artifactregistry.iam.gserviceaccount.com` was not found by read-only `describe`. Attempts to inspect the Cloud Build and Cloud Run Google-managed service-account resources directly returned `PERMISSION_DENIED` for `iam.serviceAccounts.get`; their project-policy service-agent bindings are visible, but their detailed metadata could not be verified. No additional permission was sought or granted.

The installed Firebase CLI is version `15.34.1`. Its `prepareFunctionsUpload` implementation packages files recursively from the configured Functions source directory, honoring `functions.ignore` or the default `node_modules`/`.git` ignores plus generated debug/runtime-config exclusions; it does not deploy the manually prepared outer candidate ZIP as-is. The exact candidate ZIP was extracted into a temporary isolated directory and passed to that installed CLI packager without invoking `firebase deploy` or any hosted business operation. The resulting Firebase CLI-prepared upload source:

- contains exactly 9 entries: `package.json`, `package-lock.json`, and the 7 approved compiled runtime modules;
- excludes the root `firebase.json` (outside the Functions source directory), tests, private tools, credentials, data, Rules, and dev dependencies;
- loaded with exactly `createStudentRegistration`, `getMyStudentProfile`, and `ensureMyTier1Qr`; package engine is Node 22;
- has Firebase CLI source hash `10fc53f2e0cd282327385b9e8abebb341079f6c8` and prepared upload ZIP SHA-256 `ea6d181fa604a70e007bc75a00c873a81456c030396c1aa601a136f9500a3927`.

The reviewed upload archive is [the Firebase CLI-prepared Functions payload](../../../../../.copilot/session-state/d811cfa2-9a8b-416a-8b2c-15b13cf9e996/files/resqme-g4-functions-cli-upload.zip). Future deployment must extract the separately hashed minimal candidate into an isolated source directory and run the CLI there with the exact three-function `--only` selector; the CLI will regenerate its upload archive from those same files. No `deploy --dry-run` was used because Firebase documents that a dry-run may still enable APIs. No actual deployment occurred.

The candidate does not configure a Function runtime service account. Firebase CLI 15.34.1 carries runtime `serviceAccount` from discovered function options but has no build-service-account field in its Functions deployment path. The current Cloud Build default is `519076598217-compute@developer.gserviceaccount.com` with project `roles/editor`; no Functions build has run to expose per-build metadata. Separately, installed Google Cloud CLI 575.0.1 supports `gcloud functions deploy --gen2 --build-service-account ...` and `--service-account ...`; Google documents the build-account flag for source deployments and requires `roles/run.builder` on that builder. This is a supported Gen 2 source-deploy route, but the reviewed Firebase CLI ZIP and callable behavior have not been revalidated through it. The Firebase CLI candidate itself has no runtime identity override, so using a dedicated runtime with that exact candidate requires a source/package option change and fresh tests/hashes.

### Read-only IAM preparation checkpoint

| Requirement | Exact current principal / role / scope | Exact proposed role or permission / scope (not applied) | Purpose, risk, verification, and recovery |
|---|---|---|---|
| Deployment operator | `user:dev.guntang@gmail.com`; project `roles/owner`. Prior `testIamPermissions` confirmed broad deployment/build/service-usage access. | Candidate baseline: project `roles/cloudfunctions.developer` and `roles/serviceusage.serviceUsageConsumer`; `roles/iam.serviceAccountUser` on the dedicated runtime identity and, for dedicated-build strategy, the build identity. For the three callable Functions, Firebase CLI 15.34.1 sets each Cloud Run service's invoker policy and requires `run.services.setIamPolicy`; propose only that permission in a project custom role, not `cloudfunctions.functions.setIamPolicy` (the CLI preflight checks that for plain HTTPS endpoints, not callable triggers). | Enables create/update and callable per-service invoker setup. Owner remains excessive. Confirm role contents, project/service IAM bindings, and `testIamPermissions` before any authorized change. Export prior IAM policy; remove only approved new bindings for recovery. |
| Cloud Build executor — Firebase CLI-compatible option | `519076598217-compute@developer.gserviceaccount.com`; project default from `gcloud builds get-default-service-account --project=resqme-943ee`; project `roles/editor`. Legacy Cloud Build account is not selected. | For the existing Firebase CLI path, replace project `roles/editor` with project `roles/run.builder` on the same principal. Google source-build guidance specifies `roles/run.builder` for the Cloud Build service account; no `roles/cloudbuild.builds.builder` addition is proposed. Do not change until other uses of the Compute default are identified. | Least deployment-tool/artifact change and preserves verified Firebase CLI packaging. `roles/run.builder` includes Artifact Registry upload/download/delete, log write, source-repo read, and storage-object read. Removing Editor may break any other workload using this shared account; no project-wide identity-use inventory was performed. Verify existing bindings and workload identity references before an approved change; verify the build identity afterward. Recovery: restore only the recorded Editor binding with owner approval. |
| Cloud Build executor — dedicated-account alternative | Current Compute default remains project `roles/editor`. | Proposed `resqme-functions-build@resqme-943ee.iam.gserviceaccount.com` (availability not checked; creation not authorized): project `roles/run.builder`; deploy operator gets `roles/iam.serviceAccountUser` on this account only. The installed gcloud 575.0.1 supports `gcloud functions deploy --gen2 --build-service-account projects/resqme-943ee/serviceAccounts/resqme-functions-build@resqme-943ee.iam.gserviceaccount.com`. | Avoids changing the current default and potential users of it. This is supported Gen 2 source deployment but not Firebase CLI 15.34.1; the reviewed CLI-prepared artifact and callable behavior require fresh validation for the alternative path. `roles/run.builder` permits project-level artifact upload/download/delete. Verify actual `buildConfig.serviceAccount` and build metadata only after separate deployment approval. Recovery: restore the deployment command and remove the approved role binding after confirming no build uses the identity; retain the account unless separately approved for deletion. |
| Functions runtime | No Functions are deployed. Compute and App Engine defaults each have project `roles/editor`; Firebase Admin SDK account has unrelated Auth/App Check/Storage privileges. Candidate sets no runtime account. | Proposed `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` (availability not checked; creation not authorized), with a project custom role containing exactly `datastore.databases.get`, `datastore.entities.get`, `datastore.entities.create`; deploy operator gets `roles/iam.serviceAccountUser` on this account only. | Exact operation trace: registration transaction `tx.get(profile)` and `tx.create(profile)`, `tx.create(acknowledgment)`; profile callable direct `.get()`; QR transaction `tx.get(profile)`, `tx.get(credential)`, `tx.create(credential)`, then direct credential `.get()`. Firestore maps transaction begin/rollback to `datastore.databases.get`, reads to `datastore.entities.get`, and create-only commits to `datastore.entities.create`. No current path updates, deletes, or lists documents. Project scope permits read/create across the project; Admin SDK bypasses Rules. Verify against the official method-permission mapping and then verify runtime identity/approved acceptance tests. Recovery: remove only an approved role binding after no Function uses it; do not delete data/account as rollback. |
| Google-managed service agents | Project IAM shows Cloud Functions `service-519076598217@gcf-admin-robot.iam.gserviceaccount.com` / `roles/cloudfunctions.standardServiceAgent`, Cloud Build `service-519076598217@gcp-sa-cloudbuild.iam.gserviceaccount.com` / `roles/cloudbuild.serviceAgent`, and Cloud Run `service-519076598217@serverless-robot-prod.iam.gserviceaccount.com` / `roles/run.serviceAgent`. Artifact Registry agent was not found. | No manual roles or identity creation proposed. Preserve Google-managed bindings; do not infer missing metadata from a denied read. | Cloud Build/Run service-account descriptions returned `PERMISSION_DENIED` for `iam.serviceAccounts.get`; only project-policy bindings were verified. If an exact service-agent prerequisite is later reported, stop and request an authorized administrator's read-only confirmation. No rollback action is indicated absent an approved change. |
| Callable invocation | No deployed service; no existing per-service invoker policy to inspect. | Firebase CLI 15.34.1's callable release path sets `roles/run.invoker` for `allUsers` on each generated Cloud Run service. This is a per-service policy, not a project-level grant, and is the expected transport policy for Firebase client callables. | Infrastructure IAM allows network invocation, but the callable handler must still validate Firebase Auth; profile ownership remains UID-derived. Public reachability increases abuse/cost exposure, and App Check is unenforced. Verify all three service policies after a separately approved deployment. Recovery: remove only the exact per-service binding with owner approval; doing so blocks callable clients. No policy is authorized now. |

#### Firestore operation-to-permission trace

| Function | Admin SDK operation | Required Firestore IAM permission |
|---|---|---|
| `createStudentRegistration` | `runTransaction` begin/rollback | `datastore.databases.get` |
| `createStudentRegistration` | `tx.get(profile)` and final `profile.get()` | `datastore.entities.get` |
| `createStudentRegistration` | `tx.create(profile)` and `tx.create(acknowledgment)` | `datastore.entities.create` |
| `getMyStudentProfile` | `studentProfiles/{auth.uid}.get()` | `datastore.entities.get` |
| `ensureMyTier1Qr` | `runTransaction` begin/rollback | `datastore.databases.get` |
| `ensureMyTier1Qr` | `tx.get(profile)`, `tx.get(credential)`, and final `credential.get()` | `datastore.entities.get` |
| `ensureMyTier1Qr` | `tx.create(credential)` | `datastore.entities.create` |

Firestore documents `beginTransaction` and `rollback` as requiring `datastore.databases.get`; document reads require `datastore.entities.get`; a commit/create with an `exists:false` precondition requires `datastore.entities.create`. The handlers use `tx.create`, not update-capable `set`/`update`; none of the approved paths lists or deletes documents. Thus the proposed runtime custom role is exactly those three permissions, at project scope. It limits operation types, not document paths: Admin SDK calls bypass Firestore Rules, so a compromised runtime identity could read or create any documents allowed by those permissions. Official source: [Firestore server-client IAM method requirements](https://cloud.google.com/firestore/docs/security/iam).

#### Build-identity strategy comparison and recommendation

| Strategy | Exact principal and proposed grant | Compatibility and workload impact | Verification / recovery |
|---|---|---|---|
| 1 — Keep Firebase CLI 15.34.1; narrow its current default | Existing `519076598217-compute@developer.gserviceaccount.com`: remove project `roles/editor`; grant project `roles/run.builder`. Runtime must use the separate Firestore-limited runtime account. | Preserves the already reviewed Firebase CLI source packaging and `--only` deployment scope; CLI has no per-deployment build-account option. However, the Compute account is shared project identity. Removing Editor may break other builds or workloads using it; their use was not inventoried. `roles/run.builder` is the documented source-build role and itself grants Artifact Registry upload/download/delete plus build logging/source access. | Before any mutation, perform a read-only identity-use inventory and capture exact policy; after approved change, check bindings and a canary build. Recovery is an owner-approved restoration of the recorded Editor binding. |
| 2 — Dedicated build identity via Google Cloud CLI | Proposed new `resqme-functions-build@resqme-943ee.iam.gserviceaccount.com`: project `roles/run.builder`; deployer gets `roles/iam.serviceAccountUser` on that account. The installed Google Cloud CLI 575.0.1 supports `gcloud functions deploy --gen2 --build-service-account projects/resqme-943ee/serviceAccounts/{account}`; official source-deployment guidance confirms the flag and required `roles/run.builder`. | Avoids changing the current Compute default or affecting workloads that may use it, but switches away from Firebase CLI and the already reviewed CLI-prepared artifact. The three entry points, callable/Auth behavior, source packaging, invoker binding, and exact package hash must be revalidated for this route. Account availability and Cloud Build build metadata have not been checked. | Verify the flag locally (done), official requirements, selected build SA in deployed `buildConfig`, and build logs after separate deployment approval. Preserve existing default policy; recovery is to revert to the prior deployment path and remove only the approved new role binding when unused. |

**Recommendation:** For the already reviewed Firebase CLI artifact, Strategy 1 is the smallest deployment-path change, but it is **not safe to apply yet** because dependencies on the shared Compute account are unknown. Do not remove its Editor binding until an authorized read-only workload-reference inventory establishes impact. Strategy 2 has lower cross-workload IAM impact, but is not compatible with the exact Firebase CLI upload artifact and requires a fresh local package/callable verification before it can be approved. No build identity change is authorized by this report.

**Role-evaluation evidence:** `roles/cloudfunctions.developer` includes create/update permissions for Functions and Run services but not `run.services.setIamPolicy`; `roles/cloudfunctions.admin` includes policy permissions but is broader. Firebase CLI `checkHttpIam` preflights `cloudfunctions.functions.setIamPolicy` for plain HTTPS-trigger functions, but callable triggers use the separate `run.services.setIamPolicy` path. `roles/serviceusage.serviceUsageConsumer` includes `serviceusage.services.use`; `roles/iam.serviceAccountUser` includes `iam.serviceAccounts.actAs`. `roles/run.builder` includes `artifactregistry.repositories.uploadArtifacts`, `downloadArtifacts`, `deleteArtifacts`, `logging.logEntries.create`, `source.repos.get`, and `storage.objects.get`. The Firestore `roles/datastore.user` predefined role includes broad `datastore.entities.*`; the narrower three-permission custom role above follows the documented Firestore API method permissions. These role contents were inspected read-only with `gcloud iam roles describe`; none has been granted. Official references: [Cloud Functions IAM roles](https://cloud.google.com/functions/docs/reference/iam/roles), [Firestore server-client IAM permissions](https://cloud.google.com/firestore/docs/security/iam), [Cloud Run source build service account](https://cloud.google.com/run/docs/configuring/services/build-service-account), and [Cloud Build user-managed service accounts](https://cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts).

The operator still has project Owner; the build default has project Editor; no service-agent description was verified. The exact role proposals are documented, but no mutation is safe to approve until the owner selects the build strategy. The Firebase CLI-compatible option is to reduce the current default to `roles/run.builder`, contingent on a read-only audit of all other uses of the shared Compute identity. The dedicated-build option uses the supported gcloud source-deployment flag and avoids modifying the existing default, but requires fresh local package/callable validation. A dedicated runtime identity is proposed with only the three traced Firestore permissions. No IAM mutation or service-account creation is authorized.

## API, IAM, App Check, runtime and billing requirements

**APIs.** Application-level dependencies are Firebase Authentication (Identity Toolkit) for client email/password account creation/sign-in, Firestore for client/Admin SDK reads/writes, and Cloud Functions for callables. Current read-only inventory confirms Identity Toolkit, Firestore, Cloud Functions, Cloud Build, Artifact Registry, Cloud Run, and Cloud Logging enabled. Cloud Build, Artifact Registry, and Cloud Run were enabled under Checkpoint A; no API was explicitly enabled beyond those three. Eventarc is not used by these callable-only handlers. Other enabled products do not imply application use.

**IAM.** The final Checkpoint B proposal is in the read-only matrix above and the G4 manifest. The active deployer remains project Owner. The Cloud Build default is the Compute account with project Editor; no Functions build has run to expose actual build metadata, and no Functions exist to reveal runtime/invoker settings. Firebase CLI 15.34.1's callable release path sets the Cloud Run invoker policy per service via `run.services.setIamPolicy`; the CLI's separate `cloudfunctions.functions.setIamPolicy` preflight is for plain HTTPS triggers, not the callable trigger type used here. Google Cloud CLI 575.0.1 supports a dedicated build account through `gcloud functions deploy --gen2 --build-service-account`; official source-build guidance specifies `roles/run.builder`. The Firebase CLI-compatible role reduction is conditional on a read-only audit of workloads using the shared Compute account. Runtime least privilege is mapped to three Firestore permissions. Cloud Build/Run service-agent metadata reads remain denied, with project bindings visible. No IAM changed.

**App Check.** The fresh provider-config reads found Android Play Integrity, iOS App Attest and DeviceCheck, and both reCAPTCHA v3 and reCAPTCHA Enterprise configurations for each of the two web apps. Reads used field masks that excluded private keys/secrets; no debug-token endpoint or token value was requested. The Firestore, Storage, Identity Toolkit, and OAuth service configurations all report `UNENFORCED`. Flutter still has no App Check initialization, callable handlers do not set `enforceAppCheck`, and no Functions are deployed. Configured provider resources do not demonstrate that a client can obtain or send valid tokens. Provider registration, debug-token handling, and enforcement changes each require separate approval.

**Node and billing.** Node.js 22 is a supported Cloud Functions/Run-functions runtime; official runtime dates currently list deprecation 2027-04-30 and decommission 2027-10-31. The system Node remains 24.18.0; isolated official Node 22.23.4 passed the Functions build/configured suite, registration/onboarding emulator integration and Rules tests. Billing metadata confirms billing is enabled for staging. A deployment can incur Cloud Build, Artifact Registry, Cloud Run/Functions invocation and Firestore usage charges. No usage estimate is possible from this review, and no billing change is authorized.

## Regression results for the approved local implementation

The latest backend verification ran with isolated Node `v22.23.4` / npm `10.9.9` and is detailed in the current-source Node 22 section above. Prior implementation checks also used Node `v24.18.0`, Flutter `3.44.4`, Dart `3.12.2`, Firebase CLI `15.34.1`, and Java `21.0.10`. The hosted metadata preflight and package refinement changed no application source, dependency versions, or Firebase configuration.

| Validation | Result |
|---|---|
| Current-source Node 22 Functions build/configured suite | Exit 0; **64/64** passed. |
| Current-source demo Auth/Firestore/Functions emulator integration | Exit 0; **10/10** passed. |
| Checked-in Firestore Rules emulator suite | Exit 0; **4/4** passed. |
| Deny-all Rules containment emulator suite | Exit 0 after retry on fresh ports; **2/2** passed. |
| `flutter analyze` | Exit 0; no issues found. |
| `flutter test test\features\registration test\features\qr` | Exit 0; **50/50** passed. |
| `git diff --check` | Passed after the current documentation updates. |

Fresh mobile regression checks from the implementation verification:

| Command | Result |
| --- | --- |
| `flutter analyze` | Exit 0; no issues found. |
| `flutter test test\\features\\registration test\\features\\qr` | Exit 0; **49 passed**. |

**Coverage limit:** The registration callable integration case uses anonymous Auth; onboarding integration pre-creates synthetic Auth users with the Admin SDK and then signs in. Flutter repository/widget tests use fakes. The existing suites therefore do not demonstrate the complete Flutter email/password account-creation → callable → profile-read path against Auth/Firestore emulators. This remains an explicit future acceptance item and was not inferred from callable tests.

## Historical G4 deployment proposal — superseded; do not execute

The proposal in this section predates the approved profile callable and the current package candidate. Its Function list, source identity, packaging assessment, and Node 22 status are stale. The separate [current proposed G4 deployment manifest](./resqme-g3-proposed-g4-deployment-manifest.md) supersedes it and remains unauthorized.

**Minimal function scope for a registration → skip medical → QR path:**

| Item | Proposed value |
| --- | --- |
| Firebase project | `resqme-943ee` only |
| Functions | `createStudentRegistration`, `ensureMyTier1Qr` only, after read-only inventory confirms absent/incompatible. Existing compatible Functions must not be needlessly redeployed. |
| Generation/trigger | Cloud Functions 2nd gen, HTTPS callable (`onCall`); Firebase Auth required by each handler. |
| Region/runtime | `us-central1` (client selects it; backend uses the default region); `nodejs22`. |
| Required data/config | Firestore paths in the Function map; no user-supplied secrets or runtime parameters. Current project/SDK identity only. |
| Firestore Rules / Storage Rules | **No Rules deployment or change.** No `firestore:rules`, `storage`, Hosting, indexes, Auth provider, IAM, API enablement, or QA entitlement in the command. |
| Excluded Functions | Medical `saveMySyntheticMedicalRecord` and `clearMySyntheticMedicalRecord` are not needed if the synthetic user skips the medical step; include only under separately approved scope for medical-save testing. |

Candidate command for a later separately approved deployment, **not run**:

```powershell
firebase.cmd deploy --project resqme-943ee --only functions:createStudentRegistration,functions:ensureMyTier1Qr
```

### Source and artifact identity

- Local source revision: `47fd30e` (`origin/main` is one commit behind). Deployment must not use the stale remote `main`.
- Current Functions dependency lock SHA-256: `764C85F94A2EF3E1C081465D65A0639D2EF739729FFEED7698C6C4D4220FD705`.
- Locked package versions include `firebase-admin@14.5.0`, `firebase-functions@7.4.0`, `google-auth-library@11.3.1`, and TypeScript `5.9.3`.
- Current uncommitted `functions/package.json` SHA-256: `433B5C71DA3A0CB0D1839ABA9CBB5708CEE7277A38CAF765D8E4E8BD883A8BAC`; change is to test scripts, not runtime dependencies.
- Local Node 24 build outputs: `functions/lib/src/index.js` SHA-256 `95B95967E17DA9E70CFB464DF29BB7B0BA70CEAE8A504E1F401DB245FB044CA4`; registration module `3AB4A8F27A2D6BC9A6FEE1F8FC902EDFA4453223689BDA4426EA449CC40A093B`; QR module `E1DA7AB79A816EFEE132545D970F21D7D70361AFE894B9FFEF6B213B83E8B5D6`.
- These are local input/module hashes, **not** a final deployment-archive digest; no release archive was created.
- Packaging blocker: `functions/tsconfig.json` compiles `src`, `test`, and `tools`. `firebase.json` has no Functions `ignore` list and no `.firebaseignore` is present. The installed Firebase CLI packages the whole Functions directory and defaults to ignoring only `node_modules` and `.git` (plus its generated debug/runtime-config files). Therefore current untracked `functions/test` and `functions/tools`, including local inventory tooling, would be included in the upload source. Do not deploy from this dirty tree as-is. A separately approved, scope-limited package filter/build must be reviewed, then its exact archive hashed and Node 22-tested; preserve the owner files.

### Required predeployment and verification steps

1. Obtain separate owner approval before enabling Cloud Build, Artifact Registry, Cloud Run, or making any IAM change. The Cloud Functions API is already enabled. After resolving the current blockers, any further inventory or identity checks must remain read-only and must not read application data or invoke Functions.
2. Obtain an owner decision on the deny-all/profile-read incompatibility. Preserve deny-all unless a specific alternative is approved; do not silently relax Rules or add a code workaround.
3. Run build and relevant tests in an available isolated Node 22 environment. Prepare a reviewed filtered Functions package and archive digest; exclude tests, local inventory tools and secrets while preserving owner files.
4. Present the exact API/IAM side effects, Function create/update plan, invoker policy, App Check posture, source/compiled artifact, deployment diff, billing implications, rollback artifact and verification plan for explicit G4 approval.
5. Only after separate G4 approval, deploy individually approved Functions and verify their names, generation, region, runtime, revision and invoker metadata. Hosted account creation, Function invocation, QR persistence, cross-user checks and cleanup each require separate synthetic-only test authorization.

Rollback requires a captured known-good prior Function artifact/revision and explicit authorization to redeploy it. Do not delete Functions, Auth accounts, Firestore documents, or QR references as implicit rollback steps. No cost estimate or exact hosted artifact version can be finalized until current APIs/plan and the final source archive are verified.

## Exact files/resources inspected

- Config/Rules: `.firebaserc`, `firebase.json`, `firebase.integration.json`, `firestore.rules`, `firestore.indexes.json`, `pubspec.yaml`, `pubspec.lock`, `lib/firebase_options.dart`; no local Storage Rules file found.
- Functions: `functions/package.json`, `functions/package-lock.json`, `functions/tsconfig.json`, `functions/src/index.ts`, `functions/src/registration/create_student_registration.ts`, `functions/src/registration/registration_contract.ts`, `functions/src/qr/ensure_my_tier1_qr.ts`, `functions/src/medical/save_synthetic_medical_record.ts`, `functions/src/onboarding/authorization.ts`, and the registration, QR, emulator-config, onboarding-integration, registration-integration, and Rules test files.
- Flutter: `lib/main.dart`, `lib/app/resqme_app.dart`, `lib/core/config/app_environment.dart`, `lib/core/config/firebase_environment.dart`, `lib/core/data/pilot_client.dart`, registration repository/model/screen/access-gate files, and QR repository/screen/parser/scanner files.
- Existing readiness sources: `docs/resqme-staging-security-readiness-review.md`, `docs/resqme-staging-deployment-manifest.md`, `docs/resqme-g2-owner-attested-empty-baseline-review.md`, `docs/resqme-hosted-inventory-approval-checkpoint.md`.
- Local tool evidence: Firebase CLI 15.34.1 Functions prepare/upload behavior. Official references: [Cloud Functions runtime support](https://docs.cloud.google.com/functions/docs/runtime-support), [Cloud Run functions deployment APIs and IAM](https://docs.cloud.google.com/run/docs/deploy-functions), [Firestore server-library IAM](https://docs.cloud.google.com/firestore/docs/security/iam), [Callable Functions](https://firebase.google.com/docs/functions/callable), [Flutter App Check setup](https://firebase.google.com/docs/app-check/flutter/default-providers), [Cloud Functions App Check enforcement](https://firebase.google.com/docs/app-check/cloud-functions), and [Functions regions](https://firebase.google.com/docs/functions/locations).

## Final local implementation and verification

### Confirmed incompatibility and correction

Registration creates the Firebase Authentication account and writes `studentProfiles/{uid}` with the Admin SDK. Before this correction, the Flutter registration repository then directly read that document; the last authorized hosted Rules inventory found both Firestore and Storage client access denied, making that read incompatible with the deployed Firestore policy. This local correction leaves Rules untouched and moves the read to an authenticated callable. The callable rejects non-empty request data, derives the sole document path from `request.auth.uid`, reads only that profile, rejects missing/malformed required data, and constructs a response from the owner-approved allowlist. It does not expose the full document. The existing `ensureMyTier1Qr` callable and registration schema were not changed.

### Approved profile response contract

| Response field | Contract |
|---|---|
| `schemaVersion`, `fullName`, `ageYearsAtRegistration`, `status` | Required and validated under the existing profile contract. |
| `gender`, `personalContactNumber` | Optional; included only when present and a string or `null` as accepted by the existing model. |
| `emergencyContacts.primary.fullName`, `.relationship`, `.phoneNumber` | Each optional; included only when present and valid. |
| `emergencyContacts.secondary.fullName`, `.phoneNumber` | Each optional; included only when present and valid. |

The response contains no nickname, LRN, medical data, acknowledgments, QR credentials, internal metadata, or unrecognized top-level or nested fields. My Profile continues using the existing name/QR presentation; the registration-details review panel retains the fields required by its existing model and flow.

### Focused files in this implementation

- Backend: `functions/src/profile/get_my_student_profile.ts` (new), `functions/src/index.ts`.
- Flutter: `lib/features/registration/services/firebase_student_registration_repository.dart`.
- Functions tests: `functions/test/get_my_student_profile.test.ts` (new), `functions/test/profile_integration.test.ts` (new), `functions/test/deny_all_rules.test.ts` (new), and the Functions test selectors in `functions/package.json`.
- Emulator port isolation: `functions/test/emulator_config.ts` and `functions/test/emulator_config.test.ts`.
- Flutter regression: `test/features/registration/firebase_student_registration_repository_test.dart`.
- Readiness artifacts: this report and [the proposed G4 manifest](./resqme-g3-proposed-g4-deployment-manifest.md).

No Firestore/Storage Rules, App Check configuration, QR callable, Tier 2/medical authorization, registration schema, hosted resource, or unrelated owner file was intentionally changed. The temporary emulator config was removed after testing. No commit or push was made.

### Fresh local validation evidence

Node `24.18.0` / npm `12.0.2` were available; Node 22 was not. All emulator work used synthetic `demo-resqme` resources on isolated loopback ports—Auth `19099`, Firestore `18080` (websocket `19015`), Functions `15001`—and did not connect to hosted Firebase. The temporary emulator config was removed after testing.

| Command | Result |
|---|---|
| `npm.cmd --prefix functions run build`; `npm.cmd --prefix functions test` | Passed; **64/64** configured Functions tests. |
| `firebase.cmd emulators:exec --config firebase.integration.local.json --project demo-resqme --only auth,firestore,functions "npm.cmd --prefix functions run test:integration"` | Passed; **10/10**, including authenticated profile retrieval, strict input, foreign-UID attempt, allowlist filtering, missing/malformed profiles, and existing persistent/repeated QR behavior. |
| `firebase.cmd emulators:exec --config firebase.integration.local.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules:contained"` | Passed; **2/2** authenticated/unauthenticated direct access denials using the deny-all containment fixture. |
| `firebase.cmd emulators:exec --config firebase.integration.local.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules"` | Passed; **4/4**. This verifies the checked-in owner-read Rules, not the hosted deny-all Rules. |
| `flutter analyze` | Passed; no issues reported. |
| `flutter test test\features\registration test\features\qr` | Passed; **50/50**. |
| Current-source Node 22 verification | **Not run**. The previously approved temporary runtime was removed; repeat downloads were prohibited. Do not treat the prior pre-change Node 22 results as current-source proof. |
| Full Flutter email/password → emulator account creation → callable profile load | **Not covered end-to-end** by the available harness; callable emulator coverage and Flutter fake-based tests do not establish this combined path. |
| `git diff --check` | Repeated after the final documentation update below. |

Local Storage Rules regression was not run because no local Storage Rules fixture/suite exists. The last hosted inventory reported Storage Rules deny-all; no Storage Rules change was made. No hosted test, Function deployment/invocation, account creation, or application-data access occurred.

The requested focused independent code review found no significant code issues. It flagged stale pre-correction profile-read conclusions in this report; those statements and the Function map were reconciled to distinguish the historical direct-read bug from the current, undeployed local callable.

### App Check readiness

Flutter App Check initialization is absent and callable enforcement remains disabled. No debug token or provider was added, no enforcement was enabled, and no hosted App Check setting changed. The callable endpoint is publicly invokable at the Cloud Run IAM layer, so unenforced App Check provides no proof that a request comes from the intended ResQMe app/device. Firebase Auth and server-derived UID ownership still reject unauthenticated business access and cross-user profile reads, but a caller with a valid Firebase account can automate registration/QR calls, abuse endpoints, and increase Functions/Firestore usage and cost. Before any debug-only Android pilot, separately approve SDK initialization with a debug provider restricted to the debug build, keep the token out of logs/source control, and register it only through the approved staging process. Test registration/profile/QR with the approved debug token before considering enforcement. Release/profile builds must not inherit the debug provider; any production attestation or enforcement is a separate decision.

### Package candidate

A minimal candidate was prepared outside the repository from the current Node 22-compiled runtime modules. Its entrypoint exposes exactly `createStudentRegistration`, `getMyStudentProfile`, and `ensureMyTier1Qr`. The compiled medical callable module and exports are omitted; the shared `medical_contract.js` remains because profile and QR request validation import its `object`/`keys` helpers. All approved callable dependency modules match the current build byte-for-byte; only the package entrypoint was narrowed. No application source or runtime dependencies changed. The 10-entry archive excludes tests, local tools, `node_modules`, Firestore/Storage Rules, test data, environment files, and credential/key files. It is:

`C:\Users\Mj\.copilot\session-state\d811cfa2-9a8b-416a-8b2c-15b13cf9e996\files\resqme-g4-functions-minimal-candidate.zip`

SHA-256: `099cc7aa1caec651ae6d8509ac0d79cc17aabfe9adbf464307e1a454e6b3b5ef`

The package production dependencies and lock remain unchanged: `firebase-admin@14.5.0`, `firebase-functions@7.4.0`, and `google-auth-library@11.3.1`; the lock contains no development dependencies. The archive's exact file list and digest are recorded in the G4 manifest. Its Node 22 entrypoint load was verified to expose only the approved three exports. It remains a candidate, not an approved release artifact; future deployment must use the matching exact `--only` allowlist and verify the Firebase CLI prepared upload manifest.

The Firebase CLI 15.34.1 upload-preparation function was run locally against an isolated extraction of this candidate. It generated a 9-entry source ZIP (Functions source directory only), with SHA-256 `ea6d181fa604a70e007bc75a00c873a81456c030396c1aa601a136f9500a3927` and Firebase CLI source hash `10fc53f2e0cd282327385b9e8abebb341079f6c8`. The CLI-prepared artifact is [available here](../../../../../.copilot/session-state/d811cfa2-9a8b-416a-8b2c-15b13cf9e996/files/resqme-g4-functions-cli-upload.zip). This verifies CLI source packaging locally; it does not mean Firebase CLI will directly deploy the ZIP as a file. Deploy only from an isolated extraction of the reviewed candidate and verify the generated source hash and entries before any separately authorized deployment.

## Disposition and next approval

Checkpoint A enabled exactly Cloud Build, Artifact Registry, and Cloud Run after project identity verification. This earlier disposition is superseded by the 2026-11-09 Checkpoint 1 execution and verification below. See [the proposed G4 deployment manifest](./resqme-g3-proposed-g4-deployment-manifest.md) for the current package and separate deployment/testing approvals.

## 2026-11-09 — Option A Checkpoint 1 execution and final readiness

The owner selected Firebase CLI with the existing Cloud Build default (`519076598217-compute@developer.gserviceaccount.com`) and explicitly accepted its current project `roles/editor` only as a temporary debug-staging risk. No build-account role was added or removed; this acceptance does not extend to production.

### IAM changes and verification

Checkpoint 1 was explicitly approved. Project identity rechecked as `resqme-943ee` / `519076598217` / `ACTIVE`. The named service account and custom role were absent before execution. Created only:

| Change | Exact proposal | Scope and effect |
|---|---|---|
| Runtime service account | Created `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com`; active; no user-managed key. | Dedicated identity for the three approved callables. |
| Runtime custom role | Created `projects/resqme-943ee/roles/resqmeFunctionsRuntime`, title `ResQMe Functions Runtime`, stage `GA`; exact permissions are `datastore.databases.get`, `datastore.entities.get`, `datastore.entities.create`. | Project scope. Transaction begin/rollback, reads, and create-only writes; no update, delete, list, Storage, or Auth administration permissions. |
| Runtime role binding | Added only `serviceAccount:resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` → `projects/resqme-943ee/roles/resqmeFunctionsRuntime`. | Project scope; Admin SDK bypasses Rules and this permission set reaches documents across the project. Handler Auth/UID checks remain required. |

Before/after project IAM policy comparison found exactly that single new binding, with no removals or unrelated changes. The deployment operator's `iam.serviceAccounts.actAs` on the runtime identity and `run.services.setIamPolicy` on the project both passed read-only IAM `testIamPermissions` calls. The existing operator `roles/owner`, Compute default `roles/editor`, and Google-managed service-agent bindings were preserved. No key was created. API, Rules, Storage, App Check, and application-data configuration was not changed.

### Package, source, and client configuration

- Current nested ResQMe `HEAD`: `47fd30e567c16b19b7fbb91f410c23c19f8a912b`; worktree remains dirty. The deployment artifact hash below, not the commit alone, identifies the exact reviewed input.
- The live source entrypoint also exports `saveMySyntheticMedicalRecord` and `clearMySyntheticMedicalRecord`; do not deploy unrestricted from `resqme/functions`. Only the isolated candidate exports the approved three.
- After Checkpoint 1, the three approved callables were configured with `serviceAccount: resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com`. The medical callable declarations and registration/profile/QR business logic were otherwise unchanged.
- Candidate ZIP SHA-256: `9629f7ba61c7fc10b9446c52f6a406dc0c3ada04956333d4a1bc89b65105e8b4` (10 files). Firebase CLI 15.34.1 upload payload SHA-256: `7b2213ea88b87ca3b292706e454b6c5ffc6792230697f72979adc3fc83cd99d1` (9 Functions-source entries). Firebase CLI source hash: `6706546534eccfd0235779441c941a668afcfd30`. Both artifacts were regenerated after the runtime option update.
- Candidate entrypoint load verified only `createStudentRegistration`, `getMyStudentProfile`, and `ensureMyTier1Qr`; all three endpoint manifests carry the dedicated `serviceAccountEmail`. Candidate is Node `22` / `nodejs22`. The Functions-only config contains no Rules, Storage, indexes, or Hosting sections. Tests, private tools, credentials, application data, `node_modules`, and the compiled medical callable module are absent; `medical_contract.js` remains only as shared validation code. Direct production dependencies and resolved versions match the worktree; development dependencies are excluded.
- Flutter's debug `staging` selection uses project `resqme-943ee` and `us-central1`; emulator endpoints are used only for explicit debug `emulator` mode. Release/profile builds do not initialize this Firebase backend.
- A read-only Identity Toolkit config GET confirmed `projects/519076598217/config` has Email/Password enabled. The initial request needed an `X-Goog-User-Project: resqme-943ee` request header because user ADC has no default quota project; no ADC/project configuration was changed.

### Fresh local verification

The official Node.js v22.23.4 Windows x64 archive SHA-256 was verified as `cbc74b5e0982c9dbb41525fd8fb5dcd32fbee237863f7829072f4639a1ce5f20`, matching the official published checksum and previously approved value. Isolated runtime: Node `v22.23.4`, npm `10.9.9`; system Node was not changed.

| Validation | Fresh result |
|---|---|
| `npm.cmd test` (TypeScript build plus configured Functions suite) | Exit 0; 65/65 tests passed. |
| Auth/Firestore/Functions `demo-resqme` emulator integration (`npm run test:integration`) | Exit 0; 10/10 passed on loopback ports Auth 19099, Firestore 18080, Functions 15001. |
| Checked-in Firestore Rules (`npm run test:rules`) | Exit 0; 4/4 passed against the local emulator. |
| Deny-all containment Rules (`npm run test:rules:contained`) | Exit 0; 2/2 passed against the local emulator. |

The emulator was explicitly pinned to `demo-resqme` and loopback; the 18080 Firestore emulator process left behind at CLI shutdown was identified by its exact command line and stopped by PID. No hosted Auth accounts or application documents were accessed. Firebase CLI emitted its generic warning that ADC exists for any non-emulated services; these tests used only local Auth/Firestore/Functions endpoints. No Flutter code changed, so Flutter tests/analyze were not rerun; historical Flutter results remain historical. Local Rules tests do not freshly verify hosted Rules metadata; the last hosted metadata snapshot reported Firestore and Storage deny-all, and no Rules operation occurred here.

### Readiness and remaining authorization

**G3: GO for the scoped debug-only staging pilot.** APIs are enabled, the selected build identity is owner-accepted for staging, the dedicated runtime identity and exact role are configured, operator permissions are verified, Auth Email/Password is enabled, the exact three-function candidate is rebuilt and tested, and the unenforced App Check risk has been explicitly accepted. Acceptance is limited to synthetic staging; it is not production readiness.

**G4: NOT AUTHORIZED.** No Function deployment, invoker binding, hosted account creation, hosted callable invocation, application-data read/write, Rules change, App Check change, commit, or push occurred. Obtain the two independent authorizations in the final G4 manifest: (A) exactly-three-Function deployment and (B) the separately scoped synthetic Tier 1 acceptance and cleanup. The temporary Compute Editor build identity and unenforced App Check posture remain explicit staging risks; future hardening is required before production.
