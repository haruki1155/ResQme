# ResQMe G6 — Active Tier 1 QR and Tier 2 deployment manifest (PROPOSAL)

> **STATUS: PROPOSAL — DEPLOYMENT NOT AUTHORIZED.** No Function, IAM, Rules, App Check, Auth, account, or Firestore document has been created or changed. Prepared 2026-11-12.
>
> **EXECUTED 2026-11-12.** The owner authorized decisions 1, 2 and 4; Route A was selected and the section 10 risks explicitly accepted. The IAM permission was added, all 13 functions were deployed, and the end-to-end test was run with disposable fictional data. **Results are in section 14. The disposable accounts and data have since been deleted and verified absent.** The 13 deployed functions and the added IAM permission remain in place by design for further testing.

Prepared for owner approval and, after approval, for the deployment operator.

## 1. Why this manifest exists

Two requested tests are currently impossible on staging:

- **Active Tier 1 QR scan** — a QR can be issued but never activated, and the scanner's server check endpoint does not exist, so every scan fails closed as `QR NOT ACTIVE`.
- **Tier 2 check** — all five Tier 2 callables are absent, and the Tier 2 gate additionally requires school approval plus a complete medical record, neither of which can be reached.

Both gaps share the same undeployed functions, so one manifest covers both.

## 2. Target

| Item | Value |
|---|---|
| Firebase project | `resqme-943ee` (project number `519076598217`) — staging only, never production |
| Generation / region / runtime | 2nd-gen HTTPS callable, `us-central1`, `nodejs22` |
| Runtime service account | `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` (exists, active) |
| Source | Current local worktree, **dirty**. A commit or an immutable archive hash must identify the exact deployed artifact before execution. |
| Rules, Storage, Hosting, indexes, Auth providers, App Check | **No deployment or change.** Firestore and Storage remain deny-all. |

## 3. Function scope

Deployed today — **verified by the 2026-11-12 read-only preflight** (section 13), not merely carried over from the G4 record: exactly `createStudentRegistration`, `getMyStudentProfile`, `ensureMyTier1Qr`, all `ACTIVE`, all at first revision.

| Function | Action | Required by | Why |
|---|---|---|---|
| `createStudentRegistration` | **Redeploy** | Both | Local contract now requires a 12-digit LRN and adds `enrollmentCode`/roster handling; deployed revision stores `lrn: null` |
| `getMyStudentProfile` | **Redeploy** | Both | **Deployed revision rejects any profile whose `lrn` is non-null** and omits `schoolAssignmentStatus`/`schoolVerificationOutcome` that the current client expects |
| `ensureMyTier1Qr` | **Redeploy** | Both | Deployed revision predates the `pending`/`active` + lookup-index + eligibility model; client now requires `pending` or `active` |
| `resolveTier1Qr` | New | Active QR | The scanner's server-authoritative active check |
| `replaceMyTier1Qr` | New | Active QR | "Replace QR" action on the My QR screen |
| `approveStudentQr` | New | Both | Sets `schoolApprovalStatus: 'approved'` — the only path to activation |
| `getSchoolReviewCandidate` | New | Both | The in-app reviewer screen loads the candidate before approving |
| `completeMyMedicalRecord` | New | Both | Sets `medicalStatus: 'complete'` and `medicalRevision` — required by both gates |
| `enrollTier2Device` | New | Tier 2 | Device key enrollment |
| `issueTier2Challenge` | New | Tier 2 | Nonce/challenge issuance |
| `readMyTier2Record` | New | Tier 2 | Biometric/signed-proof read |
| `readMyTier2WithPassword` | New | Tier 2 | Password fallback read |
| `revokeMyTier2Device` | New | Tier 2 | Disable biometric access |

**Total: 13 (3 redeploys, 10 new).**

**Explicitly excluded:** `saveMySyntheticMedicalRecord`, `clearMySyntheticMedicalRecord` (QA-entitled synthetic path — and records flagged `syntheticOnly` are *rejected* by both the QR and Tier 2 gates, so they cannot serve this test), and `revokeStudentQr`. Excluding revocation means school approval cannot be undone through a Function; cleanup must delete the disposable documents instead.

The repository entrypoint exports 15 names, so deployment must use an exact `--only` selector. Do not deploy unrestricted from `resqme/functions`.

## 4. IAM change required — the current runtime role is insufficient

**Verified 2026-11-12:** `projects/resqme-943ee/roles/resqmeFunctionsRuntime` (stage `GA`) holds exactly `datastore.databases.get`, `datastore.entities.create`, `datastore.entities.get` — confirmed live, not inferred. Eight of the thirteen functions perform document **updates**, which that role cannot do. Without this change the deployment will appear to succeed and then fail at runtime with permission errors.

| Function | `databases.get` | `entities.get` | `entities.create` | `entities.update` |
|---|---|---|---|---|
| `createStudentRegistration` | yes | yes | yes | only on roster auto-approval (Route B) |
| `getMyStudentProfile` | — | yes | — | — |
| `ensureMyTier1Qr` | yes | yes | yes | **yes** (pending to active) |
| `resolveTier1Qr` | — | yes | — | — |
| `replaceMyTier1Qr` | yes | yes | yes | **yes** (revoke old lookup, rotate credential) |
| `approveStudentQr` | yes | yes | yes (audit) | **yes** (profile) |
| `getSchoolReviewCandidate` | — | yes | — | — |
| `completeMyMedicalRecord` | yes | yes | yes (receipt) | **yes** (record and profile) |
| `enrollTier2Device` | yes | yes | yes | **yes** (`tx.set` on existing device) |
| `issueTier2Challenge` | — | yes | yes | — |
| `readMyTier2Record` | yes | yes | — | **yes** (consume challenge) |
| `readMyTier2WithPassword` | yes | yes | yes | **yes** (rate-limit counter) |
| `revokeMyTier2Device` | yes | yes | — | **yes** (status revoked) |

**Proposed change — one permission, nothing else:** add `datastore.entities.update` to `resqmeFunctionsRuntime`. No `datastore.entities.delete` or `.list` is needed: no handler deletes or queries documents. Do not broaden to `roles/datastore.user`. Do not touch the operator's Owner grant, the Compute default's Editor grant, or any service agent.

Residual risk, unchanged from G4 and now wider: the role is project-scoped and the Admin SDK bypasses Rules, so adding update extends project-wide document *modification* reach. Callable Firebase Auth checks and UID-derived ownership remain the only enforcement; both are present in every handler above.

## 5. School assignment — one decision needed

Activation requires `schoolAssignmentStatus: 'assigned'` **and** a `schoolId` matching the reviewer's school. `schoolId` is written **only** at registration from a roster match, and the roster lookup is keyed by `RESQME_SCHOOL_ROSTER_HMAC_KEY`, which **is not set** — there is no `functions/.env` and no `defineSecret` in source. Without it, every registration lands `unassigned` and can never be approved.

| | Route A — direct admin write (**recommended**) | Route B — roster infrastructure |
|---|---|---|
| Change | One authorized write setting `schoolAssignmentStatus`/`schoolId` on the disposable test profile | Provision a 32-byte-or-longer secret, wire it into the runtime config, seed `schoolRosterClaims/{hmac(lrn)}` |
| Added surface | One document field pair, removed at cleanup | A new secret in Secret Manager, a config change on `createStudentRegistration`, extra seeded documents |
| Exercises the real enrollment path | **No** — the roster/auto-approval path stays untested | Yes |
| Also needs | — | `datastore.entities.update` for the roster claim write, plus secret-access IAM |

**Decision recorded 2026-11-12: the owner selected Route A.** No roster secret, roster seeding, or `createStudentRegistration` config change is in scope; the roster/auto-approval enrollment path stays untested and remains a known gap for a later milestone.

Route A is the smaller, more reversible change and is sufficient for both requested tests. Route B is the right choice only if you specifically want roster auto-approval demonstrated.

## 6. Authorized staging data writes required

Beyond deployment, the test needs these — each requires your separate approval:

1. **Two disposable Auth accounts** — one fictional adult student (18 or older, so no guardian authorization is required) and one reviewer. `approveStudentQr` rejects self-approval, so the reviewer cannot be the student.
2. **`schoolReviewers/{reviewerUid}`** — `{ active: true, schoolId: '<test-school-id>' }`, matching `^[a-z0-9][a-z0-9_-]{1,63}$`. Client writes are denied by deny-all Rules, so this is an operator write.
3. **Route A only: `studentProfiles/{studentUid}`** — set `schoolAssignmentStatus: 'assigned'` and `schoolId` to the same value.

Fictional data only. The LRN must be 12 digits to pass validation — it can no longer be blank.

## 7. Proposed commands (documentation, not authorization)

Read-only preflight, to run first and compare against this manifest:

```powershell
gcloud.cmd projects describe resqme-943ee --format="value(projectId,projectNumber)"
gcloud.cmd functions list --v2 --project=resqme-943ee
gcloud.cmd iam roles describe resqmeFunctionsRuntime --project=resqme-943ee
gcloud.cmd firestore databases describe --project=resqme-943ee
firebase.cmd firestore:rules get --project resqme-943ee
```

Stop and re-approve if the project, inventory, region, runtime, role contents, or Rules differ from what is recorded here.

IAM change (after approval; export the prior role definition first):

```powershell
gcloud.cmd iam roles update resqmeFunctionsRuntime --project=resqme-943ee --add-permissions=datastore.entities.update
```

Build, test, then deploy with the exact selector:

```powershell
npm.cmd --prefix functions test
npm.cmd --prefix functions run build
firebase.cmd deploy --project resqme-943ee --only functions:createStudentRegistration,functions:getMyStudentProfile,functions:ensureMyTier1Qr,functions:resolveTier1Qr,functions:replaceMyTier1Qr,functions:approveStudentQr,functions:getSchoolReviewCandidate,functions:completeMyMedicalRecord,functions:enrollTier2Device,functions:issueTier2Challenge,functions:readMyTier2Record,functions:readMyTier2WithPassword,functions:revokeMyTier2Device
```

Record the exact commit/artifact hash, each deployed revision, each service's `serviceAccountEmail`, and every invoker binding created.

## 8. Test sequence after deployment

1. Register the fictional adult student in the app (debug build, `RESQME_BACKEND=staging`).
2. Apply the approved assignment write (Route A) and the reviewer document.
3. Reviewer signs in, opens the school review screen, loads the candidate, approves. Expect `schoolApprovalStatus: 'approved'`.
4. Student completes the medical form in-app. Expect `medicalStatus: 'complete'`, `medicalRevision: 1`.
5. Open My QR. Expect `verificationStatus: 'active'` and the "Active Tier 1 QR" heading.
6. Display that QR on a second screen and scan it with the device. Expect `QR ACCEPTED - TIER 1` / `ACTIVE RESQME QR`. **The QR image must not be saved or included in any report.**
7. Negative scan: re-scan the never-issued sample fixture. Expect `QR NOT ACTIVE`.
8. Tier 2 password path: reauthenticate and read. Expect only `conditions`, `allergies`, `primaryContact`. The password read requires auth within **120 s** and allows **5 attempts per 10 minutes**.
9. Tier 2 biometric path: enroll the device, then read. Requires biometrics enrolled on the TECNO CN5 and Android 9 or later; this path has never run on hardware, and the client collapses every failure into one generic message, so distinguishing a cancelled prompt from a missing enrollment needs device logs.
10. Optional: Replace QR, then confirm the old payload resolves inactive and the new one resolves active.

## 9. Resources created, and cleanup

Expected to exist after the test — all disposable, all to be removed:

- Auth users: student, reviewer (2)
- `studentProfiles/{student}` plus `acknowledgments/tier1-registration-v1` and `schoolApprovals/{requestId}`
- `studentMedicalRecords/{student}` plus `productionRequests/{requestId}`
- `studentQrCredentials/{student}`, `studentQrLookups/{sha256}` (2 if replace is tested)
- `tier2Devices/{student}`, `tier2Challenges/{challengeId}`, `tier2PasswordRateLimits/{student}`
- `schoolReviewers/{reviewer}`
- No `studentGuardianAuthorizations` document (adult student)

Verify each path's absence before creation and ownership before deletion. Delete in dependency order, leaf documents first, Auth users last, then re-verify absence. Deleting data is **not** part of a code rollback.

## 10. Residual risks to accept explicitly

**Decision recorded 2026-11-12: the owner explicitly accepted the public unauthenticated `resolveTier1Qr` endpoint and unenforced App Check for this debug-only staging pilot.** That acceptance does not extend to production, to real student data, or to any later milestone.

- **`resolveTier1Qr` is unauthenticated by design.** It performs no `request.auth` check, so once deployed it is a public endpoint. Its rate limit is an in-process map (30/min/IP) and `maxInstances: 4`, so the effective ceiling is roughly 120/min/IP and resets on cold start. It returns only `{active}` and never identity or medical data.
- **App Check remains UNENFORCED** and the Flutter client has no App Check integration. Abuse and attestation risk is unmitigated, now across 13 endpoints instead of 3.
- **Each callable gets `allUsers` plus `roles/run.invoker`** on its Cloud Run service — per service, never project-wide.
- **Cost:** 12 Gen-2 services, their builds, and Artifact Registry storage. Billing is enabled; confirm expected cost before approving.
- **The Compute default build identity retains project `roles/editor`**, carried over as an accepted staging-only risk.
- Deny-all Firestore/Storage Rules stay untouched, so Admin-SDK-backed callables remain the only data path.

## 11. Rollback

Restore the three previously serving revisions of the redeployed functions from captured artifacts. Deleting the ten new functions requires separate approval for the exact resources — deletion is not implicitly authorized. Remove `datastore.entities.update` from the custom role only after confirming no deployed function depends on it. Do not rotate QR references, reset data, or overwrite profiles as part of a code rollback. Record serving revisions and a post-rollback smoke result.

## 12. Owner decisions required

| # | Decision | Status (2026-11-12) |
|---|---|---|
| 1 | The 13-function deployment scope in section 3 | **OPEN** |
| 2 | Adding `datastore.entities.update` to `resqmeFunctionsRuntime` (section 4) | **OPEN** |
| 3 | Route A or Route B for school assignment (section 5) | **ANSWERED — Route A** |
| 4 | The two disposable Auth accounts and operator document writes (section 6) | **OPEN** |
| 5 | Explicit acceptance of the section 10 residual risks | **ANSWERED — accepted for staging** |

Until decisions 1, 2 and 4 are answered, no deployment, IAM change, account creation, or staging write is authorized. The read-only preflight was separately authorized and is complete.

## 13. Preflight execution record — read-only, 2026-11-12

Authorized scope: read-only metadata only. No mutating command was run. No credential or token was printed or stored.

| Check | Verified result |
|---|---|
| Project identity | `resqme-943ee` / `519076598217` / `ACTIVE` — matches the authorized target |
| Deployed functions (gen 2) | Exactly three, all `ACTIVE`, all updated `2026-11-08T19:46Z`: `createStudentRegistration`, `getMyStudentProfile`, `ensureMyTier1Qr`. The ten functions in section 3 are confirmed absent. |
| Region / runtime / identity | All three on `us-central1`, `nodejs22`, running as `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com` |
| Revisions | `createstudentregistration-00001-jab`, `getmystudentprofile-00001-vak`, `ensuremytier1qr-00001-seb` — all first revision, never updated since initial deployment |
| Runtime custom role | `resqmeFunctionsRuntime`, stage `GA`, permissions exactly `datastore.databases.get`, `datastore.entities.create`, `datastore.entities.get`. **`datastore.entities.update` is confirmed absent** — section 4 is a verified blocker, not a prediction. |
| Firestore database | `(default)`, location `nam5`, `FIRESTORE_NATIVE` |
| Firestore Rules | Release `cloud.firestore` → ruleset `aa4be7e8-ce25-44d1-afd8-c10654658bab` (updated 2026-11-06). Source fetched and read: `allow read, write: if false` on `/{document=**}` — **deny-all confirmed**, file name `firestore.containment.rules`. |
| Storage Rules | Release `resqme-943ee.firebasestorage.app` → ruleset `f0786fa3-4195-4c87-93ed-bde65612a8c0` (updated 2026-11-08). Source read: `allow read, write: if false` — **deny-all confirmed**. |
| Callable invoker policy | `ensuremytier1qr` grants `roles/run.invoker` to `allUsers`, confirming the per-service public-invoker pattern described in section 10 |

### Execution attempt, 2026-11-12 — owner authorized decisions 1, 2 and 4; blocked by tooling

The owner subsequently authorized the deployment, the IAM change, and the test-data provisioning. Execution began in the order "most reversible first" and halted at the IAM step:

| Step | Outcome |
|---|---|
| Rollback capture — prior role definition | **Done.** `resqmeFunctionsRuntime` exported before any change (etag `BwZfxvtO6gU=`, 3 permissions, title `ResQMe Functions Runtime`, description "Least-privilege Firestore permissions for approved ResQMe staging callables"). Held outside the repository. |
| Deployment credential check | **Done.** Firebase CLI authenticated as `dev.guntang@gmail.com`, the recorded deployment operator. |
| `firebase.json` hazard review | **Done.** It maps `"firestore": {"rules": "firestore.rules"}`, and that checked-in file is the **owner-read** policy, not deny-all. A bare `firebase deploy` would therefore replace the deployed deny-all ruleset. The exact `--only functions:` selector in section 7 is mandatory, not stylistic. No predeploy hook exists. |
| Source provenance | **Done.** Worktree is dirty and was **not** committed (unrelated feature work is uncommitted). Deterministic archive of `functions/src` + `package.json` + `package-lock.json` + `tsconfig.json`, 33 entries, SHA-256 `1fdb14110141f5acd9b7ce1479d8788276bc27b07c78dae7bccad29a19b0c9d0`, atop git `cd5d9f2a412e3bcb6aa501a5729824ea6685dc73` (dirty — the commit alone does not identify the artifact). |
| **IAM role update** | **BLOCKED.** `gcloud iam roles update … --add-permissions=datastore.entities.update` was refused by the agent harness's own permission classifier as a destructive action. No workaround was attempted: any alternative transport performs the identical mutation. The role is **unchanged** and still holds exactly its original three permissions. |
| Function deployment | **NOT ATTEMPTED — deliberately.** Deploying before the role is fixed would create ten new public endpoints of which eight fail at runtime on their first write, and their removal needs separate approval. That is a worse state than the current one, so the deployment was not started. |
| Test-data provisioning | **NOT ATTEMPTED.** Depends on a working deployment. |

The IAM command must therefore be run by the operator, or the agent must be granted permission to run it. Everything downstream of it is unchanged and ready.

Notes for the operator:

- The Rules read required an `x-goog-user-project: resqme-943ee` header because local Application Default Credentials have no quota project set. **No ADC or gcloud configuration was changed** to work around this; use the same header rather than running `gcloud auth application-default set-quota-project`.
- The local gcloud default project differs from the target, so every command above was explicitly pinned with `--project=resqme-943ee`. Keep that pinning for any later authorized command.
- Nothing in this preflight contradicts the manifest. Sections 3 and 4 are now evidence-backed rather than doc-derived, so no re-approval of the scope is needed on that account.
- Local supporting evidence from the same session: `npm test` in `functions` passed **90/90** (unit only, no emulator, no hosted call).

## 14. Execution results — 2026-11-12

Deployment: all 13 functions `ACTIVE` in `us-central1` on `nodejs22`, each running as `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com`. The Firebase CLI reported exit 1 on the Artifact Registry cleanup-policy step *after* a successful deploy — the same owner-accepted condition recorded in G4. `--force` was deliberately not used. Firestore and Storage Rules were not touched and remain deny-all.

IAM: `datastore.entities.update` added to `resqmeFunctionsRuntime`; title, stage and description unchanged; prior definition captured before the change (etag `BwZfxvtO6gU=`).

Source deployed: deterministic archive of `functions/src` + manifests, SHA-256 `1fdb14110141f5acd9b7ce1479d8788276bc27b07c78dae7bccad29a19b0c9d0`, atop dirty git `cd5d9f2a412e3bcb6aa501a5729824ea6685dc73`. The worktree was **not** committed.

| Check | Result | Evidence |
|---|---|---|
| Registration, redeployed contract | **PASS** | Profile `pending_review`, 12-digit LRN stored, acknowledgment `affirmativeAction: true` |
| `getMyStudentProfile` redeploy | **PASS** | QR screen loaded for a profile with non-null `lrn`, which the prior revision rejected |
| `getSchoolReviewCandidate` | **PASS** | Returned student name, `pending`, `manual_review` |
| `approveStudentQr` | **PASS** | Returned `schoolApprovalStatus: approved` |
| `completeMyMedicalRecord`, in-app form | **PASS** | `medicalStatus: complete`, `revision: 1`, `selfReported: true` |
| QR activation (`ensureMyTier1Qr`) | **PASS** | Screen showed "Active Tier 1 QR"; credential `active`. This is the behaviour the added update permission unblocked |
| Physical camera scan of the live active QR | **PASS** | TECNO CN5 showed "QR ACCEPTED - TIER 1" / "ACTIVE RESQME QR" |
| Negative control, never-issued payload | **PASS** | "QR NOT ACTIVE" / "Not confirmed active" |
| `resolveTier1Qr`, unauthenticated | **PASS** | `{active:true}` for the live payload, `{active:false}` for unissued |
| `replaceMyTier1Qr` rotation | **PASS** | Payload rotated; old payload resolves `false`, new resolves `true` |
| Tier 2 password path, in-app | **PASS** | Displayed only conditions, allergies, primary contact. No LRN, email, or QR payload |
| Tier 2 lock | **PASS** | Record cleared from the screen |
| `enrollTier2Device` + `issueTier2Challenge` | **PASS** | Device registered with EC P-256 key, `keyVersion: 1`; challenge bound to the exact uid/device/operation, unconsumed, 60 s expiry |
| Tier 2 biometric **read** (`readMyTier2Record`) | **NOT VERIFIED** | Requires a fingerprint on the device; the prompt went unanswered and the attempt was not retried before cleanup. The device does have 4 prints enrolled and a working crypto-bound sensor, so this is testable in a later session |

### Defects and observations

1. **Misleading Tier 2 error text (client, P2).** [tier2_authorization_repository.dart:92-104](../lib/features/medical/services/tier2_authorization_repository.dart#L92-L104) collapses every failure into "Password or biometric verification failed. Check your password and try again." During the test, enrollment had already succeeded and the password was correct — only the biometric prompt went unanswered — yet the user is told to check their password. Fix before any school demonstration.
2. **Three QR lookup documents existed for one student** (one active, two revoked) where two were expected. Issuance is still correct — only one lookup was `active`, and revoked lookups resolve inactive — but the extra revoked row suggests an additional issuance occurred during UI driving. Worth confirming that repeated `ensureMyTier1Qr`/`replaceMyTier1Qr` cannot accumulate orphaned rows in normal use.
3. **The registration privacy dialog's confirmation could not be attributed to a specific tap.** A device-side parse failed in that window and issued a stray tap at (0,0). The server recorded the acknowledgment with `affirmativeAction: true` under the student's own uid, so the record is genuine, but the exact confirming interaction is unaccounted for. Any future acceptance-evidence run should capture the dialog state immediately before and after the tap.
4. **UI automation caveat.** The device's accessibility bounds drift between dumps (an inset difference of roughly 113 px), so dump-then-tap in separate steps mis-targets adjacent controls. All driving must parse and tap within one operation; `scratchpad/uitap.sh` does this.

### Cleanup, verified

All disposable resources were removed after testing and verified absent: 15 Firestore documents (profile, medical record, QR credential, 3 QR lookups, 3 Tier 2 challenges, Tier 2 device, password rate limit, reviewer doc, acknowledgment, school approval, medical request receipt) and both Auth accounts. Post-cleanup reads returned `ABSENT` for every named path, 0 documents in each affected collection, and 0 users for both UIDs. Device app data was cleared. Local disposable artifacts (QR renderers, rendered QR pages, identities file, payload file) were deleted.

**Deliberately retained:** the 13 deployed functions and the added `datastore.entities.update` permission, so further testing needs no redeployment. Removing them requires separate approval per section 11.

### To resume testing

Re-provision with the same Route A sequence: register a fictional adult student in the app, create a reviewer Auth account, run `scratchpad/provision-g6.sh <studentUid> <reviewerUid>` for the two operator writes, approve via `approveStudentQr`, complete the medical form in-app, then verify activation. The only step needing a person present is the Tier 2 biometric prompt.
