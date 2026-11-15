# ListDocuments metadata-only proof: remediation options

Date: 2026-11-08  
Status: design for owner review only. Neither option is authorized for execution.  
Gate: G2 remains BLOCKED; G3 and G4 remain unauthorized.

## Decision to make

`ListDocuments(showMissing:true)` is required to discover both existing documents and references to missing parents. The metadata mask must prevent business fields from crossing the wire; filtering fields after receipt is not an acceptable substitute.

The current diagnosis for Firestore emulator v1.22.0 records that its `showMissing` implementation bypasses the mask/projection path. The approved isolated v1.20.2 experiment produced the same privacy failure: for `showMissing:true`, the raw gRPC response contained synthetic private and control-field bytes with the mask omitted, explicitly empty, and nonempty. `showMissing:false` with an empty mask returned one metadata-only existing document but did not prove missing-parent traversal. The v1.20.2 artifact was checksum-verified and its temporary directory was removed. Neither result establishes hosted Firestore behavior.

This design compares two possible next investigations. It does not choose or authorize either one.

## Option A — upstream bug-report proposal

**Source availability check (reviewed 2026-11-08):** The official [Firebase CLI emulator launcher](https://github.com/firebase/firebase-tools/blob/v15.0.0/src/emulator/downloadableEmulators.ts) delegates Firestore startup to a downloaded emulator binary; its [official emulator manifest](https://github.com/firebase/firebase-tools/blob/v15.0.0/src/emulator/downloadableEmulatorInfo.json) identifies the Firestore JAR and download URL. The reviewed official repository exposes the launcher/manifest, not the server implementation. I did not identify a public official Firestore emulator server source repository or an authorized source revision for the server implementation; public source availability is therefore **not established**, rather than claimed impossible. A code search found a third-party fork containing similarly named Java classes, which is not an official or authorized source and must not be used as one.

Therefore, a source patch/build is not a presently supportable path. Recast this option as a **proposal to report the reproducible emulator defect to the Firebase Emulator Suite maintainers**, likely via the official [Firebase CLI issue tracker](https://github.com/firebase/firebase-tools/issues) so maintainers can route it to the server owner. No issue has been filed.

### Minimum steps, after separate approval

1. Prepare a sanitized bug-report draft describing `ListDocuments(showMissing:true)` mask bypass. Include emulator versions 1.22.0 and 1.20.2, verified artifact provenance/checksums, the four-variant raw-wire summary, and a minimal synthetic reproduction. Exclude sentinel values, resource names, credentials, raw responses, and ResQMe data.
2. Ask maintainers to confirm the owning component, whether server source is available to them, and which official issue/revision will track a fix. Do not infer source availability or authorization from a third-party mirror/fork.
3. If maintainers provide an authorized source/revision, return for owner review and separate approval before any source checkout, changes, upstream contribution, build, or candidate execution. Do not decompile, patch, modify, or distribute any official emulator JAR.
4. If an official corrected candidate is later made available and separately approved, run the raw-wire acceptance suite below against that candidate and only synthetic local data. Reject any response containing an unrequested field; do not strip fields in a client adapter.

### Security boundary

- A bug-report draft contains only sanitized synthetic evidence and public artifact metadata.
- Drafting is read-only. Submitting an issue, attaching a reproducer, checking out upstream source, or testing a future candidate each requires separate approval.
- Do not decompile, patch, modify, or distribute an official emulator JAR. Do not access hosted Firebase, credentials, ADC, or ResQMe project resources.
- If an official candidate is later approved, it must run locally against synthetic data on loopback, a verified free port other than 8080, and a uniquely scoped temporary directory.
- Do not modify the active emulator, repository configuration, application/backend source, or owner worktree.

### Benefits and risks

- This is the lowest data-risk route and avoids hosted credentials or records.
- It gives maintainers the evidence needed to route the defect to the emulator server owner, without assuming the server source is public.
- A report alone does not establish a fix or a passing emulator. A later official candidate would prove emulator behavior only, not hosted Firestore behavior.
- Maintainer response/release timing is outside the owner's control. No unofficial source, private mirror, or modified JAR is an acceptable substitute.

## Option B — synthetic-only hosted protocol experiment

**Purpose:** Independently establish the hosted Firestore `ListDocuments` protocol behavior without accessing any ResQMe staging records.

### Minimum steps, after separate approval

1. Require an owner-designated, dedicated disposable Firebase/GCP project that is not `resqme-943ee`, contains no user data, and is reserved for synthetic testing. Hosted project IDs cannot use the Emulator Suite's `demo-*` convention; this option is deliberately not an emulator run.
2. Require an owner-approved short-lived test identity and explicit credential-handling procedure. No automatic ADC discovery, local credential-file search, or token refresh is permitted. Credentials may be supplied only through a separately approved explicit in-memory mechanism; do not proceed if access would require a ResQMe staging identity or broadened production permissions.
3. Use only the hosted Firestore API endpoint and exact `(default)` database in that dedicated project. Confirm the configured project ID matches the approval before making any request. Do not enumerate projects, databases, collections, Auth users, Storage buckets, or any ResQMe resource.
4. Generate a unique synthetic collection path. Create exactly two known synthetic documents: one existing document at that collection's root and one nested document under a missing parent. Give them distinct random sentinel fields. Record the exact paths only in memory; do not print field values, resource identifiers, tokens, or raw response payloads.
5. Issue the four exact `ListDocuments` variants below directly over the approved Firestore transport. For raw-wire proof, capture the gRPC response as bytes before protobuf response decoding; inspect the original bytes for sentinels, and independently validate decoded document keys and field maps. Do not log or persist raw responses.
6. If all privacy checks pass, continue only within the synthetic collection: paginate with page size one; identify the missing parent from absent existence timestamps; call `ListCollectionIds` for that exact parent; list the discovered child collection with the empty mask and `showMissing:true`. Enforce request deadlines, an overall deadline, a small fixed request cap, bounded response size, and page-token cycle detection.
7. In a `finally` cleanup, issue `DeleteDocument` for each of the two exact paths created by this run, leaf first. Then independently issue `GetDocument` for each exact path with an explicitly present empty mask. Require `NOT_FOUND` for both. If either path returns a document, check the original response bytes for either sentinel and report cleanup failure without printing contents; do not filter the response and do not broaden cleanup. Count every delete and verification call against the reserved cleanup budget below. If a call fails, still attempt the remaining exact-path cleanup calls within that reserve; an unverified path is an incomplete cleanup failure.

### Security boundary

- Project allowlist is one owner-supplied dedicated test project ID; explicitly reject `resqme-943ee` and every unapproved project before creating a client or sending a request.
- The test identity may access only the dedicated test project to the extent its IAM configuration supports. This experiment must not depend on, request, or test ResQMe staging access. Any IAM grant or project/API setup is a separate remote change and requires separate explicit approval.
- Restrict reads to the generated collection path and its known missing-parent traversal. Never list at the database root or inspect unrelated documents.
- Use only the four approved `ListDocuments` variants, bounded `ListCollectionIds`, the synthetic fixture `CreateDocument` calls, exact-path `DeleteDocument` calls, and exact-path masked `GetDocument` cleanup checks described above. No Rules changes, deployments, exports, backups, or other Firebase products.
- Hold credentials in memory through the approved mechanism; never echo, log, serialize, persist, refresh, or reuse them. Abort on identity/project mismatch, unexpected response shape, timeout, excess requests, or any operation outside the allowlist.
- Synthetic data is the only allowed content. No response scrubbing: an unexpected business field is a hard failure, even if it is later removed by application code.

### Benefits and risks

- Directly tests the hosted service's behavior, avoiding inference from emulator behavior.
- Still exercises hosted APIs and writes synthetic documents, so it has higher operational and credential risk than Option A.
- A mistaken project selection, over-broad identity, concurrent writer, or cleanup failure could expose unrelated data or leave test records. The dedicated empty project and exact path allowlist are required mitigations, not optional conveniences.
- Results apply only to the tested hosted API, project configuration, identity, and time. They do not prove full verifier completeness, an atomic snapshot, or absence of historical data.
- A passing protocol experiment is not authorization to run the ResQMe verifier or access staging.

## Exact acceptance tests

These are acceptance criteria for any future, separately approved official emulator candidate and for Option B. They do not authorize execution. Option A as currently scoped is only a bug-report proposal; it cannot pass a candidate test until maintainers provide an authorized candidate and the owner separately approves it. Use only a local synthetic `demo-*` project for an emulator candidate and only the separately approved disposable hosted project for Option B.

### Four request variants

For the same unique synthetic collection, create exactly two documents: a direct existing document with a private sentinel and a distinct permitted control field, plus a nested existing document under a missing parent with its own private sentinel. Every `ListDocuments` request in these variants uses `pageSize: 1`. Follow a returned page token when needed so the empty-mask and control-mask cases actually receive and inspect the direct existing document; do not treat a page containing only the missing-parent reference as satisfying either test.

1. `showMissing:true`, mask omitted: record whether the mask is absent in the serialized request, document count, raw sentinel-presence booleans, and decoded field counts. This is a comparison/control, not an acceptable metadata-only result if fields are returned.
2. `showMissing:true`, explicitly present empty protobuf mask (`mask.fieldPaths = []`): the request round-trip must preserve mask presence. Paginate, if necessary, until the direct existing document is returned. Its raw response must contain neither sentinel; its decoded entry must have only the permitted metadata keys (`name`, `createTime`, `updateTime`) and no business fields. Continue this same pagination sequence to discover the missing-parent reference; validate existing creation/update metadata and absent timestamps on the missing reference. These responses also satisfy the root missing-parent traversal test; do not issue a duplicate root traversal.
3. `showMissing:true`, nonempty control mask containing only the synthetic control field: prove the request carries exactly that mask and paginate, if necessary, until the direct existing document is returned. In that document's decoded response, require exactly the permitted `controlField` and its known synthetic control value; require the private field to be absent. In the original raw response bytes, require the control sentinel to be present and the private sentinel to be absent. A missing-parent-only page does not satisfy this case; unexpected or omitted control data fails.
4. `showMissing:false`, explicitly present empty mask: the raw response must contain neither sentinel and must include only the metadata for the existing document. This case is a control and cannot substitute for case 2 or missing-parent traversal.

For every response, assert the original response bytes before decoding; then reject any unexpected protobuf document fields or malformed resource names/timestamps. Do not accept client-side field deletion, post-decode redaction, REST `fields` projection alone, or high-level SDK output as proof of raw-wire privacy.

### Traversal, bounds, and fail-closed behavior

5. Reuse the complete page sequence from variant 2 (`showMissing:true`, empty mask, page size one) to discover both the existing document and missing-parent reference. Follow its page token as required; reject repeated tokens, duplicate/foreign names, malformed pages, unexpected records, and over-cap responses.
6. For the missing reference only, `ListCollectionIds` must discover the known nested collection. Listing that child collection with the same metadata-only request must find the nested existing document without returning either synthetic sentinel in raw bytes.
7. Enforce and assert the configured maximum request count, per-request timeout, overall deadline, and maximum response size. On timeout, cap exhaustion, cancellation, unexpected response, or transport failure, fail closed; never produce a success-shaped empty result.
8. Capture only a sanitized report: variant label, mask-presence boolean, document/field counts, sentinel-presence booleans, pagination status, request count, and cleanup status. Never output field values, tokens, raw bytes, credentials, or hosted resource identifiers.
9. Confirm exact synthetic cleanup without touching any other path. The hosted option must also confirm that the approved target project was used and no request addressed the ResQMe staging project.

### One hard operation budget (Option B)

The following are hard ceilings for the entire operation, including setup after process start, fixture writes, all four protocol variants, traversal, cleanup, cleanup verification, and client shutdown:

- **Overall wall-clock deadline:** 120 seconds, measured from test-process start through client shutdown. The protocol/fixture phase must end and cleanup must begin no later than 95 seconds; reserve up to 20 seconds for four cleanup calls and 5 seconds for shutdown/reporting. If a failure occurs earlier, start cleanup immediately. If the overall deadline is reached, cancel in-flight work and report every unverified path as cleanup failure; do not extend the deadline.
- **Per-request timeout:** 5 seconds for every Firestore RPC. No retries, redirects, automatic pagination, or token refresh.
- **Request cap:** 16 total Firestore RPCs, with four requests reserved unconditionally for cleanup: exactly two `DeleteDocument` attempts and two independent `GetDocument` verifications. Do not spend the cleanup reserve on protocol work.
- **Response cap:** at most 65,536 bytes per raw protobuf response message and 1,048,576 aggregate response bytes for the whole run. Reserve 262,144 aggregate bytes for the four cleanup responses; protocol/fixture responses may consume at most 786,432 bytes. Enforce the receive limit before protobuf decoding; stop protocol work on overflow but retain the cleanup reserve.
- **Page/request sizing:** `ListDocuments` and `ListCollectionIds` page size is exactly 1. Reject empty/repeated/oversized page tokens and duplicate resource names/collection IDs.

Request accounting: fixture creation exactly 2; variant 1 exactly 1 `ListDocuments`; variant 2 plus root traversal at most 2 `ListDocuments` pages (reused, not repeated); variant 3 at most 2 `ListDocuments` pages to reach the existing document; variant 4 exactly 1 `ListDocuments`; missing-parent collection discovery at most 2 `ListCollectionIds` pages; nested-document listing at most 2 `ListDocuments` pages; cleanup reserve exactly 2 deletes plus 2 exact-path gets. Thus pre-cleanup protocol work is capped at 12 Firestore RPCs and the total at 16, including the four cleanup calls. A page beyond these allowances, unexpected record, extra collection, exhausted cap, or unfinished pagination fails closed. Always attempt all four exact-path cleanup requests in the reserve; any deletion or verification not confirmed is a cleanup failure, not success.

Use one owner-supplied, explicitly injected in-memory bearer token for the approved disposable project; require sufficient remaining lifetime for the 120-second operation and do not load credentials, discover ADC, call an identity endpoint, or refresh tokens. Token provisioning and identity/IAM policy must be separately approved. The request cap counts every outbound Firestore RPC; no other network requests are permitted by this experiment.

Cleanup verification is intentionally independent: each exact document name (root existing path and nested child path) receives its own `GetDocument` call with a present empty mask. Both must return `NOT_FOUND`; a root collection listing alone is insufficient to establish nested deletion. If an unexpectedly existing document is returned, its raw response must still be checked for sentinel bytes before decoding; any content leak and any non-`NOT_FOUND` result fail cleanup verification.

**Pass condition:** all four variants behave as expected, cases 2 and 3 satisfy raw-wire privacy, and cases 5–9 pass. Any leaked sentinel, missing parent/child, malformed or unexpected response, uncontrolled request, or cleanup failure is a failure; stop and report evidence. Do not weaken assertions or try another emulator version as a fallback.

## Approvals and gates

- **Current state:** this document is the only authorized work. No implementation, emulator change, hosted request, credential load, or test execution is authorized by it.
- **Option A approval:** separately approve preparing/submitting a sanitized bug report. Any official source/revision later identified, source change, upstream contribution, build, or candidate execution requires a further approval. No JAR decompilation, patching, modification, or distribution is allowed.
- **Option B approval:** separately approve the exact non-ResQMe disposable project ID, database, test window, synthetic paths/operations, explicit in-memory token provision and lifetime, identity permissions, fixed request budget, timeouts, response caps, and exact-path cleanup. Any project setup, IAM grant, API enablement, or Rules/configuration change requires its own explicit approval.
- **After either protocol proof:** review raw-wire results and implementation proposal separately. A passing result does not authorize implementation, a hosted baseline run against ResQMe, or G2 release.
- **G2:** remains BLOCKED until the complete verifier and its independent approval requirements are satisfied. **G3/G4:** remain unauthorized.

## Recommendation for review

The practical no-hosted next step is to review and, if separately approved, submit the sanitized upstream bug-report proposal. No official emulator server source or authorized source revision has been established, so a source-fix plan cannot responsibly be promised. If the decision needed is specifically whether hosted Firestore honors the mask, only Option B can answer that protocol question, at higher operational risk and only in a dedicated non-ResQMe project. A passing synthetic hosted test proves protocol behavior only; it does not show that the ResQMe staging database is empty or authorize staging access.
