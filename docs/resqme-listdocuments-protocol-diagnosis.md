# Firestore ListDocuments protocol diagnosis

Date: 2026-11-08. Decision: BLOCKED for complete empty-baseline verification.

## Confirmed environment

Running Firestore emulator: cloud-firestore-emulator-v1.22.0.jar, standard edition, demo-resqme,127.0.0.1:8080. JAR SHA256:9b6498b7f62714d67f48f59b3818883cd682dbcd46b9f59511de81c97bb5166c. Installed SDK source: functions/node_modules/@google-cloud/firestore/build/src/reference/collection-reference.js, listDocuments() lines136–156. Node24.18.0; Node22 deployment parity remains separate.

## Narrow implementation sequence performed

Read existing dirty tree, protocol/RPC source, tests and prior results. Inspect installed SDK request and local JAR bytecode. Add one independent synthetic raw-buffer probe (no verifier imports), compare mask variants, then rerun existing regression suite and original failed positive proof. No transport correction or weakening is made.

## Exact protocol comparison

Installed Google SDK constructs {parent,collectionId,showMissing:true,mask:{fieldPaths:[]}}, sends listDocuments through its RPC layer and maps returned documents to references. The diagnostic uses the same installed Firestore v1 descriptor and the same request fields, with explicit bounded pageSize100. It serializes and deserializes requests to prove omitted mask has no mask property, while present-empty mask has a mask property with no field paths. No guessed document field or response scrubbing is used.

The independent probe uses grpc.Client.makeUnaryRequest with a response deserializer returning the Buffer unchanged. It tests sentinel presence in that raw response Buffer BEFORE protobuf object decoding. gRPC framing/decompression is performed by grpc-js; no Google SDK/GAX/Auth, application decoder, response map/filter or ResQMe verifier is in this read path. No new packages were installed.

## Results: one existing synthetic document and one missing parent

| Request | mask present in serialized request | sentinel bytes in raw response | document count | business-field counts |
| --- | --- | --- | --- | --- |
| showMissing:true, mask omitted | no | yes |2|2,0|
| showMissing:true, explicit empty mask | yes | yes |2|2,0|
| showMissing:true, explicit nonempty synthetic control mask | yes | yes |2|2,0|
| showMissing:false, explicit empty mask | yes | no |1|0|

Both existing and missing references have expected existence metadata in the independent probe. No values or resource identifiers were printed; only variant names, booleans and counts. Fixture cleanup removes only this probe's two known synthetic documents, never the whole database. The live emulator was reused and left untouched otherwise.

## Local implementation cause

Inspected bytecode using the existing Android JBR javap, without extracting/modifying/installing the JAR:

- com.google.cloud.datastore.emulator.impl.firestore.CloudFirestoreV1.listDocuments tests getShowMissing. On the true branch it invokes showMissingListDocuments(context,collectionRef,startAfter,limit,transaction); the mask/query projection is not an argument. Returned ReadResults map directly through FirestoreEmulatorConverters.toDocument.
- showMissingListDocuments reads LocalEntityStore.ReadView.all(), enumerates entries/references and returns ReadResults. No mask/projection is applied in that helper path.
- The false branch invokes the query helper with the converted Query. The control above demonstrates the empty mask works on this branch.

Together, bytecode and raw response prove the observed fields originate from this emulator's showMissing path, not a post-response client transformation. This is evidence for this installed JAR only, not a claim about hosted behavior or other emulator versions. Earlier REST behavior is consistent with this cause when showMissing:true; separate REST partial-response implementation details are not inferred.

Temporary bytecode output: %TEMP%/resqme-v1-list-bytecode.txt, resqme-showmissing-bytecode.txt, resqme-v1-verbose.txt and resqme-converters-bytecode.txt. These contain program instructions, not student data.

## Reproduction and verification

From functions root via repository commands:

1. npm.cmd --prefix functions run build — exit0.
2. Set GCLOUD_PROJECT=demo-resqme and FIRESTORE_EMULATOR_HOST=127.0.0.1:8080; npm.cmd --prefix functions run test:baseline:diagnosis —1test/four variants passed,exit0. Passing means the limitation is reproduced, NOT baseline acceptance.
3. npm.cmd --prefix functions test —58passed,0failed,exit0. Existing58test behavior preserved.
4. npm.cmd --prefix functions run test:baseline:integration —1passed,1failed,exit1. Mandatory positive metadata-isolation proof retained unchanged and still fails.
5. git diff --check —exit0.

New source: functions/test/list_documents_wire_probe.test.ts. Package script added: test:baseline:diagnosis. New diagnostic is emulator-only and deliberately separate from the non-emulator unit suite. No production transport/auth logic changed in this diagnosis.

## Supported alternatives and limits

- Explicit empty-mask RPC with showMissing:false is locally demonstrated metadata-only for existing documents. It is NOT a complete baseline alternative: root traversal can omit a missing parent and its descendants. Do not substitute it for the approved coverage.
- A complete alternative is not yet established. The next safe candidate is a separately reviewed local compatibility check against another official emulator version whose showMissing path honors DocumentMask, or an upstream emulator fix. Do not download, replace or patch the current emulator under this result alone.
- Another API combination must independently prove names-only discovery of ALL missing-parent descendants plus metadata-only existing reads; no guessed field, high-level reference mapping or content filtering qualifies. Structured queries alone do not demonstrate discovery of arbitrary unknown collection names.
- No hosted correctness is asserted. Any hosted protocol experiment requires separate explicit authorization and a safe synthetic-only scope; this diagnosis authorizes none.

No real credentials/tokens, hosted Firebase requests, hosted writes, deployments, dependency changes, commits/pushes or approval-package assembly. Owner's uncommitted Flutter/dependency/plugin files and prior tests remain preserved. G2 blocked; G3/G4 unauthorized.
