# ResQMe bounded empty-baseline verifier design

Date: 2026-11-08. Status: PROPOSED � owner review before implementation. No hosted retry is authorized by this document. G2 remains blocked; G3/G4 remain unauthorized.

## Purpose and approach

Establish whether staging has any records requiring preservation, without retrieving document fields, Auth profile/credential fields, or Storage object contents. Stop at the first existing record; counts then mean observed lower bounds, never total counts. The owner has replaced full historical inventory with an empty-baseline check, not authorized remediation.

Use a small separate TypeScript verifier with injected HTTP/auth, immutable endpoint builders, and sanitized counters. Reuse the reviewed affirmative-email validator/security semantics, not the historical inventory runner or its query scopes. No new dependency, Cloud Function export, arbitrary URL option, endpoint override or automatic hosted script. Alternatives: manual Console inspection cannot reliably establish missing-parent coverage; running the historical inventory would collect unnecessary projected metadata.

## Two explicitly separate approvals

1. IDENTITY_ONLY: approve exact artifact/lock/runtime hashes, expected email and stable subject, existing ADC path/hash, run ID and UTC window. Permit only OAuth refresh and token-info requests. Print only match/claim-presence booleans and status; exit immediately. No Firebase project, database, Rules, Auth-user or Storage requests.
2. EMPTY_BASELINE: separately approve its compiled artifacts and canonical manifest digest plus the operations below. Reverify identity with the same constraints; use that one token without refresh, replacement or scope expansion. Identity-only success never advances automatically into baseline mode.

Identity: exact expected operator email/stable subject; email_verified must equal boolean true or string true; missing/false/unexpected/conflicting verification claims reject. Subject disagreement rejects. Require lifetime covering remaining run budget plus60s. Missing privately recorded subject/path/hash is a blocker, not a value to infer from an unapproved response. Adapter read-only behavior does not certify operator IAM least privilege.

## Fixed target and baseline

Project resqme-943ee; number519076598217; Firestore (default), FIRESTORE_NATIVE, nam5. Read-only metadata operations, before existence checks:
- GET https://firebase.googleapis.com/v1beta1/projects/resqme-943ee : request fields=projectId,projectNumber,state; require exact IDs and ACTIVE.
- GET https://firestore.googleapis.com/v1/projects/resqme-943ee/databases/(default) : fields=name,type,locationId; require exact target.
- GET https://firebaserules.googleapis.com/v1/projects/resqme-943ee/releases/cloud.firestore : fields=name,rulesetName,updateTime.
- GET https://firebaserules.googleapis.com/v1/projects/resqme-943ee/rulesets/aa4be7e8-ce25-44d1-afd8-c10654658bab : fields=name,source(files(name,content)); exactly one deny-all source with SHA256 7bff2de50c73415a3b12a6783f42ff621b1b04803ffc4e2634e6ba68e5d655f9. Rules source is configuration, not student content. Unexpected release/source stops.
Repeat release/source verification at completion. Never restore public Rules. Initial/final checks do not establish an atomic snapshot; operator must attest no concurrent hosted writers/administrative changes during the window. Otherwise no clean-baseline conclusion.

## Firestore: all nesting, names only

Base https://firestore.googleapis.com/v1/projects/resqme-943ee/databases/(default)/documents .
- POST {parent}:listCollectionIds, body {pageSize:100,pageToken?}, response fields=collectionIds,nextPageToken. Start at database documents root; collection IDs kept in memory only.
- For each collection: GET {parent}/{encodedCollectionId}?showMissing=true&pageSize=100&mask.fieldPaths=__name__&fields=documents(name,createTime,updateTime),nextPageToken&pageToken=... . No query ordering/filter with showMissing. This explicit reserved-name mask plus response fields prevents business fields from being returned; verify exact wire behavior using synthetic Firestore emulator sentinels before hosted approval.
- A returned entry with creation/update metadata is an existing document: increment observed count, stop with DATA_FOUND. No document get, field projections or content logging.
- A returned missing-parent reference has no creation/update metadata: recursively call listCollectionIds for that reference and traverse descendants. Do not treat a missing parent as an existing record or evidence its descendants are empty. Reject malformed metadata, foreign project/database names, invalid alternation, duplicates/cycles or unexpected fields.
- Complete every page and pending missing-parent traversal before declaring zero. A page token on an empty page still requires follow-up. All resource names and page tokens remain in memory and never enter output/errors.

## Authentication: existence only, tenants accounted for

- GET https://identitytoolkit.googleapis.com/v1/projects/resqme-943ee/accounts:batchGet?maxResults=1&fields=users(localId),nextPageToken . A single projected localId establishes existence; never output/store it. Do not request emails, passwords, password hashes, tokens or provider details. If empty but nextPageToken exists continue within limits.
- GET https://identitytoolkit.googleapis.com/v2/projects/resqme-943ee/tenants?pageSize={remainingTenantCapacity}&fields=tenants(name),nextPageToken . For each returned tenant under the exact project, call the same v1 accounts:batchGet at /v1/projects/resqme-943ee/tenants/{encodedTenantId}/accounts:batchGet with maxResults=1/identical fields (never a tenantId query on default accounts). Tenant names are memory-only. No tenant/config changes.
- Any user in default/tenant Auth yields DATA_FOUND and stops. Tenant-list permission/API failure yields INCOMPLETE, never assume tenants absent. Do not enable APIs or widen permissions.

## Storage: every project bucket, versions and soft-deleted data

- GET https://storage.googleapis.com/storage/v1/b?project=resqme-943ee&maxResults={remainingCombinedBucketCapacity}&projection=noAcl&fields=items(name,projectNumber,softDeletePolicy),nextPageToken,unreachable . Reject any bucket not assigned to project519076598217 or any unreachable result; no guessed default bucket.
- For each bucket: GET https://storage.googleapis.com/storage/v1/b/{encodedBucket}/o?maxResults=1&versions=true&projection=noAcl&fields=items(size),nextPageToken . No prefix/delimiter; includes live and noncurrent versions. Nonempty items establishes existence even size0; no object names, custom metadata, ACLs or download requests.
- When an applicable bucket soft-delete policy is present, separately list objects with softDeleted=true instead of versions=true and identical fields/maxResults. Do not combine the two flags.
- Also list soft-deleted buckets using buckets.list with softDeleted=true, same project/field restrictions. Any returned soft-deleted bucket is preservation-relevant: DATA_FOUND; do not restore or inspect contents. Unsupported operation/permission failure is INCOMPLETE.
- Empty means no active/versioned/soft-deleted objects in all discovered active buckets and no soft-deleted buckets found. Buckets alone are not student records. Other services (Realtime Database, backups/PITR, other projects) are outside this scope; never claim all cloud data is absent.

## Hard bounds and failure behavior

All bounds are global across identity, metadata, pagination and final checks: overall10min, request30s, response1MiB, at most200HTTP requests,100collection IDs,2000missing references,depth32,20buckets,20tenants. Firestore/listing page100; Auth/object existence page1. Lower-only overrides; reserve20s/2requests for final Rules checks. Budget/cap hit, including a page with potential uninspected results at the limit: INCOMPLETE. Validate all returned shapes; reject HTTP200 error envelopes. No retry, redirects, token refresh, permissions repair or resumable cursor file. Cancel pending work immediately on failure. Stop all collection on first DATA_FOUND.

Outputs: COMPLETE_EMPTY (all checks completed, all observed counts0, unchanged G1); DATA_FOUND (observed lower-bound counts only; remaining checks NOT_RUN); INCOMPLETE/BLOCKED (safe code, completed checks and unknown counts). Never count an unrun/failed check as0. Results are time-bounded observations; no automatic G2 closure, clearance, remediation or deployment. Only sanitized counts/status/timing/G1 hash in shareable report. No raw responses, names, tokens, ADC bytes, identifiers or pagination tokens written to disk/logs. No full inventory evidence store required; restricted manifest remains outside Git. Raw credentials never appear in chat.

## Local acceptance before executable approval

Tests use fake auth/HTTP and synthetic loopback Firestore only: identity-only zero metadata calls; string/boolean/false/missing/conflicting claims; exact metadata fields/masks; missing parents with nested sentinel; arbitrary collection nesting; empty pages with next tokens; existing record early stop; tenant users; bucket versions/zero-byte/soft-deleted objects and buckets; project/G1 drift; denied API; malformed responses; deadline/caps/cancel; no identifiers/contents in reports. Verify mask on emulator with a forbidden sentinel business field. Hash final compiled modules/helper/lock/runtime after successful tests. Node24.18.0 local validation; Node22 Functions parity is separate and not implied.

## Sources and review decisions

- https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/list (showMissing and mask)
- https://docs.cloud.google.com/identity-platform/docs/reference/rest/v1/projects.accounts/batchGet (paginated accounts)
- https://docs.cloud.google.com/storage/docs/json_api/v1/objects/list (versions and separate softDeleted)
- https://docs.cloud.google.com/storage/docs/json_api/v1/buckets/list (project buckets/soft-deleted buckets)

Owner review required: approve this exact expanded existence scope (including tenants, versions and soft-deleted buckets), global limits, no-concurrent-writer attestation and sanitized report policy. Implementation approval is local only; identity-only hosted retry and baseline execution each require separate artifact-bound authorization. No existing historical-inventory manifest is reusable.

## Binding owner corrections

1. Tenant accounts use the separate tenant-specific path, never the default user endpoint with a tenantId query parameter.
2. Do not assume reserved __name__ is supported in DocumentMask. Establish a supported metadata-only wire response with existing and missing-parent synthetic documents, rejecting every unexpected field; hosted execution stays blocked if unproven. The earlier mask proposal is superseded pending this local proof.
3. Tenant discovery page size is at most remaining capacity20; bucket discovery across active plus soft-deleted populations shares capacity20. Never request100 identifiers when only20 are approved. Reaching capacity with possible uninspected pages is INCOMPLETE.
## Local proof checkpoint

REST emulator filtering failed to suppress synthetic fields, including the proposed reserved-name mask. See docs/resqme-empty-baseline-local-preparation-results.md. Hosted transport and executable package remain BLOCKED. Next evaluate explicitly present empty RPC DocumentMask using the official SDK pattern; do not treat the rejection regression as metadata-only acceptance.

RPC transport checkpoint: a deliberately serialized present empty protobuf mask also returned2synthetic business fields from the installed emulator. Mandatory positive proof remains failed; transport investigation is BLOCKED. See local results for exact commands and limitations. Do not create an executable approval package or complete orchestration on this evidence.
