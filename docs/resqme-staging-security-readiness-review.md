# ResQMe staging security readiness review

Date: 2026-11-06. Decision: **NO-GO for application deployment or hosted testing.**

Baseline: `bb280ed05c0235e3e7c94dcd399e4cc1d8353833`. This review adds documentation only. No application/Rules changes, commits, remote writes, API enablement, hosted record reads, QA grants, account creation, IAM/billing changes, pushes or deployments occurred. Captured staging metadata from the preceding preflight is historical evidence, not a fresh remote verification. This report supersedes the earlier manifest's readiness assumptions; that document remains preserved.

## 1. Prioritized blockers

| Priority | Evidence | Consequence / required resolution |
| --- | --- | --- |
| P0 | Captured active Rules permit all reads/writes before `timestamp.date(2026,12,6)` | Approve a Rules-only lockdown first. Do not start hosted testing or grant QA entitlement while public rules remain active. |
| P0 | Public writes covered profile, QA, QR, acknowledgment and retry paths too | Existing documents cannot be assumed server-created or trustworthy. No compromise is asserted, and no hosted records were inspected. An authorized operator must establish a trusted baseline before callables are enabled. |
| P1 | Functions listing returned HTTP 403, `SERVICE_DISABLED`, service `cloudfunctions.googleapis.com` | API access must be separately authorized; disabled API does not prove absence of a deployed function. Registration availability/version is unknown. |
| P1 | Captured enabled-API list lacks the five services listed below | Explicitly approve required enablements/service-agent side effects; do not let deployment implicitly expand this scope. |
| P1 | Only Auth App Check service policy was captured; no Flutter App Check initialization or callable `enforceAppCheck` option exists | Decide and verify callable/Firestore App Check policy before hosted testing. If enforcement is required, a separately approved client/backend correction is needed. Do not disable enforcement silently. |
| P2 | Local executable is Node 24.18.0; target is Node 22 | Node 22 parity remains a predeployment validation gate. No runtime change or Node installation is proposed automatically. |
| P2 | No device acceptance evidence | Native phone/tablet, QR camera readability, lifecycle and hosted end-to-end acceptance remain later gates. |

Captured project: `resqme-943ee`, number `519076598217`, ACTIVE. Billing enabled; Email/Password enabled; Firestore Native `(default)` database in `nam5`. These are captured observations, not permission to change them. Callable region remains `us-central1`; this does not move the database.

## 2. Firestore dependency and compatibility matrix

Dependency search covered `lib/`, `functions/src/` and checked-in Rules. No other application/backend Firestore collection dependencies were found on those paths. This is not an inventory of hosted data or external clients.

| Path | Current app/backend dependency | Reviewed client access |
| --- | --- | --- |
| `studentProfiles/{uid}` | Registration callable creates; Flutter reads own profile; medical callable updates canonical primary contact | Owner get allowed; other/guest denied; all client writes denied |
| `studentProfiles/{uid}/acknowledgments/{version}` | Registration transaction creates privacy acknowledgment | Owner read allowed; other/guest and all client writes denied |
| `studentMedicalRecords/{uid}` | Save/clear callables mutate; Flutter reads own medical state/details | Owner read allowed; other/guest and all client writes denied |
| `studentMedicalRecords/{uid}/acknowledgments/{requestId}` | Medical transaction creates minimal acknowledgment metadata | Owner read allowed; other/guest and all client writes denied |
| `studentMedicalRecords/{uid}/requests/{requestId}` | Server-only idempotency digest/revision receipt | All client access denied |
| `studentQrCredentials/{uid}` | QR callable creates/reuses; Flutter reads own reference | Owner read allowed; other/guest and all client writes denied |
| `qaTesters/{uid}` | Medical transaction reads trusted `enabled` and `syntheticOnly` flags | All client access denied; Admin/operator-managed only |
| All other paths | No dependency found in the current application/backend | Default deny |

Flutter uses own-document reads, not broad collection queries. Passwords stay in Firebase Auth. Public first-aid and DRRM content is bundled locally; guest dashboard does not depend on Firestore. Hotline/scanner placeholders remain unchanged. Firebase Auth signup/login is not governed by Firestore Rules; profile creation uses a trusted callable, not direct client writes. Admin SDK transactions bypass Rules and still require their existing server validation.

Replacing the captured permissive Rules stops anonymous/cross-user reads and all direct client writes, including historical tools or external clients not represented in this repository. Server SDK access continues subject to IAM. Rules replacement does not delete data, repair forged documents, revoke previously downloaded data or prove historical record provenance. Owner reads also allow authenticated owners to see pre-existing matching-UID documents; broader compatibility therefore needs an approved inventory/review before selecting the owner-readable ruleset.

### Fresh local validation

- `firebase.cmd emulators:exec --config firebase.integration.json --project demo-resqme --only firestore "npm.cmd --prefix functions run test:rules"`: **4 passed, 0 failed/skipped, exit 0**; includes TypeScript build.
- Additional local-only matrix: **96 assertions, exit 0** across all eight path groups above (unknown path as eighth), for owner/cross-user/guest get, set, update and delete. Owner gets allowed only on the five documented owner-readable paths; every other operation denied. All fixtures were synthetic in the emulator.
- The existing suite does not separately assert owner-read existence of profile acknowledgments or server-only replay paths; the additional matrix covered these gaps without modifying source/tests.
- Evidence: `%TEMP%/resqme-security-rules-review.log` and `%TEMP%/resqme-security-rules-matrix.log`. The CLI reported shutdown but left its Firestore Java child listening. That child was identified by PID, creation time, exact emulator/project command, then stopped; port 8080 was verified free. No unrelated processes were stopped.

### Rules-only remediation proposal — separate approval required

1. Approve a rules-only release, separate from Functions/API enablement. Re-fetch the active release/ruleset metadata immediately before any authorized write; captured reference is `projects/resqme-943ee/rulesets/eeef0033-272a-49be-ba6a-5aef2486aa42`, released 2026-11-05T16:16:31Z. Preserve its source as incident/compatibility evidence, never as an automatic rollback target.
2. Preferred immediate containment when historical/external compatibility is unresolved: approve a temporary **deny-all client Rules** release. This blocks existing private account UI; public bundled emergency resources continue. A temporary rules file and emulator validation would be prepared only after owner selects this option; it is not implemented here.
3. Alternatively, approve the checked-in owner-readable/default-deny ruleset only after accepting its impact and resolving historical data trust/owner-read concerns. Current file SHA256: `A5B5F8A8F00F7E96E15C231B4DDF2895CF86D6F26969C4CB6A24AA71593E1B5B` (byte hash; recheck at deployment).
4. Authorized operator establishes a trusted cutover: inventory/review historical QA/profile/medical/QR/receipt documents under separately scoped access permission; revoke or quarantine suspect state only with exact change approval. No bulk deletion/reset is authorized. Existing client timestamps/status flags are not provenance evidence because they could have been forged under public writes.
5. Do not enable medical/QR callables against unreviewed historical authority. A documented clean baseline and freshly created post-lockdown synthetic UIDs are required. If that cannot be established, design a bounded server-controlled cutover/entitlement namespace correction and test it under separate implementation approval. Public Rules plus a future allowlist is not a secure baseline.

## 3. APIs and infrastructure authorization

The exact captured failure was `cloudfunctions.googleapis.com`, not Firestore or Auth. The following services were absent from the captured enabled list and require explicit enablement approval, with status rechecked at execution:

| API | Purpose |
| --- | --- |
| `cloudfunctions.googleapis.com` | Firebase Functions API access/deployment/inventory |
| `cloudbuild.googleapis.com` | Build function artifacts |
| `artifactregistry.googleapis.com` | Store built containers |
| `run.googleapis.com` | Run generation-2 callable infrastructure |
| `eventarc.googleapis.com` | Required by installed Firebase CLI generation-2 preparation, even though these functions have no event triggers |

Captured enabled supporting APIs include `pubsub.googleapis.com`, `storage.googleapis.com`, `logging.googleapis.com`, `firestore.googleapis.com`, `firebaserules.googleapis.com`, `identitytoolkit.googleapis.com` and `serviceusage.googleapis.com`; do not re-enable or alter them without need/approval. No scheduler, task, secret-manager or event-trigger feature is used by these callables; no blanket API enablement is proposed.

Installed Firebase CLI 15.34.1 source `lib/deploy/functions/prepare.js` invokes `ensureApiEnabled` for Cloud Run, Eventarc, Pub/Sub and Storage for generation 2 and generates Pub/Sub/Eventarc service identities. Deployment authorization must explicitly cover necessary managed service-agent/resource creation, build/storage/container resources and normal function revision replacement. IAM bindings, invoker-policy changes and service-account permissions must be inventoried/reviewed; stop for exact approval if missing, never grant broad roles opportunistically. Billing is enabled in captured metadata; no billing change is required or authorized.

Official references: [Firebase Functions setup and supported Node runtimes](https://firebase.google.com/docs/functions/get-started), [Cloud Run function build/deployment prerequisites](https://docs.cloud.google.com/run/docs/deploy-functions). The Eventarc requirement above is specifically verified from the installed Firebase CLI, rather than inferred from HTTP trigger needs.

## 4. Registration verification and callable contract comparison

After API access is approved, perform read-only inventory of generation-1 and generation-2 functions in `resqme-943ee`, explicitly locating `createStudentRegistration` in `us-central1`. Record generation, runtime, state, update time, build/source revision, service URI and invoker/App Check settings without printing secrets. List/describe does not invoke the function. An endpoint's presence alone is not proof of matching implementation. Compare its available source/artifact identity with the approved contract; unknown source identity remains unverified. Actual callable behavior requires separately authorized synthetic hosted smoke, not a read-only probe that creates a profile.

| Callable | Flutter request / expected response | Server compatibility |
| --- | --- | --- |
| `createStudentRegistration` | Auth first; name/age and approved optional contact fields, `noticeVersion:tier1-registration-v1`, `acknowledgmentAccepted:true`; then owner profile read | Local contract matches; derives pending status, null LRN, no password storage, identical retries idempotent and altered retry rejected. Hosted version unknown. |
| `saveMySyntheticMedicalRecord` | conditions/allergies `{state,details}`, versioned synthetic acknowledgment, minor flag, optional contact plus original snapshot, `expectedRevision`, `requestId`; then reload | Local schema/names align. Server checks Auth/project/pending/QA, derives minor from profile, rejects extra fields/stale values/replay changes; returns revision/status. |
| `clearMySyntheticMedicalRecord` | Only `expectedRevision`, `requestId`; then reload | Local schema aligns. Auth/pending/QA required; retains contacts/minimal metadata. |
| `ensureMyTier1Qr` | Empty object; expects opaque `payload`, `verificationStatus:unverified` | Local schema aligns; existing pending profile required; returns same reference under concurrency; no medical prerequisite or authorization grant. |

All use the existing selected Firebase app and `us-central1`; emulator is `demo-resqme` loopback, staging is explicitly `resqme-943ee`. No fallback or duplicate initialization was introduced. No new request/response mismatch was found. Prior registration metadata omissions remain recorded in the existing acceptance report; they are not silently repaired here.

## 5. Environment and App Check gates

`firebase.json` and `firebase.integration.json` specify `nodejs22`; `functions/package.json` specifies engine `22`, main `lib/src/index.js`; TypeScript emits that entry and exports all four callables. Current executable is Node 24.18.0; this review's Rules build passed under it. Node 22 parity is unverified, not a demonstrated application failure. Approve an existing Node 22 environment/CI validation, or separate installation if needed; do not change runtime target to match Node 24.

No source `enforceAppCheck`/global enforcement configuration or Flutter `firebase_app_check` initialization was found. Auth App Check was captured as UNENFORCED only; that does not establish Firestore or individual callable enforcement. Client reads and callable invocations may require different App Check arrangements. Auth, QA checks and owner-only Rules remain mandatory even with App Check. An enforced hosted policy requires approved Flutter debug-provider/token registration and compatible callable policy before smoke; do not silently disable it. Tokens/secrets must never appear in reports or Git.

## 6. Revised deployment manifest and gates

Every gate requires explicit project-owner authorization for its remote effects; NO commands in this report were executed remotely.

| Gate | Proposed resources/actions | Exit criterion |
| --- | --- | --- |
| G1 security containment | Firestore Rules only: selected temporary deny-all or reviewed owner-readable/default-deny release | Active ruleset metadata captured and verified; anonymous/client writes denied; no public-access rollback |
| G2 provenance/compatibility | Separately scoped operator inventory and exact remediation of historical authority; no automatic deletion, migration or QA grants | Trusted baseline recorded; unrelated consumers/collections handled; historical QA flags not blindly accepted |
| G3 API/environment preflight | Exactly five missing APIs above; required managed service identities after approval; read-only function/policy inventory; Node 22 parity | Required APIs ready, IAM/App Check/runtime policy reviewed; no unapproved settings changes |
| G4 application release | The three new callables below, plus conditional registration callable only when approved | Approved source revision/artifacts deployed; expected runtime/region/state and permissions verified |
| G5 synthetic smoke | Approved synthetic accounts, then separately approved exact-UID QA grant | Smoke checklist and later native acceptance recorded honestly |

G4 base scope: `saveMySyntheticMedicalRecord`, `clearMySyntheticMedicalRecord`, `ensureMyTier1Qr`, all generation 2, Node 22, `us-central1`, project `resqme-943ee`. No public verification endpoint, Hosting, indexes, Tier 2, school verification or guardian verification.

**Conditional expanded manifest:** if authorized inventory proves `createStudentRegistration` absent/incompatible, add deployment/replacement of that exact generation-2 Node 22 `us-central1` callable from the reviewed source. This fourth function requires separate explicit approval, including any generation conflict/migration discovered. Do not assume absence from the disabled API error. No delete-and-recreate or Auth provider change is included. Local source revision remains `bb280ed`; any technical correction requires a new reviewed revision and applicable tests before G4.

Rules are released separately under G1, not bundled blindly with G4. QA grants, users and records are excluded from the function deployment manifest and require G5-specific authorization. Current deployer IAM/resource inventory is not established; first-deployment infrastructure side effects must not be treated as already approved by local implementation.

## 7. Synthetic-only hosted smoke checklist — later authorization

- [ ] Verify security cutover and function versions first; use fresh fictional identities after lockdown, no historical authority reused without review.
- [ ] Guest dashboard, first aid, DRRM and existing hotline/scanner placeholders work without login or Firestore permissions.
- [ ] Register ages 17 and 18; notice starts unchecked, Auth-only credentials, correct pending states, null LRN, no school/guardian approval.
- [ ] Sign in/out and explicitly authorized password reset to controlled synthetic inbox; offline/partial Auth-profile recovery without duplicate account/profile/acknowledgment.
- [ ] Non-QA Save denied clearly; Skip writes no medical record and reaches persistent unverified QR/dashboard.
- [ ] Only after separate exact-UID QA grant: unknown/none-known/listed, bounds, minor acknowledgment, Save/update/contact CAS, clear, stale/replayed requests, reminder state.
- [ ] QR restart/retry/concurrency restores one opaque reference; decoded payload contains no personal/medical data and grants no Tier 2 access.
- [ ] Cross-user/guest read and client-write denial using only the approved test records; never probe arbitrary hosted students.
- [ ] Phone/tablet layout, text scale, keyboard, Back/lifecycle/account changes, actual QR camera readability and cold restart. Web/widget/APK evidence is not native acceptance.
- [ ] Record exact artifact/revisions, exit/results, failures and pending checks; cleanup or entitlement revocation only with approved exact resources.

## 8. Secure rollback / failure containment

Never restore the captured publicly permissive Rules, even temporarily. Keep reviewed restrictive Rules active; if owner-read compatibility or provenance is uncertain, move to a separately approved emulator-validated deny-all client ruleset. This intentionally limits private account functionality while leaving bundled guest emergency access.

For a failed function release, restore only a captured previously reviewed secure artifact/config if one exists and is compatible with the restrictive Rules. For first deployments with no secure predecessor, stop rollout and request exact authorization to disable invocation/revoke relevant QA entitlement or remove the new function; IAM changes/deletions are not preauthorized. Do not re-enable public Rules to make an old client work. Do not reset data, reissue QR, erase receipts, restore suspect records or disable unrelated APIs. Preserve incident evidence and minimal audit state; no automatic destructive rollback. Revalidate active Rules and affected function versions after any approved rollback.

## Recommendation

1. **Technically ready for review:** checked-in restrictive Rules and local callable contracts; existing four Rules tests and additional 96 checks pass. Not permission to deploy.
2. **Requires technical resolution:** historical authority/provenance baseline; external collection compatibility; Node 22 parity; App Check correction if required by chosen hosted policy; registration artifact compatibility after inventory.
3. **Requires owner authorization:** immediate Rules-only containment choice, exact API/service-agent prerequisites, scoped historical review/remediation, conditional fourth callable, application deployment and later synthetic users/QA grants. No remote changes are approved by this report.
4. **Requires later device acceptance:** native phone/tablet/QR readability and hosted end-to-end smoke. Current decision remains NO-GO.
