# ResQMe synthetic onboarding — proposed staging handoff

Prepared 2026-11-06. LOCAL ONLY: resources below were neither deployed nor remotely inspected during this milestone. Owner go/no-go is required before remote operations. Project must explicitly be `resqme-943ee`; no production destinations, Hosting, indexes, IAM, billing or Auth-provider changes are included.

## Proposed deployment scope

| Resource | Proposed effect |
| --- | --- |
| `saveMySyntheticMedicalRecord` (`us-central1`, Node 22 callable) | New authenticated pending-account and QA-entitled save; transactional revisions, replay receipts and canonical-contact compare-and-set |
| `clearMySyntheticMedicalRecord` (same region/runtime) | New authenticated QA-entitled clear; removes medical details, retains minimal revision/acknowledgment/retry metadata and registration contacts |
| `ensureMyTier1Qr` (same region/runtime) | New pending-account callable; transactionally issues/reuses one private 32-byte opaque unverified reference |
| Firestore Rules | Replace the project ruleset with reviewed local `firestore.rules`; owner-only private profile/medical/QR reads, client writes denied, QA entitlement access denied, default deny |

`createStudentRegistration` implementation is unchanged and excluded. Its deployed presence, version and compatible contract must be checked during authorized preflight. If absent/incompatible, stop for approval of an expanded manifest; deploying only the three new callables will not repair a missing registration backend.

Rules replacement affects the entire database. Capture and compare current remote Rules first; stop if unrelated permissions would be removed. Git history does not prove deployed compatibility.

After approval and successful preflight, the proposed commands are:

```powershell
npm.cmd --prefix functions run build
firebase.cmd deploy --project resqme-943ee --only functions:saveMySyntheticMedicalRecord,functions:clearMySyntheticMedicalRecord,functions:ensureMyTier1Qr,firestore:rules
```

These commands are documentation, not authorization. Record exact commit/artifact, deployed revisions and resulting Rules version when executed.

## Preflight and separate operator actions

- Verify Email/Password enablement, Firestore database/location, callable region/version, invoker access, App Check policy and deployment permissions. None were remotely verified here. Do not enable providers, relax enforcement, grant IAM or enable APIs implicitly.
- Confirm billing/Cloud Functions prerequisites without changing billing. Missing prerequisites require owner authorization. Preserve Node 22 target; local tests used Node 24.18.0. Node 22 runtime-parity validation remains pending.
- The Flutter client has no newly added App Check integration. If hosted enforcement requires tokens, stop for an approved debug-provider setup; do not disable enforcement to pass tests.
- Capture prior function artifacts/configuration and Rules backup. Verify staging isolation. School privacy/retention clearance is required before any real-data proposal; this pilot permits fictional records only.
- QA entitlement is an Admin-managed document, **not an environment variable**: `qaTesters/{syntheticTestUid}` with `enabled:true` and `syntheticOnly:true`. Missing documents deny medical writes. Clients cannot read/write entitlement. Creating or revoking a hosted entitlement requires a separately authorized operator action for the exact UID. Signup never grants it. Until then, Skip → QR → dashboard remains available. No hosted grants occurred locally.

## Synthetic smoke after approval

1. Guest opens dashboard/first aid/DRRM and the existing hotline placeholder without Auth.
2. Create invented age-17/age-18 accounts with controlled test addresses; confirm pending statuses, never approved.
3. Before QA grant, medical Save is denied clearly; Skip writes no medical record and reaches QR/dashboard.
4. After separately approved QA grant, test unknown/none-known/listed, required details, unchecked acknowledgments, minor acknowledgment, Save/update/clear and canonical contacts. Guardian authorization stays `not_verified`.
5. Concurrent QR calls and login/restart restore the same reference. Decode only `resqme:v1:<opaque reference>`; no personal/medical data, public verification or Tier 2 access.
6. Test logout/reset, partial registration recovery, offline/retry, stale edits and altered replay; no duplicate Auth/profile/QR or stale reminder after editing. Reset emails require a controlled synthetic inbox and hosted-test authorization.
7. Check owner/cross-user/anonymous access; then phone/tablet rendering, keyboard/text scaling, Back navigation and actual QR readability. Local tests/APK build do not establish native or hosted acceptance.

## Rollback

Restore captured prior function source/artifacts/config and Rules version after explicit rollback approval. Do not reset data, rotate QR references, overwrite profiles or delete records as part of code rollback. Disabling/removing new callables or revoking QA grants requires authorization for the exact resources; deletion is not implicitly approved. Retain minimal audit/retry data pending approved retention. Record serving revisions and smoke results after rollback.
