# ResQMe G4 Functions Deployment Manifest

> **CURRENT STATUS — G4 hosted backend synthetic acceptance PASS: 29/29 automated checks, exact cleanup verified.** Three approved Functions are deployed and ACTIVE. Full Tier 1 device/UI and offline-scanner acceptance remain NOT RUN. CLI exit 1 is retained as a post-deployment cleanup-policy failure; the owner temporarily accepted the absent policy and approved the recorded API/IAM exceptions. The final execution record below is authoritative; earlier snapshots are historical.

> **Approval boundary:** Authorization A and conditional Authorization B were explicitly granted, including the final scoped exceptions below. The scoped backend session is finished and its synthetic resources are removed. No new deployment, configuration change, replacement-account session, or broader remediation is implied.

## 1. Target and scope

| Item | Proposed value |
|---|---|
| Firebase project | `resqme-943ee` |
| Project number | `519076598217` |
| Functions generation | 2nd generation HTTPS callable |
| Region | `us-central1` |
| Runtime | Node.js 22 (`nodejs22`) |
| Functions to deploy | `createStudentRegistration`, `getMyStudentProfile`, `ensureMyTier1Qr` |
| Functions explicitly excluded | `saveMySyntheticMedicalRecord`, `clearMySyntheticMedicalRecord` |
| Rules, Hosting, Storage, indexes, Auth providers | No deployment or change |

This exact Function allowlist supports registration, authenticated profile loading, and the existing persistent QR flow. It does not include Tier 2 or medical-record behavior. The user-approved profile callable returns the approved compatibility allowlist and derives ownership from Firebase Authentication. The existing QR callable is unchanged.

The fresh owner-approved read-only staging check on 2026-11-08 reconfirmed project `resqme-943ee` / number `519076598217` and returned no deployed Cloud Functions. The last Rules metadata read showed deny-all Firestore and Storage; no Rules operation occurred during API enablement. The gcloud configured default project differs (`mind-mates-cd2cf`); all authorized commands were explicitly pinned to staging. Before deployment, re-confirm the project, Function inventory, Rules, and artifact identity. Stop if the project, existing Function state, region, runtime, or source contract differs from this proposal.

## Latest verified readiness facts (historical snapshot; see final update)

- Cloud Functions, Cloud Build, Artifact Registry, and Cloud Run APIs are enabled. The latter three were enabled only after explicit Checkpoint A approval; see the post-approval verification below.
- The active operator has project-level Owner and corresponding broad permission checks pass; this is not least-privilege readiness. The App Engine default and newly listed Compute default service accounts have project Editor. `gcloud builds get-default-service-account` returns the Compute default as the project's selected Cloud Build default; no Functions build has run to expose per-build identity metadata. Firebase Admin SDK permissions include Firebase Auth/App Check administration, Storage Admin, and service-account token creation. No deployed Functions exist to identify a runtime identity or invoker policy.
- App Check provider configuration resources exist for Android (Play Integrity), iOS (App Attest and DeviceCheck), and both Web apps (reCAPTCHA v3 and Enterprise). Firestore, Storage, Identity Toolkit, and OAuth App Check enforcement report `UNENFORCED`. No debug tokens were read. Flutter App Check initialization and callable enforcement remain absent.
- Official Node `v22.23.4` / npm `10.9.9` was obtained for this approved local run and checksum-verified; current-source Functions and emulator tests passed. The isolated runtime was removed afterward. System Node remains unchanged.

## 2. API and IAM prerequisites

The approved API change has been completed. No other API enablement is authorized by this manifest. Any future API prerequisite requires a separate owner decision after read-only verification.

### Checkpoint A — exact API change proposal

Read-only metadata was rechecked on `resqme-943ee` on 2026-11-08 before and after the approved change. Project ID and number matched the authorized target. Before the operation Cloud Functions was enabled and the three approved deployment APIs were disabled/not listed. The approved command completed successfully:

```powershell
gcloud.cmd services enable cloudbuild.googleapis.com artifactregistry.googleapis.com run.googleapis.com --project=resqme-943ee
```

Post-change status:

| API | Current state | Proposed action | Expected effects |
|---|---|---|---|
| `cloudfunctions.googleapis.com` | Enabled | None | Existing Cloud Functions API remains enabled. |
| `cloudbuild.googleapis.com` | Enabled | No further change | Build identity/resources may be provisioned when used; build execution can incur charges. |
| `artifactregistry.googleapis.com` | Enabled | No further change | Artifact repository/image storage and transfer may incur charges. |
| `run.googleapis.com` | Enabled | No further change | Cloud Run service identity/resources may be provisioned when used; deployed service compute/request charges may occur. |

No other API was explicitly named by the operation. The full pre-change enabled API list was not captured, so this record does not claim that every unrelated API's state was compared. API enablement is not deployment and does not authorize Function deployment, IAM changes, hosted invocation, or account creation. Billing is enabled; later builds, artifact storage, and deployed Functions can incur usage charges. Confirm current pricing/quotas before deployment approval.

Pre-change identity and API checks:

```powershell
gcloud.cmd projects describe resqme-943ee --format="value(projectId,projectNumber)"
gcloud.cmd services list --enabled --project=resqme-943ee --format="value(config.name)"
```

After this API mutation, the same commands confirmed the project remained `resqme-943ee` / `519076598217` and the approved APIs are `ENABLED`. Inspect service-agent metadata read-only:

```powershell
gcloud.cmd iam service-accounts list --project=resqme-943ee --format="table(email,disabled,displayName)"
gcloud.cmd projects get-iam-policy resqme-943ee --format=json
```

The user-managed account list increased from App Engine default and Firebase Admin SDK to include `519076598217-compute@developer.gserviceaccount.com`; project IAM grants it `roles/editor`. `gcloud builds get-default-service-account --project=resqme-943ee` returned this Compute default account as the Cloud Build execution identity. Project IAM also shows Cloud Build and Cloud Run service-agent bindings and a legacy Cloud Build builder binding. The Artifact Registry `gcp-sa-artifactregistry` account was not found. Direct `describe` requests for Cloud Build and Cloud Run service-agent accounts returned `PERMISSION_DENIED` (`iam.serviceAccounts.get`), despite their IAM service-agent bindings being present. These are the observed automatic identity changes/metadata limitations; no account was manually created. The default Compute account's Editor grant is a major least-privilege blocker for both build and runtime use.

The API enablement operation succeeded without requesting further permissions. If an unexpected API/resource change appears during later deployment preparation, stop immediately, capture the exact error and resulting read-only service/IAM state, and request owner direction. Do not retry with broader APIs, manually create/delete identities, alter IAM, or disable APIs as automatic rollback. Disabling an API may affect other consumers; any reversal requires impact review and separate owner approval.

Preliminary IAM findings below are retained for context and are superseded by the final Checkpoint 1 execution record. The original matrix was prepared before the owner-authorized IAM changes.

| Requirement | Current principal / exact role / scope | Proposed role or permission / scope (not applied) | Purpose, risk, verification, and recovery |
|---|---|---|---|
| Deployment operator | `user:dev.guntang@gmail.com`; project `roles/owner`. | Candidate baseline: project `roles/cloudfunctions.developer` + `roles/serviceusage.serviceUsageConsumer`; `roles/iam.serviceAccountUser` only on the selected runtime account. For these callable Functions, Firebase CLI 15.34.1 sets each Cloud Run service's invoker policy using `run.services.setIamPolicy`; its separate `cloudfunctions.functions.setIamPolicy` preflight is for plain HTTPS triggers, not callable triggers. Propose only `run.services.setIamPolicy` in a project custom role, not `roles/cloudfunctions.admin` or `roles/run.admin`. No grant is authorized. | Enables approved Function create/update and per-service invoker setup. Owner remains excessive. Verify bindings and `testIamPermissions` before any authorized change. Export IAM policy before a change; remove only approved new bindings for recovery. |
| Cloud Build executor | `gcloud builds get-default-service-account` returns `519076598217-compute@developer.gserviceaccount.com`; project `roles/editor`. Legacy `519076598217@cloudbuild.gserviceaccount.com` has `roles/cloudbuild.builds.builder` but is not the selected default. | Do not use the Editor Compute default for production builds. A dedicated builder would need scoped build/artifact permissions, but Firebase CLI 15.34.1's local Functions deploy/discovery path exposes no build-service-account setting. Resolve whether a different approved deployment mechanism or project-level Cloud Build default can be used, then derive exact minimum roles. | Build identity used for build steps; project Editor could access/mutate unrelated resources. Verify effective identity through build configuration/metadata and read-only IAM after a later approved build. No identity created or role changed. |
| Functions runtime | No deployed Function exists. If unspecified, the Compute default is the likely Gen 2 default and has project `roles/editor`; do not rely on that default. Candidate package does not set `serviceAccount`. | Propose a dedicated per-Functions runtime identity with `roles/datastore.user` at project scope only, since the three handlers use Admin Firestore. Firebase CLI discovery supports a runtime `serviceAccount` option, but the source/package must be updated after the owner approves the exact account. Do not reuse the Firebase Admin SDK account (Auth/App Check/Storage privileges) or App Engine default (Editor). | Runtime needs server Firestore document access; Admin SDK bypasses Firestore Rules, so callable Auth/UID checks remain mandatory. Project-scoped role is broader than per-document access. Verify `serviceConfig.serviceAccountEmail` and effective IAM after a separately approved deployment. |
| Google-managed service agents | IAM shows Cloud Functions service agent `service-519076598217@gcf-admin-robot.iam.gserviceaccount.com` (`roles/cloudfunctions.standardServiceAgent`), Cloud Build service agent `service-519076598217@gcp-sa-cloudbuild.iam.gserviceaccount.com` (`roles/cloudbuild.serviceAgent`), and Cloud Run service agent `service-519076598217@serverless-robot-prod.iam.gserviceaccount.com` (`roles/run.serviceAgent`). Artifact Registry `gcp-sa` account was not found. | Retain only service-agent bindings automatically required by enabled services; do not manually create/alter agent accounts or bindings. Recheck with an administrator if deployment reports a specific prerequisite. | Direct Cloud Build/Run service-account descriptions were denied with `iam.serviceAccounts.get`, so only project policy bindings were verifiable. Unexpected missing/changed bindings require stop and owner review. |
| Callable invocation | No deployed service and therefore no invoker policy to inspect. | Expected per-service public HTTP/Cloud Run invoker access (typically `allUsers` with `roles/run.invoker`) is required for Firebase client callable transport; this does **not** replace Firebase Auth. Preserve `request.auth` and profile UID checks. Grant only per service, never project-wide; verify the exact CLI-created binding before/after deployment. | Public endpoint permits network requests and increases abuse/DoS exposure; handler Auth rejects unauthenticated business requests. App Check remains unenforced, so no attestation mitigation exists. No binding is authorized now. |

Google Cloud recommends dedicated Cloud Build service accounts where defaults are broad. No Function exists to reveal runtime identity or invoker policy; service-agent details were partly unreadable. The IAM plan is not ready to apply. Obtain owner review/approval of the exact least-privilege role/resource bindings before any IAM mutation; perform read-only post-deployment checks once the service exists.

**Preliminary Checkpoint B note (superseded below):** This earlier matrix predates validation of `roles/run.builder` and the Google Cloud CLI `--build-service-account` path. Use only the final matrix and strategy comparison below. No identity or IAM binding has been created or changed.

### Checkpoint B final IAM proposal — supersedes the preliminary matrix above

The following is a read-only proposal, not authorization to create identities or change IAM. The project still has the active operator as Owner and the Cloud Build default as Compute `roles/editor`.

| Requirement | Current principal and binding | Proposed exact change (not applied) | Purpose, verification, risk, and recovery |
|---|---|---|---|
| Deployment operator | `user:dev.guntang@gmail.com`; project `roles/owner`. | For Firebase CLI path: project `roles/cloudfunctions.developer`, `roles/serviceusage.serviceUsageConsumer`, and a custom project role containing only `run.services.setIamPolicy`; `roles/iam.serviceAccountUser` on the runtime account. For dedicated-build path, also scope `roles/iam.serviceAccountUser` to the build account. These are proposals, not grants. | Functions Developer lacks `run.services.setIamPolicy`; Cloud Functions Admin includes policy permissions but is broader. Verify role contents, all bindings, and `testIamPermissions` before any authorized change. Export prior IAM policy; recovery removes only approved new bindings. |
| Cloud Build executor — Firebase CLI path | `519076598217-compute@developer.gserviceaccount.com`; project default, project `roles/editor`. | Remove project `roles/editor`; add project `roles/run.builder` on this same identity. Do not add `roles/cloudbuild.builds.builder`. | Preserves Firebase CLI and the reviewed package. Removing Editor may break other workloads that use the shared Compute identity; usage has not been inventoried. `roles/run.builder` grants project-wide Artifact Registry upload/download/delete, logging, source-repo, and storage read. Verify identity references before mutation and a build afterward. Restore Editor only with owner-approved recovery. |
| Cloud Build executor — dedicated-account alternative | Existing Compute default remains project `roles/editor`; legacy Cloud Build account is not selected. | Proposed `resqme-functions-build@resqme-943ee.iam.gserviceaccount.com` (availability not checked; creation not authorized): project `roles/run.builder`; deployer gets `roles/iam.serviceAccountUser` on this identity. Installed gcloud 575.0.1 supports `gcloud functions deploy --gen2 --build-service-account projects/resqme-943ee/serviceAccounts/resqme-functions-build@resqme-943ee.iam.gserviceaccount.com`. | Avoids changing the current default. This is a supported Gen 2 source-deploy route but not the reviewed Firebase CLI path/artifact; revalidate source packaging, callable/Auth behavior, and exact deployment scope. Verify deployed `buildConfig.serviceAccount` and build metadata. Remove only the new binding after confirming no build uses it; do not delete the account absent separate approval. |
| Functions runtime | No deployed Function. Compute and App Engine defaults have project `roles/editor`; Firebase Admin SDK identity has unrelated Auth/App Check/Storage privileges. Candidate has no runtime override. | Recommend a dedicated runtime account, configured via supported Function `serviceAccount` option, with a custom project role containing exactly `datastore.databases.get`, `datastore.entities.get`, `datastore.entities.create`. Grant the deployer `roles/iam.serviceAccountUser` only on that account. Do not grant broad `roles/datastore.user` unless testing proves this custom role insufficient. | The permission set maps to the current transaction start, direct document reads, and create-only writes; it still enables read/create across the project and Admin SDK bypasses Rules. Confirm against official Firestore method permissions; verify `serviceConfig.serviceAccountEmail` and a separately authorized acceptance test. Any account, grant, or source/package change needs separate approval. Remove only an approved binding after no Function uses the identity; do not delete data/account as rollback. |
| Google-managed service agents | IAM shows the Cloud Functions, Cloud Build, and Cloud Run service-agent bindings. Direct Cloud Build/Run account metadata reads were denied (`iam.serviceAccounts.get`); Artifact Registry agent was not found. | No manual creation or role changes proposed. Preserve Google-managed bindings. | Only project-policy bindings are verified. If a later deployment identifies an exact missing prerequisite, request authorized read-only confirmation and stop rather than broadening IAM. |
| Callable invocation | No deployed service or current per-service invoker policy. | Firebase CLI 15.34.1's callable release path sets `allUsers` with `roles/run.invoker` on each callable's Cloud Run service; per-service only, never project-wide. | Network invocation is public at the infrastructure IAM layer. Firebase Auth remains enforced in handlers, UID ownership is server-derived, and App Check remains unenforced, leaving abuse/cost exposure. Verify all three policies after separately approved deployment. Removing a binding blocks callable clients and requires owner approval. |

#### Firestore operation-to-permission trace

| Function | Admin SDK operation | Required permission |
|---|---|---|
| `createStudentRegistration` | Transaction begin/rollback | `datastore.databases.get` |
| `createStudentRegistration` | `tx.get(profile)` and final `profile.get()` | `datastore.entities.get` |
| `createStudentRegistration` | `tx.create(profile)` and `tx.create(acknowledgment)` | `datastore.entities.create` |
| `getMyStudentProfile` | Direct profile document `.get()` | `datastore.entities.get` |
| `ensureMyTier1Qr` | Transaction begin/rollback | `datastore.databases.get` |
| `ensureMyTier1Qr` | `tx.get(profile)`, `tx.get(credential)`, final `credential.get()` | `datastore.entities.get` |
| `ensureMyTier1Qr` | `tx.create(credential)` | `datastore.entities.create` |

Firestore documents `datastore.databases.get` for `beginTransaction`/`rollback`, `datastore.entities.get` for document reads, and `datastore.entities.create` for a commit with an `exists:false` precondition. These handlers use `tx.create`, not update-capable `set`/`update`; none of the approved paths lists or deletes documents. The proposed custom runtime role therefore contains exactly those three permissions, granted at project scope. This limits operation types, not document paths: Admin SDK calls bypass Rules, and the role can read/create data across the project. Official method requirements: [Firestore server-client IAM permissions](https://cloud.google.com/firestore/docs/security/iam).

#### Build-identity strategy comparison and recommendation

| Strategy | Proposed identity and grant | Compatibility / other-workload impact | Verification and recovery |
|---|---|---|---|
| Firebase CLI, narrow existing default | Existing `519076598217-compute@developer.gserviceaccount.com`: remove project `roles/editor`; grant project `roles/run.builder`. Runtime must use the dedicated Firestore-limited account. | Preserves Firebase CLI 15.34.1 and the reviewed package preparation. Its Functions discovery/deploy path has no per-deployment build-account option. Removing Editor may break other Cloud Build or runtime workloads using this shared account; those uses have not been inventoried. `roles/run.builder` is the documented source-build role and includes project-level Artifact Registry upload/download/delete, logging, source-repo, and storage read. | Before mutation, inventory workload references and capture policy; after approval, verify build identity and a build. Recovery is an owner-approved restoration of the previous Editor binding. |
| Dedicated builder through Google Cloud CLI | Proposed `resqme-functions-build@resqme-943ee.iam.gserviceaccount.com` (availability unverified): project `roles/run.builder`; deployer gets `roles/iam.serviceAccountUser` scoped to it. Local gcloud 575.0.1 confirms `gcloud functions deploy --gen2 --build-service-account projects/resqme-943ee/serviceAccounts/{account}`; official Google documentation supports the flag for source deployments. | Avoids changing the Compute default and workloads that may use it. It is not the previously reviewed Firebase CLI deployment/package path; validate the three callable entry points, auth behavior, source packaging, and exact scope before accepting this route. | After separate approval, verify actual deployed `buildConfig.serviceAccount`, build logs, and IAM. Revert to the prior deployment path and remove only the approved binding once no build uses it; no account deletion is implied. |

**Recommendation:** For the exact already-reviewed Firebase CLI artifact, narrowing the existing default is the smallest deployment change, but cannot be deemed safe until the shared account's other workload references are audited. If minimizing cross-workload impact takes priority, the dedicated builder is safer for existing workloads but requires a fresh local package and callable validation because it changes the deploy path. Do not remove Editor or create/grant a build identity until the owner selects and approves a path.

The runtime custom role is based on the code's Firestore operations and official method-permission mapping; it has not been tested or granted. The predefined `roles/datastore.user` includes broad `datastore.entities.*`, including update/delete, and is not preferred. Local Firebase CLI 15.34.1 source inspection (`lib/deploy/functions/checkIam.js`, `lib/deploy/functions/release/fabricator.js`, and `lib/gcp/run.js`) confirmed the callable IAM behavior; local gcloud 575.0.1 help confirmed the build-service-account flag. No deploy or dry-run was run. See official [Cloud Functions IAM roles](https://cloud.google.com/functions/docs/reference/iam/roles), [Firestore server-client IAM permissions](https://cloud.google.com/firestore/docs/security/iam), [Cloud Run source build service account](https://cloud.google.com/run/docs/configuring/services/build-service-account), and [Cloud Build user-managed service accounts](https://cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts).

**Checkpoint B disposition:** The existing Compute default is rejected as-is because it has project Editor. For Firebase CLI compatibility, reducing it to `roles/run.builder` is the smallest path, but must wait for a read-only audit of other workloads that may rely on that shared identity. A dedicated builder is supported by Google Cloud CLI source deployment flags but requires fresh local candidate/callable validation and a deployment-scope review. The runtime custom-role proposal and exact callable invoker behavior are documented above. G3 remains **NO-GO**; G4 remains **NOT AUTHORIZED**. No IAM mutation or service-account creation occurred.

## 3. App Check and application security

- Preserve the current unenforced App Check posture. No debug token registration, provider initialization, token disclosure, enforcement, or hosted App Check changes are included.
- Do not describe unenforced App Check as attestation protection.
- Residual risk: callable endpoints are publicly invokable at the Cloud Run IAM layer and App Check enforcement is off, so requests have no proof of coming from the intended app/device. Firebase Auth and UID-derived data ownership reject unauthenticated business access and cross-user profile reads, but a caller with a valid Firebase account can automate registration/QR calls, abuse endpoints, and increase Functions/Firestore usage and cost. Obtain explicit owner acceptance of this staging posture before G3 GO/G4 approval.
- Keep Firebase Authentication and server-side authorization mandatory regardless of App Check.
- Firestore and Storage Rules are out of scope and must not be deployed or relaxed.
- No medical, LRN, acknowledgment, QR credential, internal metadata, or arbitrary profile fields may be returned by `getMyStudentProfile`.
- Profile reads must remain bound to `request.auth.uid`; no client UID may select a document.

Debug-only Android App Check setup and token handling require a separate approval and a test sequence before any enforcement proposal.

## 4. Source and artifact identity (original package; superseded)

The package and no-runtime-identity statements in this section and the following original command proposal predate Checkpoint 1. The final hashes and dedicated-runtime configuration are recorded in the final update.

- Repository baseline: `main`, HEAD `47fd30e567c16b19b7fbb91f410c23c19f8a912b` at implementation start. The implementation and owner work remain uncommitted; this commit does not identify the complete source by itself.
- Exact candidate archive: `C:\Users\Mj\.copilot\session-state\d811cfa2-9a8b-416a-8b2c-15b13cf9e996\files\resqme-g4-functions-minimal-candidate.zip`
- Candidate archive SHA-256: `099cc7aa1caec651ae6d8509ac0d79cc17aabfe9adbf464307e1a454e6b3b5ef`
- The archive was constructed from the current Node 22 build and curated packaging files. It was not deployed. Its checksum identifies this candidate only; it is not an approved release artifact.
- Installed Firebase CLI: `15.34.1`. Extracting the candidate into an isolated folder and calling its own `prepareFunctionsUpload` packaged only the configured `functions/` source directory. The CLI-prepared upload ZIP is `C:\Users\Mj\.copilot\session-state\d811cfa2-9a8b-416a-8b2c-15b13cf9e996\files\resqme-g4-functions-cli-upload.zip`, SHA-256 `ea6d181fa604a70e007bc75a00c873a81456c030396c1aa601a136f9500a3927`; Firebase CLI source hash `10fc53f2e0cd282327385b9e8abebb341079f6c8`.
- The CLI-prepared ZIP has 9 entries relative to the Functions source root: package manifests plus seven compiled runtime modules. Requiring its entrypoint exposed exactly the approved three exports. It excludes tests, private tools, credentials, application data, Rules, and dev dependencies. The outer candidate ZIP is not itself the Firebase CLI upload; deployment must run from an isolated extraction of that candidate so the CLI packages the same source files. A later CLI invocation may create ZIP bytes with different archive metadata; reverify CLI source hash and entry list before upload.
- Node 22 is the configured engine and hosting runtime. Official Windows x64 Node `v22.23.4` archive checksum matched the Node project's published `SHASUMS256.txt` and recorded SHA-256 `cbc74b5e0982c9dbb41525fd8fb5dcd32fbee237863f7829072f4639a1ce5f20`. Current-source build/configured Functions tests and isolated emulator suites passed under this runtime. No system Node or dependency versions were changed.

Before any G4 decision, review the exact source diff and revalidate the candidate if its source or package contents change. The present candidate was built and verified under Node 22; do not substitute `origin/main`, an unreviewed dirty tree, or a differently hashed archive.

## 5. Original packaging and deployment command proposal (superseded)

The candidate contains a root `firebase.json`, the Functions production manifest/lock, a curated compiled runtime dependency closure, and an entrypoint exporting **only** `createStudentRegistration`, `getMyStudentProfile`, and `ensureMyTier1Qr`. The compiled medical callable module and exports are omitted. The shared `medical_contract.js` remains because profile and QR validation import its `object`/`keys` helpers. Existing medical source and functionality in the repository are unchanged; medical callables are simply outside this candidate's approved deployment scope.

Exact ZIP contents (10 files):

```text
firebase.json
functions/package.json
functions/package-lock.json
functions/lib/src/index.js
functions/lib/src/registration/create_student_registration.js
functions/lib/src/registration/registration_contract.js
functions/lib/src/profile/get_my_student_profile.js
functions/lib/src/qr/ensure_my_tier1_qr.js
functions/lib/src/onboarding/authorization.js
functions/lib/src/medical/medical_contract.js
```

The package and lock preserve the existing runtime dependencies: `firebase-admin@14.5.0`, `firebase-functions@7.4.0`, and `google-auth-library@11.3.1`; no development dependencies are in the package lock root. Internal relative module dependencies resolve within the archive. Every packaged callable/dependency module except the deliberately narrowed `index.js` matches the current Node 22 build byte-for-byte. The entrypoint loaded successfully and exported exactly the approved three names; the exact Firebase CLI upload preparation result and digest are recorded above. It excludes tests, test data, private tools, `node_modules`, Rules, env files, and credential/key files. Reverify the CLI source hash and entry list before any future upload and stop on any unexpected Function or file.

The CLI-prepared upload ZIP contains exactly these 9 entries relative to `functions/`:

```text
package.json
package-lock.json
lib/src/index.js
lib/src/medical/medical_contract.js
lib/src/onboarding/authorization.js
lib/src/profile/get_my_student_profile.js
lib/src/qr/ensure_my_tier1_qr.js
lib/src/registration/create_student_registration.js
lib/src/registration/registration_contract.js
```

No `.firebaserc` is required for the proposed command because the project is explicit. Extract the candidate ZIP into a new isolated directory and run from its root:

**Hold:** do not run this command. The candidate does not bind a dedicated runtime service account, and its default runtime identity is not acceptable while the Compute default has project Editor. For Firebase CLI, select the existing default only after the read-only workload-reference audit and approved role reduction; for a dedicated builder, use the supported gcloud source-deployment flag but first revalidate the candidate packaging, callable/Auth behavior, and exact three-function scope. No identity or IAM changes are authorized. Any runtime source adjustment requires Node 22 regression verification and refreshed candidate/CLI package hashes before G4 approval.

```powershell
firebase.cmd deploy --config firebase.json --project=resqme-943ee --only functions:createStudentRegistration,functions:getMyStudentProfile,functions:ensureMyTier1Qr
```

This is a future proposal, not an instruction to execute now. The curated archive already contains compiled JS and the Functions package lock; the Firebase CLI performs package preparation/build work for Gen 2. `--only functions:...` excludes Firestore Rules, indexes, Storage, Hosting, and all other Firebase targets. Do not run deployment or a CLI dry-run in this session. Any source/package change requires Node 22 revalidation, a new candidate and CLI-prepared upload digest, and repeated export/content review.

### Local Node 22 and archive verification

The approved local run passed `npm.cmd test` (**64/64**) on Node `v22.23.4` / npm `10.9.9`; Auth/Firestore/Functions `demo-resqme` integration passed **10/10**; the checked-in Rules suite passed **4/4**; and deny-all containment passed **2/2** after a retry on free emulator ports. A first containment attempt exited 1 because an emulator child still occupied its previous ports; no unrelated process was interrupted. The retry used new loopback ports. Temporary configs and the verified runtime were removed.

The outer candidate ZIP SHA-256 was recomputed and matches `099cc7aa1caec651ae6d8509ac0d79cc17aabfe9adbf464307e1a454e6b3b5ef` (10 entries). The Firebase CLI-prepared upload SHA-256 is `ea6d181fa604a70e007bc75a00c873a81456c030396c1aa601a136f9500a3927` (9 source entries; CLI source hash `10fc53f2e0cd282327385b9e8abebb341079f6c8`). Exact allowlists, dependency closure, production dependency lock, three-export set, and test/tool/credential exclusions were checked against the installed Firebase CLI `15.34.1`. The package step was local-only; no deploy or dry-run was invoked.

### Expected deployment operations and read-only verification

The staging Function inventory was empty before deployment. An approved G4 deployment would therefore be expected to **create**, not update, exactly these three Gen 2 callable Functions in `us-central1`, Node.js 22: `createStudentRegistration`, `getMyStudentProfile`, and `ensureMyTier1Qr`. It must not delete existing Functions or deploy Rules/indexes/Storage/Hosting. Any non-empty preflight inventory or update/delete plan requires stopping for owner review.

After separately approved deployment, use metadata-only checks:

```powershell
gcloud.cmd projects describe resqme-943ee --format="value(projectId,projectNumber)"
gcloud.cmd functions list --v2 --project=resqme-943ee --format="table(name,region,environment,state,buildConfig.runtime,serviceConfig.serviceAccountEmail,serviceConfig.uri)"
gcloud.cmd functions describe createStudentRegistration --v2 --region=us-central1 --project=resqme-943ee --format="yaml(name,environment,buildConfig.runtime,serviceConfig.serviceAccountEmail,serviceConfig.uri)"
gcloud.cmd functions describe getMyStudentProfile --v2 --region=us-central1 --project=resqme-943ee --format="yaml(name,environment,buildConfig.runtime,serviceConfig.serviceAccountEmail,serviceConfig.uri)"
gcloud.cmd functions describe ensureMyTier1Qr --v2 --region=us-central1 --project=resqme-943ee --format="yaml(name,environment,buildConfig.runtime,serviceConfig.serviceAccountEmail,serviceConfig.uri)"
gcloud.cmd functions get-iam-policy createStudentRegistration --region=us-central1 --project=resqme-943ee
gcloud.cmd functions get-iam-policy getMyStudentProfile --region=us-central1 --project=resqme-943ee
gcloud.cmd functions get-iam-policy ensureMyTier1Qr --region=us-central1 --project=resqme-943ee
```

Confirm exactly these three Functions exist, generation 2, `us-central1`, Node 22, expected runtime identity, and reviewed invocation policy; compare Rules releases to the recorded deny-all versions and verify no other Firebase target changed. If CLI flags or fields differ in the installed gcloud version, consult local command help rather than substituting a mutating command.

## 6. Acceptance plan after separate approvals

Deployment, hosted invocation, account creation, and synthetic test data each need explicit authorization. If approved later, use only a dedicated synthetic `demo-*` or owner-approved staging identity and test:

1. Registration creates one Auth account and the expected owner profile without exposing private fields.
2. Authenticated profile callable returns only the approved allowlist; unauthenticated, missing, malformed, and foreign-UID attempts fail safely.
3. Flutter sign-in/profile-status refresh and registration retry continue to work; skipped medical onboarding reaches QR.
4. Repeated `ensureMyTier1Qr` calls reuse the persistent QR, return the established payload/response contract, and disclose no personal or medical data.
5. Firestore and Storage Rules remain unchanged; direct client reads/writes remain denied under the deployed policy.
6. Confirm deployed Function name, generation, region, runtime, revision, invoker policy, and App Check posture using metadata only.

Local emulator tests do not establish hosted behavior. The current local harness does not exercise the complete Flutter email/password account-creation flow end-to-end.

### Synthetic test data cleanup and preservation policy

This is a future proposal only. Before Checkpoint D authorization, identify the exact synthetic Auth UID and email and capture a before-state showing whether any matching profile/QR paths already exist; do not overwrite or delete preexisting records. If owner approval covers cleanup, remove only the explicitly created synthetic Auth user and the exact `studentProfiles/{uid}` profile, its registration acknowledgment subcollection documents, and `studentQrCredentials/{uid}` created by that test. Use Admin SDK cleanup only after confirming the UID belongs to that run. Preserve all unrelated student profiles, acknowledgments, medical records, QR credentials, Rules, and logs. If ownership or test-created status is uncertain, stop and retain the data pending owner direction. Cleanup is not implied by test authorization.

## 7. Cost and rollback considerations

Potential billable usage includes Cloud Build, Artifact Registry image storage, Cloud Run/Functions compute and requests, Firestore reads/writes, Authentication synthetic accounts, logs, and network egress. Billing is enabled per prior inventory, but no estimate was calculated. Obtain a project-specific estimate and confirm quotas before approval.

The last inventory found no deployed Functions, so no known-good deployed Function revision is established. Preserve the reviewed prior source/artifact and record deployed revisions before any change. A code rollback would require explicit authorization to redeploy a reviewed prior artifact; deleting newly created Functions or changing data is not an implicit rollback. Do not delete accounts, profiles, QR credentials, or other records as rollback steps.

## 8. Original approval gates (superseded by the final authorization package)

Before deployment, obtain owner approval for:

1. Select the build strategy in the Checkpoint B matrix. For Firebase CLI, first authorize the read-only workload-reference audit before considering replacing the shared Compute account's Editor with `roles/run.builder`. For dedicated gcloud deployment, approve fresh local artifact/callable validation before any identity grant.
2. Approve or revise the exact deployment-operator roles, dedicated runtime identity/custom Firestore role, and per-Function public invoker policy in the Checkpoint B matrix. No identity creation or IAM mutation is authorized by this manifest.
3. Explicit acceptance or revision of the current App Check unenforced posture and its residual risk.
4. Approval of the exact reviewed source revision, candidate ZIP SHA-256, Firebase CLI source hash, and CLI-prepared upload ZIP SHA-256; rerun validation if any changes or if selecting gcloud.
5. Deployment of exactly the three named Functions and the per-service invoker policy, with no Rules/indexes/Storage/Hosting changes.
6. Separate synthetic hosted account creation/invocation tests and any specifically scoped cleanup.
7. Any debug-only App Check setup or later enforcement proposal.

**Current status: G3 NO-GO; G4 NOT AUTHORIZED. Checkpoint A APIs are enabled. No further hosted configuration change or deployment is authorized by this document.**

## 2026-11-09 — Option A and Checkpoint 1 approval request (completed; historical)

The owner selected **Option A: Controlled Debug-Only Staging Pilot**. This supersedes the earlier request to choose between Firebase CLI and dedicated gcloud: use Firebase CLI and retain the existing Cloud Build Compute default account with its current project `roles/editor` for this staging pilot only. No builder account or build-role change is proposed. This does not authorize production use of that risk or authorize deployment.

### Exact IAM authorization request (approved and completed; see final update)

Authorize this single conditional IAM change set for project `resqme-943ee` / `519076598217`:

1. Reverify project identity; inspect whether `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` and the project role already exist. If either exists unexpectedly, stop and report rather than overwrite or repurpose it.
2. If the account is absent, create service account ID `resqme-functions-runtime` with display name `ResQMe Functions Runtime`; create no user-managed key.
3. If the role is absent, create project custom role ID `resqmeFunctionsRuntime`, title `ResQMe Functions Runtime`, stage `GA`, with exactly:
   - `datastore.databases.get`
   - `datastore.entities.get`
   - `datastore.entities.create`
4. Bind `projects/resqme-943ee/roles/resqmeFunctionsRuntime` to `serviceAccount:resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` at project scope.
5. Make no other IAM changes: do not modify the existing deployment operator's project `roles/owner`, the Cloud Build default's `roles/editor`, Google-managed service agents, or any unrelated principal.

The three Firestore permissions correspond to transaction begin/rollback, document reads, and create-only registration/acknowledgment/QR writes. No approved handler updates, deletes, or lists documents. The Admin SDK bypasses Rules, so the project-scoped read/create role has broad document-path reach; callable Firebase Auth and UID-derived ownership checks remain mandatory.

The existing deployer is `user:dev.guntang@gmail.com` with project `roles/owner`. No extra deployer role grant is part of this request. After approval, read-only `testIamPermissions` must verify `iam.serviceAccounts.actAs` for the runtime account and `run.services.setIamPolicy` for callable invoker setup. If either is missing, stop and request a narrowly scoped follow-up approval; do not broaden roles. The allUsers `roles/run.invoker` bindings are **not** authorized by this IAM checkpoint; they are per-service deployment changes requiring Authorization A below.

Verification after the authorized IAM change: recheck project ID/number; describe the exact service account and custom role; inspect project and service-account policy; verify the role permission list and principal bindings; verify no unexpected grants. Recovery before deployment: remove only the approved custom-role binding if verification fails. Do not delete the service account or custom role without a separate no-usage check and approval. Preserve the existing Compute Editor binding and all service-agent bindings.

**Owner decision required now:** explicitly approve or decline this exact conditional IAM change set. Until approval, do not create or modify any IAM resource.

### Package and local configuration evidence

- Current nested repository revision: `47fd30e567c16b19b7fbb91f410c23c19f8a912b`, dirty; it is not an immutable deployment revision.
- The candidate ZIP was rehashed: `099cc7aa1caec651ae6d8509ac0d79cc17aabfe9adbf464307e1a454e6b3b5ef`. Its 10 files include the Functions-only `firebase.json`, Node 22 package files, and only the three approved entrypoint exports. It excludes the medical callable module, tests, private tools, credentials, data, Rules, indexes, and Hosting configuration.
- The Firebase CLI 15.34.1-prepared upload ZIP was rehashed: `ea6d181fa604a70e007bc75a00c873a81456c030396c1aa601a136f9500a3927`; 9 entries under the Functions source. All approved callable modules match the current compiled worktree modules; the candidate entrypoint is intentionally narrowed versus the worktree entrypoint, which also exports two medical functions. The candidate and worktree direct production dependencies and resolved production versions match; the candidate omits development dependencies.
- The candidate's deployment inputs do not yet bind a runtime service account. Source/package options must be updated after Checkpoint 1, then built, tested, rehashed, and reapproved. Do not use either current hash as the final deployment artifact after that change.
- Flutter's debug staging selection is pinned to `resqme-943ee`, callables use `us-central1`, and emulator endpoints are configured only for explicit debug emulator mode; release builds do not initialize this Firebase backend. At this original snapshot, Email/Password was last captured as enabled in the 2026-11-06 staging security report; the fresh read-only confirmation is recorded in the final update.
- The proposed Functions-only `firebase.json` does not reference Firestore Rules, Storage Rules, indexes, or Hosting. Deploy only from an isolated extraction of the refreshed candidate with the exact three-function `--only` selector. The live repository entrypoint also exports medical callables, so do not deploy unrestricted from `resqme/functions`.

**Checkpoint 2 is now prepared below.** Checkpoint 1 was approved and completed; the current package, hashes, runtime identity, invoker scope, post-deployment checks, costs, and rollback are recorded in the final authorization package.

## Final update — Checkpoint 1 complete; Checkpoint 2 authorization package

This update supersedes earlier statements in this manifest that the runtime identity was absent, that IAM changes had not been made, that the candidate lacked a runtime identity, that the latest package hashes were the original hashes, or that G3 was NO-GO. It does not authorize deployment or hosted testing.

### Checkpoint 1 IAM execution and verification

The owner approved and the operator applied exactly the following changes in `resqme-943ee` / project `519076598217`:

| Principal/resource | Current exact state |
|---|---|
| Runtime service account | `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` exists and is active; no user-managed key was created. |
| Custom role | `projects/resqme-943ee/roles/resqmeFunctionsRuntime`, title `ResQMe Functions Runtime`, stage `GA`; permissions are exactly `datastore.databases.get`, `datastore.entities.get`, `datastore.entities.create`. |
| Runtime grant | The custom role is bound only to `serviceAccount:resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` at project scope. |
| Existing identities | Operator Owner, Compute default Editor, and Google-managed service-agent bindings are unchanged. No build account was created and no build permissions were changed. |

The before/after project IAM policy comparison showed exactly one addition: the runtime account's custom-role binding. Read-only permission checks confirmed the deployer has `iam.serviceAccounts.actAs` on the runtime account and `run.services.setIamPolicy` on the project. No additional permission is needed for the proposed path based on these checks. If deployment later reports an exact missing permission or agent, stop and request a narrowly scoped decision; do not broaden roles. The project-scoped Firestore role lets the Admin SDK read/create documents project-wide and bypass Rules; callable Firebase Auth and UID-derived ownership checks remain mandatory.

App Check remains UNENFORCED. The owner explicitly accepted the resulting device-attestation and abuse/cost risk only for this debug-only, synthetic-data staging pilot. No App Check setting or token was changed. The Compute default's project `roles/editor` is also retained as an owner-accepted temporary staging risk; it is not acceptable as a production posture. No production authorization is implied.

### Current source and package identity

- Repository `HEAD` remains `47fd30e567c16b19b7fbb91f410c23c19f8a912b` and the worktree remains dirty. The source change is limited to shared runtime options, those options on the three approved callables, and a regression assertion. No commit was created. The exact package hashes, not `HEAD` by itself, identify the staged deployment input.
- Current candidate: `C:\Users\Mj\.copilot\session-state\d811cfa2-9a8b-416a-8b2c-15b13cf9e996\files\resqme-g4-functions-runtime-candidate.zip`; SHA-256 `9629f7ba61c7fc10b9446c52f6a406dc0c3ada04956333d4a1bc89b65105e8b4`; 10 entries.
- Current Firebase CLI 15.34.1-prepared upload payload: `C:\Users\Mj\.copilot\session-state\d811cfa2-9a8b-416a-8b2c-15b13cf9e996\files\resqme-g4-functions-runtime-cli-upload.zip`; SHA-256 `7b2213ea88b87ca3b292706e454b6c5ffc6792230697f72979adc3fc83cd99d1`; 9 Functions-source entries. Firebase CLI source hash: `6706546534eccfd0235779441c941a668afcfd30`.
- Candidate load verification found exactly `createStudentRegistration`, `getMyStudentProfile`, and `ensureMyTier1Qr`; each endpoint manifest has `serviceAccountEmail` set to `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com`. Runtime is `nodejs22`; region is `us-central1`. Medical callable code/exports, tests, private tools, credentials, application data, Rules, Storage, indexes, Hosting, and development dependencies are excluded. The shared `medical_contract.js` is included only for validation helpers used by approved code.
- The candidate's Functions-only `firebase.json` includes no Rules/Storage/Hosting targets. Deployment must run from an isolated extraction of this candidate and use the exact function allowlist. Recheck candidate and current CLI version/source/entry list immediately before execution; stop on any hash, export, configuration, source, or inventory mismatch. CLI upload repackaging may change ZIP metadata, so its exact inputs and source list—not an assumed byte-identical transient upload archive—must be verified.
- The debug Flutter staging configuration targets `resqme-943ee` and `us-central1`; emulator endpoints are used only by explicit debug emulator mode. Release/profile builds do not initialize this Firebase backend. Read-only Identity Toolkit metadata confirms Email/Password is enabled for project `519076598217`; the per-request quota-project header was used without changing ADC or project configuration.

### Current local verification

The isolated official Node.js v22.23.4 Windows x64 archive SHA-256 is `cbc74b5e0982c9dbb41525fd8fb5dcd32fbee237863f7829072f4639a1ce5f20`, matching the official published checksum. Isolated npm version was 10.9.9; system Node was not changed.

| Validation | Result |
|---|---|
| Functions TypeScript build and configured regression suite | Passed, 65/65. |
| Auth/Firestore/Functions `demo-resqme` emulator integration | Passed, 10/10; loopback ports 19099, 18080, and 15001. |
| Local Firestore Rules suite | Passed, 4/4. |
| Local deny-all Rules containment suite | Passed, 2/2. |

These are local results. No hosted Function is deployed or invoked, and no hosted account or application record was created/read/written. Local Rules results do not freshly verify hosted Rules metadata; the last read-only hosted snapshot reported Firestore and Storage deny-all. No Flutter files changed during this update; historical Flutter tests/analyze were not rerun. Emulator cleanup was limited to the exact test-owned process identified by command line and PID.

**Readiness:** G3 is **GO for the scoped pre-deployment staging pilot**. G4 remains **NOT AUTHORIZED**. The previously empty Functions inventory must be rechecked immediately before deployment; if any Function or relevant configuration now differs, stop and return with the exact difference.

### Authorization A — deploy exactly three Functions

Approval authorizes only the following deployment in the named project:

| Item | Exact scope |
|---|---|
| Target | Firebase project `resqme-943ee`, project number `519076598217`; Functions v2 / 2nd generation. |
| Functions | `createStudentRegistration`, `getMyStudentProfile`, `ensureMyTier1Qr`; no other Functions. |
| Runtime and region | Node.js 22 (`nodejs22`), `us-central1`. |
| Runtime identity | `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` with only the approved project custom role above. |
| Build identity | Existing `519076598217-compute@developer.gserviceaccount.com`, retaining project `roles/editor` for this pilot only. No build-account IAM changes. |
| Callable invocation | Add `allUsers` → `roles/run.invoker` separately on each of the three generated Cloud Run services, as required for Firebase callable transport. This allows unauthenticated transport reachability; handlers must continue rejecting unauthenticated requests and enforcing UID ownership. Do not grant project-wide invoker. |
| App Check | Remains UNENFORCED under the explicitly accepted staging-only risk. No debug token registration or enforcement change. |
| Source | Isolated extraction of the current candidate above; candidate SHA-256 `9629f7ba61c7fc10b9446c52f6a406dc0c3ada04956333d4a1bc89b65105e8b4`; prepared CLI payload SHA-256 `7b2213ea88b87ca3b292706e454b6c5ffc6792230697f72979adc3fc83cd99d1`; CLI source hash `6706546534eccfd0235779441c941a668afcfd30`. |
| Deployment command | From the candidate's isolated root, after revalidating its hash/content and confirming the target inventory: `firebase.cmd deploy --config firebase.json --project=resqme-943ee --only functions:createStudentRegistration,functions:getMyStudentProfile,functions:ensureMyTier1Qr` |
| Excluded scope | No Firestore/Storage Rules, indexes, Hosting, Auth provider, App Check, medical Functions, account, or application-data changes. No other APIs or IAM bindings. |

Expected effects include builds through Cloud Build, image storage in Artifact Registry, three Cloud Functions/Cloud Run services, and three service-level callable invoker bindings. Usage of Cloud Build, Artifact Registry, Cloud Run/Functions, Firestore, Authentication, logging, and network egress may incur charges; no project-specific estimate was produced. Billing is enabled. No known deployed Function revision exists as a rollback target.

Immediately before deployment, reverify project ID/number, empty/expected Function inventory, candidate and CLI inputs, exports, runtime/region/identity, and Functions-only configuration. Afterward, verify the exact three names, generation, runtime, region, runtime identity, callable invoker policy, and revisions; confirm no Rules or unrelated Firebase targets changed. Stop on any unexpected permission, service-agent, API, artifact, or resource result. Recovery is to stop and report; redeployment of a prior artifact, invoker changes, or deletion of created resources requires separate approval. This authorization does not imply synthetic testing approval.

### Authorization B — synthetic hosted Tier 1 acceptance

This authorization is independent from Authorization A and permits no deployment. It becomes executable only after the three approved Functions have been deployed and verified. Approval of A alone does not grant B; the owner may approve A and B in the same decision. If only B is approved, it remains pending until deployment is separately authorized and verified.

| Control | Exact proposed limit |
|---|---|
| Accounts | At most two disposable Firebase Auth accounts: one synthetic student account and one auth-only second account for cross-user denial checks. No real student identities or real personal/medical data. |
| Test window | One owner-scheduled staging session, maximum 60 minutes, starting after deployment verification. Stop when the window expires; do not create replacement accounts without new approval. |
| Permitted document paths | Only `studentProfiles/{studentUid}`, `studentProfiles/{studentUid}/acknowledgments/tier1-registration-v1`, and `studentQrCredentials/{studentUid}` for the registered synthetic account. The second account receives no Firestore documents. Do not touch any preexisting matching path; if one exists before test creation, stop. |
| Permitted tests | Registration, same-payload retry, authenticated own-profile retrieval/allowlist, unauthenticated rejection, second-account cross-user attempts, direct client Firestore denial, QR creation/repeat equality in memory/logout-login retrieval/privacy shape, plus the listed public Tier 1 UI flows and offline scanner behavior. No Tier 2, medical, unrelated callable, or production workflow. |
| Evidence | Record pass/fail, counts, function metadata, and cleanup result only. Never log passwords, tokens, raw QR values, email addresses, or full Auth UIDs. Keep the exact synthetic UIDs only in an ephemeral session record until cleanup is verified; if cleanup fails, provide the minimum UID/path needed for owner-directed cleanup through the authorized channel, not in logs or these reports. Keep raw test logs only during execution and remove them at session end; retain only a sanitized outcome in these readiness documents. |
| Cleanup | Only after owner-authorized B: verify each test UID belongs to this run; delete the exact acknowledgment document, profile document, QR credential document, then the two exact test Auth users; verify those exact paths/users are absent. Do not run collection-wide deletes or touch unrelated data. |
| Cleanup exception | If ownership, path, or deletion outcome cannot be proven, do not delete; stop and report the remaining synthetic resources to the owner for direction. No retention beyond the exact scoped exception is intentional. |

Registration creates the Firebase Auth account in the client before invoking the registration callable. Test credentials exist only for the active run and are not written to this repository. For the second account, test the own-profile/QR endpoints and a supplied foreign UID only if the existing request contract permits it; do not expose the first account's identity in logs. The student test must confirm status follows existing age rules, profile fields match the approved allowlist, repeated QR responses match without logging the credential, signing out/in preserves retrieval, and QR data contains no personal or medical fields. Direct Firestore access must remain denied. Public mobile Tier 1 checks include Splash and Terms/Privacy, emergency dashboard, first-aid library, hotlines, DRRM guidance, QR scanner, registration/sign-in, My Profile name, My QR, logout/login; scanner offline behavior must remain intact. Distinguish automated evidence from owner-observed device acceptance; backend test success alone is not Tier 1 acceptance.

### Owner decision required

Select independently:

1. **Authorize A only** — deploy the exact three Functions and service-level callable invoker policies above.
2. **Authorize B only** — authorize the bounded synthetic hosted acceptance and exact cleanup above, usable only after verified deployment.
3. **Authorize A and B** — authorize both scopes independently as specified.
4. **Authorize neither / request changes.**

No action occurs unless the selected authorization is explicit. G4 remains NOT AUTHORIZED until then.

## 2026-11-09 — Authorized G4 execution attempt stopped before deployment

The owner subsequently authorized Authorization A and conditional Authorization B. Execution stopped during Checkpoint A1 before project, IAM, Rules, App Check, or Function-inventory verification was completed. A Firebase CLI identity-list query was run with JSON output; the response included credential-bearing fields in tool output. No credential values are reproduced here. The query did not deploy or invoke Functions, create accounts, or access application records. No gcloud preflight or hosted mutation followed, and no deployment attempt occurred.

Treat the affected local Firebase CLI session material as potentially exposed to this execution transcript. Do not reuse it for G4. An authorized operator must assess/revoke or replace the session through the normal account-security procedure, then reauthenticate using a non-credential-printing identity check before restarting the approved preflight. No token revocation, credential rotation, IAM change, or other remediation was performed here because it was outside the specifically approved deployment/testing operations.

**Execution outcome: G4 FAIL/BLOCKED before deployment.** Authorization A did not pass A1–A4; Authorization B was not eligible and was not run. No functions were deployed; no test account or Firestore document was created. Hosted acceptance matrix: all tests **NOT RUN**. Cleanup: zero test-owned resources created; nothing to clean; the testing window was not started. Do not treat this as a successful G4 result. Resume only after the session-security issue is addressed and a fresh authorized preflight confirms all required conditions.

## 2026-11-09 — Scoped Extensions API exception and read-only resume review

The owner confirmed manual credential recovery and retained Authorization A and conditional Authorization B. Fresh preflight verified operator `dev.guntang@gmail.com`, absence of `FIREBASE_TOKEN` and credential overrides (presence-only inspection), absence of standard local ADC, project `resqme-943ee` / `519076598217`, approved artifact hashes, runtime account/role, empty Functions inventory, and deployed deny-all Rules. The isolated deployment attempt then enabled `firebaseextensions.googleapis.com`; the exact deployment process was stopped. Post-stop inventory contained zero Functions. Authorization B never started.

The owner explicitly permits the already-enabled `firebaseextensions.googleapis.com` API to remain enabled solely for the approved three-Function deployment. This exception does not authorize installing, updating, or deleting Extensions, any further API enablement, or IAM changes. No rollback, API disablement, or deployment retry was performed during this review.

Read-only checks after the exception:

- Extensions instances API returned zero instances and no continuation page. No Extensions instance mutation appeared in the bounded Admin Activity query from `2026-11-08T17:57:00Z` through the review. This supports no instance creation/modification by the interrupted attempt; it is bounded audit evidence.
- Project ID/number remain correct; Functions inventory remains empty. Candidate SHA-256 remains `9629f7ba61c7fc10b9446c52f6a406dc0c3ada04956333d4a1bc89b65105e8b4`; prepared upload SHA-256 remains `7b2213ea88b87ca3b292706e454b6c5ffc6792230697f72979adc3fc83cd99d1`.
- Firestore release remains deny-all ruleset `aa4be7e8-ce25-44d1-afd8-c10654658bab`; Storage release remains deny-all ruleset `f0786fa3-4195-4c87-93ed-bde65612a8c0`. Runtime account is active and retains the approved custom-role binding.
- Installed Firebase CLI 15.34.1 source `lib/deploy/functions/prepare.js`, `ensureAllRequiredAPIsEnabled`, unconditionally ensures Cloud Run, Eventarc, Pub/Sub, and Storage for any Gen 2 endpoint, then calls service-identity generation for Pub/Sub and Eventarc. Cloud Run, Pub/Sub, and Storage are enabled; **`eventarc.googleapis.com` is disabled**. Thus another API enablement would be required by this CLI path even for callable-only deployment. This was discovered by source inspection and enabled-service listing, without deploy or dry-run.
- Bounded Admin Activity evidence shows Google-managed IAM additions during/after the interrupted attempt: at `2026-11-08T18:00:23.841395Z`, `roles/editor` was added for `serviceAccount:519076598217@cloudservices.gserviceaccount.com`; at `2026-11-08T18:06:48.657937Z`, `roles/firebasemods.serviceAgent` was added for `serviceAccount:service-519076598217@gcp-sa-firebasemods.iam.gserviceaccount.com`. Both events identify `service-agent-manager@system.gserviceaccount.com`. The latter is consistent with Extensions API service-agent provisioning; causality beyond the audit metadata is not asserted. These additions require owner disposition under the no-new-IAM boundary; no corrective IAM mutation was attempted.

**Outcome: G4 remains BLOCKED; no deployment resumed and Authorization B remains ineligible.** Required scoped decision: whether to authorize Eventarc API enablement and associated service-identity provisioning, and accept/review the two recorded Google-managed IAM additions. Any resulting new IAM requirement must be reviewed before execution; no broad IAM authorization is inferred. Application code, dependencies, Rules, App Check, and unrelated work were preserved.

## 2026-11-09 — Explicit owner exception and authorized continuation

The owner explicitly approved retaining the existing Google-managed `519076598217@cloudservices.gserviceaccount.com` project `roles/editor` binding and `service-519076598217@gcp-sa-firebasemods.iam.gserviceaccount.com` project `roles/firebasemods.serviceAgent` binding for this debug-only staging pilot. The owner authorized enabling exactly `eventarc.googleapis.com`, standard Eventarc service-identity provisioning with `roles/eventarc.serviceAgent`, and Pub/Sub service-identity provisioning with `roles/pubsub.serviceAgent` if required. No additional API or IAM role is authorized. Authorization A continues for the exact three Functions and dedicated runtime account; Authorization B remains conditional on complete deployment-security verification. This supersedes the immediately preceding approval checkpoint, without changing the remaining exclusions.

Fresh credential/identity and artifact checks passed. Eventarc enablement completed successfully. The read-only API comparison against the captured before-state showed exactly the Eventarc addition and no removals. Eventarc and Pub/Sub service-identity generation returned their expected project service-agent identities. The immediate project IAM comparison showed no additions or removals; provisioning success does not imply a verified role grant. Runtime custom-role permissions and the isolated source files matched the approval. Both deployed Rules releases remained the same deny-all rulesets. The scoped three-Function deployment was then resumed once; actual outcome and subsequent verification are recorded below when available.

### Actual deployment result and final stop

One scoped deployment continuation ran from the verified isolated candidate under Node `v22.23.4` and Firebase CLI `15.34.1`. All three create operations succeeded. The CLI subsequently exited **1**, reporting that Functions were successfully deployed but it could not set up an Artifact Registry cleanup policy in `us-central1`. No `--force`, artifact-policy command, deployment retry, rollback, or corrective mutation followed. Read-only repository metadata confirms `gcf-artifacts` exists and has no cleanup policy configured.

Read-only Function and Cloud Run verification confirmed exactly the following three Gen 2 Functions, all `ACTIVE`, runtime `nodejs22`, region `us-central1`, dedicated runtime identity `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com`, and build identity `519076598217-compute@developer.gserviceaccount.com`:

| Function | Ready revision |
|---|---|
| `createStudentRegistration` | `createstudentregistration-00001-jab` |
| `getMyStudentProfile` | `getmystudentprofile-00001-vak` |
| `ensureMyTier1Qr` | `ensuremytier1qr-00001-seb` |

Each latest-created revision equals its latest-ready revision. Each service policy contains exactly `allUsers` with `roles/run.invoker`. All Function labels report callable deployment by Firebase CLI and Function hash `b1dfb174032205eb9187b4295029af7f38265358` (the endpoint deployment hash, not the candidate ZIP SHA-256 or CLI source hash). Cloud Build `5ae67f58-0857-4236-b8d8-a591b6772673` succeeded under the approved Compute build identity.

Final security/scope checks found two **unapproved changes**, so Authorization B was not activated:

1. Enabled APIs increased by `eventarc.googleapis.com` (approved) **and `cloudbilling.googleapis.com` (not approved)**, with no removals. Admin Activity records show Cloud Billing API enablement under `dev.guntang@gmail.com` at `2026-11-08T19:44:46.540088Z` and `19:44:47.563687316Z`. Installed CLI `lib/gcp/cloudbilling.js` calls `ensureApiEnabled.ensure` with silent mode; the earlier bounded prerequisite review missed this helper path. No separate Cloud Billing API enablement command was issued by the operator workflow.
2. Project IAM comparison found exactly one added binding, **`serviceAccount:service-519076598217@gcp-sa-artifactregistry.iam.gserviceaccount.com` → `roles/artifactregistry.serviceAgent`**, and no removed bindings. Admin Activity attributes this addition at `2026-11-08T19:45:05.846640Z` to `service-agent-manager@system.gserviceaccount.com`. This Google-managed binding is outside the explicit Eventarc/Pub/Sub role exception. No manual IAM grant was issued.

Firestore and Storage remain on the same deny-all rulesets recorded above. Extensions inventory remains empty. No App Check change, application-code/dependency change, commit, push, synthetic account creation, callable acceptance invocation, or application-data access was performed in this continuation. Synthetic acceptance and device/offline-scanner checks are **NOT RUN**; zero test-owned resources exist and no synthetic cleanup was needed. The conditional 60-minute test window never started.

**Final outcome: three Functions deployed, but G4 remains BLOCKED and deployment command exit is 1.** Required owner disposition is limited to the newly enabled Cloud Billing API, the Artifact Registry service-agent binding, and whether to retain the absent artifact cleanup policy or separately authorize an exact repository cleanup policy. Do not redeploy merely to address the CLI exit. Do not disable services, remove bindings, or configure deletion policies without a scoped decision. No changes beyond the observed automatic effects were attempted.

## 2026-11-09 — Final scoped dispositions and Authorization B execution

The owner explicitly approved retaining the already-enabled Cloud Billing API, the existing Artifact Registry service-agent binding, and the temporarily absent artifact cleanup policy. This does not permit billing-account/payment changes, other API/IAM changes, image deletion, or repository policy changes. Artifact image accumulation can incur storage charges; a scoped retention-policy/cost review remains outstanding. The earlier CLI exit **1** remains recorded as a **post-deployment artifact cleanup-policy failure**, not a Function create failure. No redeployment was performed.

Fresh read-only verification passed for exact active project ID/number, exactly the three approved Gen 2 Functions, `ACTIVE` and ready states, unchanged revisions, Node.js 22, approved dedicated runtime and Compute build identities, and exactly per-service `allUsers` / `roles/run.invoker` policies. The runtime remains keyless with only the approved custom-role binding and exact three Firestore permissions. Compared with the saved pre-Eventarc baseline, enabled API additions are exactly Eventarc and Cloud Billing, and IAM differences are confined to the approved exceptions. Both artifact ZIP hashes match. The deployed source archive was independently read and all nine source entries match the approved CLI upload byte-for-byte. Both deny-all Rules releases are unchanged; Extensions inventory is empty; Firestore, Storage, and Identity Toolkit App Check services remain `UNENFORCED`.

Billing verification found an enabled current association and no billing-association mutation in the bounded Admin Activity window beginning `2026-11-08T00:00:00Z`. The previous reports did not retain a historical billing-account identifier, so this is audit-supported continuity rather than a direct comparison with a retained historical account ID. A hash of the current association was captured locally for the end-of-test comparison without exposing billing-account details.

Authorization B began only after these checks passed. Sanitized test and cleanup results follow when execution completes.

### Hosted synthetic acceptance results — completed

**29/29 recorded automated checks passed; zero functional/security checks failed.** This count includes six initial path-absence checks and three checks that the auth-only account acquired no documents. Two disposable synthetic accounts were used, with fictional data only. The functional check sequence took 32 seconds; diagnosis and exact cleanup completed within the same authorized 60-minute session. No replacement account or deployment was attempted.

| Check group | Actual result |
|---|---|
| Firebase Authentication | Synthetic sign-up succeeded for two accounts; password sign-in again returned the same student identity. |
| Unauthenticated callable access | All three Functions rejected unauthenticated requests with `UNAUTHENTICATED`. |
| Registration | Fictional 17-year-old registration returned `pending_guardian`; identical retry returned the same result. |
| Owner profile | Authenticated own-profile retrieval returned the expected name/status and only approved allowlist fields. |
| Auth-only second account | Own-profile retrieval returned `NOT_FOUND`; QR creation returned `FAILED_PRECONDITION`; no profile/acknowledgment/QR documents appeared for it. |
| Cross-account and malformed requests | Both profile and QR endpoints rejected supplied foreign UIDs and unexpected fields with `INVALID_ARGUMENT`. Ownership stayed bound to the authenticated UID. |
| QR | Exact response/privacy shape passed; opaque payload matched the expected format; repeated responses matched in memory; signing in again preserved the same QR. No raw QR or token was logged. |
| Direct Firestore client access | Reads of the three student test paths and a direct profile write were denied with HTTP 403. |
| Cleanup | Exactly three test documents and two test Auth users deleted; all five exact resources independently verified absent. |

### Exact test-owned resource accounting and cleanup

`S` denotes the synthetic student UID; `A` denotes the second auth-only UID. Full UIDs and emails are intentionally omitted under Authorization B's evidence/privacy contract. The temporary exact UID/path record was retained only until absence verification and then deleted.

| Resource | Created | Cleanup evidence |
|---|---:|---|
| Firebase Auth user `S` | 1 | Exact user lookup proved run ownership; exact deletion succeeded; subsequent lookup returned no user. |
| Firebase Auth user `A` | 1 | Exact user lookup proved run ownership; exact deletion succeeded; subsequent lookup returned no user. |
| `studentProfiles/{S}/acknowledgments/tier1-registration-v1` | 1 | Verified affirmative acknowledgment and matching actor UID, deleted first, then exact GET returned 404. |
| `studentProfiles/{S}` | 1 | Verified fictional name, age, and status, deleted second, then exact GET returned 404. |
| `studentQrCredentials/{S}` | 1 | Verified expected QR shape in memory, deleted third, then exact GET returned 404. |
| Corresponding profile/acknowledgment/QR paths for `A` | 0 | Exact GETs verified absence before and after tests; no documents were created or deleted for `A`. |

The first cleanup pass performed **zero deletions** because the admin Identity Toolkit ownership lookup returned HTTP 403. Systematic diagnosis reproduced the request with and without `x-goog-user-project: resqme-943ee`: the omitted-header request returned `PERMISSION_DENIED` / `SERVICE_DISABLED`; the header-present request returned 200 for the same operator and exact test UID. This was a request quota-project attribution issue, not an application authorization defect or missing project IAM grant. No API enablement, IAM change, credential recreation, or configuration mutation was used to resolve it.

Before cleanup resumed, exact UIDs were checked against the run-only ownership record, synthetic email format, and Auth creation timestamps after the fresh preflight. All three existing documents were verified as this run's fictional records. Cleanup then deleted only those exact documents/users, verified absence, and removed the ephemeral UID/path record. The initial cleanup failure and its resolution remain recorded; final cleanup is PASS. No raw test-response logs, credentials, or QR values were retained in the report.

### End-of-session security verification and final status

Fresh post-acceptance checks confirmed:

- Project IAM bindings and enabled APIs are exactly unchanged from the approved pre-test snapshot.
- The billing-account association hash and `billingEnabled` state are unchanged across this session. Historical continuity before this session is supported by the bounded audit evidence described above, not an unavailable historical identifier snapshot.
- Firestore/Storage Rules releases and App Check service enforcement are unchanged.
- Exactly the three approved Functions remain `ACTIVE`, Gen 2; their independently verified identities, revisions, and invoker policies are recorded above.
- Cleanup verified five exact resources absent; no test-owned hosted resources remain. No unrelated application record/account was accessed or changed.

**Final G4 status: PASS for the authorized hosted backend synthetic acceptance, including final cleanup and security verification. Full Tier 1 end-to-end/device acceptance is not complete:** Splash/Terms/Privacy, emergency dashboard, first-aid library, hotlines, DRRM guidance, mobile scanner, registration/sign-in UI, My Profile/My QR UI, logout/login UI, and offline-scanner device behavior were not exercised by these REST tests. They remain `NOT RUN`; backend success is not device acceptance.

Outstanding nonblocking staging items: the owner-accepted missing artifact cleanup policy may accumulate billable image storage and needs later cost/retention review; the original CLI exit remains **1** for that post-deployment policy failure. Previously accepted staging risks remain: public callable transport, unenforced App Check, and broad existing build/Google-managed identities. No redeployment, policy/deletion change, billing-account change, new IAM/API change, application/dependency change, commit, or push occurred during this final acceptance session.

## 2026-11-10 � Fresh Eventarc authorization verification and stop

The owner authorized the exact Google-managed `roles/editor` binding for `serviceAccount:519076598217@cloudservices.gserviceaccount.com`, the exact Firebase Mods service-agent binding, Eventarc API enablement, and standard Eventarc/Pub/Sub service-identity initialization with their service-agent roles. No broader API or IAM changes were authorized.

Fresh read-only checks confirmed active Firebase CLI identity `dev.guntang@gmail.com`, gcloud operator identity `dev.guntang@gmail.com`, project `resqme-943ee` / `519076598217`, `FIREBASE_TOKEN` and `GOOGLE_APPLICATION_CREDENTIALS` unset, standard ADC absent, and Firebase CLI 15.34.1. The approved runtime candidate and prepared upload SHA-256 values still match `9629f7ba61c7fc10b9446c52f6a406dc0c3ada04956333d4a1bc89b65105e8b4` and `7b2213ea88b87ca3b292706e454b6c5ffc6792230697f72979adc3fc83cd99d1` respectively.

`eventarc.googleapis.com` and `pubsub.googleapis.com` are enabled. The authorized Cloud Services Editor, Firebase Mods, Artifact Registry service-agent, and ResQMe runtime custom-role bindings are present; the runtime role still has exactly `datastore.databases.get`, `datastore.entities.get`, and `datastore.entities.create`. The Eventarc and Pub/Sub service-agent bindings are absent. A scoped Service Usage `generateServiceIdentity` request was issued for Eventarc; its long-running operation status request returned HTTP 400, and no Eventarc or Pub/Sub role binding appeared in the subsequent IAM read. Identity existence could not be independently established because direct service-account metadata reads returned HTTP 403. The authorization boundary was not expanded and no manual role grant was made.

No API enablement command, Function deployment/redeployment, synthetic test, IAM grant/removal, Rules change, App Check change, or artifact-policy change was performed. The enabled API set remained at 56 services on final read. Exactly the three approved Functions remain `ACTIVE`, Node.js 22, on the approved runtime identity; each Cloud Run invoker policy contains exactly `allUsers` with `roles/run.invoker`. Firestore and Storage still point to deny-all rulesets `aa4be7e8-ce25-44d1-afd8-c10654658bab` and `f0786fa3-4195-4c87-93ed-bde65612a8c0`. All four App Check enforcement services remain `UNENFORCED`.

**Disposition: stop before any further mutation.** The earlier deployment remains in place; its CLI exit code remains 1 for the post-deployment Artifact Registry cleanup-policy failure, with the three Functions independently verified healthy. No deployment retry or new Authorization B session was started. The current Eventarc identity initialization and exact service-agent bindings remain unverified/incomplete; resolve this through the already authorized identity-provisioning operation and verify only the exact Eventarc/Pub/Sub bindings before considering any further G4 action. No commit or push was made.

## 2026-11-10 — Eventarc/Pub/Sub service-agent polling diagnosis (read-only)

This diagnostic supplements the preceding execution note. It does not alter the earlier **G4 hosted synthetic acceptance PASS (29/29 checks, exact cleanup verified)**. The service-agent initialization issue is tracked separately and does not retroactively invalidate that completed acceptance.

### Trigger type and current deployed impact

Fresh `gcloud functions describe --v2` metadata for exactly `createStudentRegistration`, `getMyStudentProfile`, and `ensureMyTier1Qr` reports all three `ACTIVE`, `nodejs22`, with a service URI and the approved `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` identity. Each has Firebase CLI label `deployment-callable=true`; none has an `eventTrigger`. These are HTTPS callable Functions, not Eventarc-triggered Functions. The per-service Cloud Run invoker policy remains `allUsers` → `roles/run.invoker` as already verified. Firebase's callable protocol defines callable Functions as HTTPS triggers. [Firebase callable protocol](https://firebase.google.com/docs/functions/callable-reference)

Therefore, absent Eventarc/Pub/Sub service-agent bindings do **not** affect invocation or health of these already deployed callable Functions, and no redeployment is indicated. Eventarc's service agent and Pub/Sub's service agent are relevant to Eventarc/Pub/Sub event-driven resource creation or workloads and future deployment prerequisite paths; no Eventarc trigger, Pub/Sub topic, or subscription was created by this diagnostic.

### Service-agent identities and binding comparison

Official Google Cloud IAM documentation lists Eventarc as `service-519076598217@gcp-sa-eventarc.iam.gserviceaccount.com` with `roles/eventarc.serviceAgent`, and Pub/Sub as `service-519076598217@gcp-sa-pubsub.iam.gserviceaccount.com` with `roles/pubsub.serviceAgent`. Google documents automatic service-agent role grants on creation and warns against assigning service-agent roles to non-service-agent principals. [Google Cloud service agents](https://cloud.google.com/iam/docs/service-agents)

Read-only project IAM policy comparison confirms both exact principal/role bindings are absent. Direct `iam.serviceAccounts.get` reads for the two principals return HTTP 403, so their status is **existence cannot be verified with current permissions**; it is not evidence that either account is confirmed absent. The confirmed state is thus “binding absent; account existence indeterminate,” not “service account confirmed absent” and not “account exists but binding absent.” Other approved IAM bindings, including the runtime custom-role binding and previously owner-accepted Google-managed bindings, remain as recorded above.

### Why operation polling returned HTTP 400

Read-only calls to the documented Service Usage `v1beta1.operations.list` endpoint, with the exact project service parent and quota-project header, returned this sanitized error: `ListOperations is not supported.` The structured error is HTTP 400 / `INVALID_ARGUMENT`, `ErrorInfo.reason=UNSUPPORTED_NAMED`, domain `serviceusage.googleapis.com`, RPC `ListOperations`. A v1 path returned the same result. Thus the observed polling failure is because Service Usage does not support listing operations in this environment/API surface; it is **not** evidence that the identity-generation operation itself failed or completed. The operation metadata/status cannot be retrieved with the available read-only method. The operation resource name was not captured for an authorized direct GET, and no further operation polling or identity generation was attempted. [Service Usage operations list reference](https://cloud.google.com/service-usage/docs/reference/rest/v1beta1/operations/list)

### Disposition and minimal follow-up

No API, IAM, Rules, App Check, Function, test account, application-data, or artifact-policy change occurred during this diagnostic. Eventarc and Pub/Sub APIs remain enabled; the three callable Functions remain healthy. The earlier CLI exit code **1** remains accurately attributed to the post-deployment Artifact Registry cleanup-policy setup failure. Missing cleanup policy and its storage-cost consideration are unchanged.

To resolve service-agent status, an operator with appropriate read-only IAM permissions must inspect the exact two service-account resources or capture/query the original generation operation by its exact operation name. If an account exists but its approved binding is absent, the minimal IAM change would be exactly the corresponding Google-managed service-agent binding(s) authorized previously; if account creation/role provisioning did not occur, the minimum corrective action is to use the already authorized Google service-identity initialization path, then verify only those exact bindings. This diagnostic does **not** establish which branch applies, and does not authorize a new retry or manual grant. If a corrective mutation is still needed after the identity state is established, obtain/rely on separate owner authorization for that exact action before applying it. No changes are needed for the currently deployed callable Functions.