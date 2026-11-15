# ResQMe Tier 2 eligibility correction — deployment proposal

**Date:** 2026-11-16. **Status: PREPARED, NOT AUTHORIZED FOR DEPLOYMENT.** No hosted inventory, Firebase CLI, deployment, device operation, commit or push was performed during preparation. Existing local changes remain intact.

> **Owner authorization received 2026-11-16:** one scoped local commit and one controlled seven-Function staging deployment are approved conditionally on every mandatory preflight check passing. This supersedes the proposal's earlier approval-pending language. No push, device acceptance, synthetic account/data creation or automatic rollback is included. Execution results and the resulting commit SHA will be appended below; approval is not evidence that deployment occurred.

## Target and exact update allowlist

Project `resqme-943ee`, number `519076598217`; staging only. Generation 2 HTTPS callables, `us-central1`, Node.js 22. Runtime account: `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com`. Preserve existing build identity/permissions, Rules and App Check posture. No new IAM/API change is authorized.

| Function to update | Reason |
|---|---|
| `enrollTier2Device` | Validate trusted school, matching medical revision and guardian eligibility in enrollment transaction |
| `issueTier2Challenge` | Apply the same authoritative checks when creating a challenge |
| `readMyTier2Record` | Apply the shared policy and guardian read in the proof-consumption transaction; reject missing authentication normally |
| `readMyTier2WithPassword` | Apply the same eligibility policy to the password-authorized medical read, retaining its rate/recency limits |
| `ensureMyTier1Qr` | Imports the changed shared eligibility module; preserve separate canonical credential/lookup checks and fail-closed guardian validation |
| `resolveTier1Qr` | Same shared eligibility dependency; public result remains only `{active:boolean}` |
| `replaceMyTier1Qr` | Same dependency; preserve rotation/revocation and eligibility behavior |

The last three functions must accompany the shared-policy change: invalid guardian dates and empty guardian identities now fail closed consistently. Four direct Tier 2 updates alone would leave different QR/medical eligibility implementations deployed.

**Excluded:** `createStudentRegistration`, `getMyStudentProfile`, `completeMyMedicalRecord`, `getSchoolReviewCandidate`, `approveStudentQr`, `revokeStudentQr`, `revokeMyTier2Device`, `saveMySyntheticMedicalRecord`, `clearMySyntheticMedicalRecord`. The source entrypoint exports 16 Functions; the prepared package exports only the seven above. `revokeMyTier2Device` imports the shared module but uses unchanged recent-auth helpers, not the corrected eligibility guard; its behavior does not require updating. Revoking one's device must remain available even after losing eligibility.

No Firestore/Storage Rules, indexes, Hosting, Auth provider, App Check, Extensions, API enablement, IAM or artifact-cleanup deployment is included. No account/data mutation or acceptance invocation is authorized by a deployment approval alone.

## Reviewed local changes and validation

Baseline `main` / `7ea3b1f0813893a64f26f1c4df8a7f6818310979`. Review covered the six changed production modules, their transitive callers and the corrected tests. The eligibility guard now consumes authenticated UID plus trusted guardian data, uses the existing student policy shared with QR, and fails closed. Reads/writes are transactionally grouped. Response allowlists, signature binding, 60-second one-use challenges, recent-auth windows and password limits remain unchanged.

Latest completed verification before packaging: Node 22.23.4 `npm test` **150/150**; full Flutter **154/154**; Flutter analysis clean; TypeScript build and whitespace checks passed. Those are local results, not hosted/device acceptance. Preparation additionally loaded the packaged entrypoint under Node 22 and verified exactly seven Gen 2 callable definitions with the dedicated runtime identity. No handler was invoked. No repeat full suite was needed because preparation did not change product/test source.

A fresh TypeScript compilation into the protected preparation directory also matched every packaged handler/helper module byte-for-byte. All 23 current source fingerprints and all 15 staged artifact entry hashes were independently rechecked. The narrowed index is the documented packaging exception, not an unnoticed source substitution.

## Identified deployment artifact

Protected local preparation directory:

`C:\Users\Mj\AppData\Local\Temp\ResQMe-Tier2-Deploy-Prep-838e519f5afb46229b7f09b30493fce0`

- Candidate archive: `resqme-tier2-seven-functions-candidate.zip`
- **SHA-256:** `cc00be5f9f0795480daeae4b185f0ec564f43ecea3add458425d5023bb5fea29`
- 15 files: Functions-only root `firebase.json`, production package/lock, and 12 compiled runtime modules including the seven-export index.
- `artifact-manifest.json` in that directory records exact entry hashes and all source fingerprints. It is outside the deployment archive.
- Handler/helper JavaScript is copied byte-for-byte from the tested compiled output. The index is deliberately narrowed; package scripts/dev dependencies are omitted from the deployment package root. Existing runtime dependencies and lock resolutions are preserved; unused lockfile resolution metadata is retained, not installed as development dependencies by this production-only root.
- No `node_modules`, TypeScript tests, diagnostic endpoints, credentials, `.env`, application data, Rules, indexes, Hosting or device evidence is included. No existing profile was reused.
- The directory ACL is protected and limited to the current Windows account, SYSTEM and Administrators.

Deploy from a new isolated extraction of this archive, never unrestricted from the live repository. Before use, recheck archive hash, every entry/source fingerprint and exact exports; stop on mismatch. Firebase CLI may repackage ZIP metadata, so independently compare prepared upload source inputs/list/source hash before upload. An archive's identity does not by itself prove current cloud state or authorize execution.

## Git source identity recommendation

The verified backend changes are uncommitted. The owner's recommendation to use a scoped commit is retained; no commit was inferred from that recommendation while the earlier no-commit boundary remained in effect.

Proposed local commit scope: six production modules, `functions/package.json` (only regression-suite registration), the four backend test/fixture files, the scanner navigation test correction and directly related acceptance/plan/checklist/deployment documents. Review `git diff --cached` for this exact scope; do not stage arbitrary unrelated files or private artifacts. Record the resulting commit SHA in this manifest before any approved deployment. Do not push. A documentation-only commit changes Git identity but must not silently regenerate/substitute the approved payload. If any deployment input changes, rebuild/revalidate and present a new artifact identity before deploying.

The immutable candidate hash above makes this proposal reviewable now; commit creation is a separately stated requested action, not an operation already completed.

## Mandatory pre-deployment gates (not executed here)

After explicit approval covering scoped deployment and bounded metadata preflight:

1. Verify non-secret operator identity, presence-only credential overrides/token state and the approved credential/evidence handling posture. Never print credential stores/tokens or create ADC. Stop on a credential mismatch; do not re-enter prior remediation automatically.
2. Verify explicit project ID/number, current Functions inventory and all seven targets. Expect updates to existing G6 callables, not creation/deletion or a region/generation change. Capture current revisions, entrypoints, source/build metadata and service identities for recovery review. Historical G6's 13-function inventory is not a fresh fact.
3. Inspect installed Firebase CLI package metadata/source and require the reviewed 15.34.1 prerequisites. Read enabled APIs/service-agent IAM metadata before execution; no new API/IAM requirement is authorized. Do not run deploy/dry-run to discover prerequisites. Do not install or update tools.
4. Verify dedicated runtime custom-role contents and binding, retained build identity, callable service-level invoker policies, Rules releases/content and unchanged App Check. No policy repair, project-wide invoker grant or broad role is implied.
5. Reverify candidate/package/source hashes, exact seven exports, production dependencies, Functions-only config and expected region/runtime/account. Snapshot protected metadata and exact reviewed previous source/image/revision identifiers before mutation. Do not read application records during metadata preflight.

Stop on an unexpected identity, API, IAM, artifact, inventory, region, source or security result. Do not retry deployment to investigate a failure.

## Proposed command — DO NOT RUN before approval

From the isolated candidate root only:

```powershell
firebase.cmd deploy --config firebase.json --project=resqme-943ee --only functions:enrollTier2Device,functions:issueTier2Challenge,functions:readMyTier2Record,functions:readMyTier2WithPassword,functions:ensureMyTier1Qr,functions:resolveTier1Qr,functions:replaceMyTier1Qr
```

No `--force`, unrestricted `functions` selector, additional target, cleanup-policy creation or API/IAM change is approved by this proposal. Deployment can incur Cloud Build, image-storage and Functions/Cloud Run usage costs. Existing absence of an Artifact Registry cleanup policy remains a documented staging storage-cost issue; do not configure one or delete images automatically.

## Deployment verification and stop criteria

- Record the CLI exit code and per-Function result accurately. An exit 1 may reflect a post-deployment cleanup-policy failure; independently inspect all seven Functions rather than assuming success or failure and redeploying.
- Verify the seven updated callables are ACTIVE/healthy, Gen 2, Node 22, `us-central1`, with expected runtime/build identities, callable transport policies, revisions and uploaded source identity. Verify the excluded Function set and Rules/App Check/configuration metadata did not change.
- Partial success is not complete deployment verification. Stop, preserve the exact completed/failed inventory, and request direction. No automatic retry, deletion or rollback.
- Only after full deployment verification may a separately approved fictional-resource/device acceptance session begin. Use the existing physical checklist; APK installation, hosted writes and cleanup remain explicitly gated.

## Rollback / recovery procedure

1. Stop further deployment/testing on a mismatch; preserve original and resulting metadata, archive hashes, build/operation IDs and exact per-Function revisions. Do not delete Functions, accounts, data or images; do not disable APIs or modify IAM/Rules/App Check.
2. Determine whether the problem is packaging/runtime failure or an authorization defect using bounded metadata/log review. Do not capture sensitive request values. A reviewable forward fix retaining the eligibility protections is preferred.
3. `7ea3b1f`'s prior Tier 2 guard lacks the three required eligibility checks. It is **not a security-approved known-good rollback**. G6's historical artifact/revision alone also does not establish a safe rollback target.
4. Before rollback, identify a preserved, buildable reviewed artifact and exact target revisions; validate compatibility with current records and retain school/revision/guardian enforcement. If only the older weak artifact is available, stop for an explicit owner security decision; do not restore it automatically or label it safe.
5. Any code rollback, traffic/invoker change or forward-fix deployment requires separate authorization naming the exact artifact/Functions and accepted risks. Do not change Cloud Run traffic behind Functions management as an improvised rollback.
6. After an approved recovery, independently verify the same inventory, health, identity, invoker, Rules and source checks. Do not claim medical/biometric acceptance until the appropriate authorized tests pass.

## Approval requested

Review the scoped local commit proposal and the exact seven-Function package separately from device acceptance. Deployment approval must name this hash/allowlist and retain the mandatory stop conditions. Device install, fictional hosted resources and acceptance/cleanup are later separate decisions. No push is proposed.
