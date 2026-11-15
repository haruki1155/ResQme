# Empty-baseline local protocol preparation — blocked transport proof

Date: 2026-11-08. Local Node v24.18.0. Status: PARTIAL / BLOCKED; no executable verifier or approval package exists.

## Completed corrections

- Pure Auth builder uses the separate tenant accounts path. Mock tests reject a tenant query on the default population.
- Discovery builder requests only remaining capacity (20 minus consumed). The future runner must maintain one shared active+soft-deleted bucket counter; no such runner is implemented or claimed complete.
- Strict metadata decoder rejects user-defined fields, malformed timestamps, foreign paths and unexpected envelopes.

## Reproduced blocker

Using the existing demo-resqme Firestore emulator at127.0.0.1:8080, created one synthetic existing document and one nested synthetic document beneath a missing parent. Raw REST ListDocuments response included the synthetic forbidden business field with response fields=documents(name,createTime,updateTime),nextPageToken. Adding mask.fieldPaths=__name__ also failed to suppress it. The failing proof assertion was observed before converting the probe into a permanent fail-closed rejection regression. This green rejection test DOES NOT establish an acceptable metadata-only transport.

Initial fixture mistakenly tried storing reserved __name__ as a user field; emulator rejected that fixture. Removed that unsupported fixture field, then reproduced the real response filtering failure. No hosted inference is drawn from emulator behavior; the REST emulator may not implement these filters like the hosted service. Testing against real data to resolve that question is not authorized.

The fixture setup/cleanup touched only its two synthetic local documents. Existing emulator session was reused and left running; no hosted token, credential, Firebase metadata or record access occurred. No dependency/runtime/security artifact changes.

## Actual validation

- TypeScript build: exit0.
- New protocol and synthetic emulator rejection tests:4passed, exit0.
- Existing full Functions/auth/inventory unit suite:53passed, exit0. New tests currently run explicitly, not silently included in the old script.
- git diff --check:exit0.
- Original metadata-only positive assertion:FAILED (expected absence of synthetic business fields; actual contained them). This remains the acceptance blocker, not a passing proof.

## Next technical work

Google's official Node Firestore SDK uses ListDocuments(showMissing:true,mask:{fieldPaths:[]}) over its RPC transport: https://github.com/googleapis/nodejs-firestore/blob/main/dev/src/reference/collection-reference.ts . Evaluate an explicitly injected, bounded RPC transport locally, with auto-pagination/retries/credential discovery disabled, and verify exact responses for existing/missing documents. An empty protobuf mask has presence semantics that a flattened REST query does not necessarily preserve. No unsupported reserved mask or missing-field-name guess should be substituted. Transport change must be documented and reviewed before any executable approval package; until proven, do not assemble/authorize a hosted baseline run.

Identity-only mode, approval validation, orchestration, pagination runner, final G1 checks and real network adapters are NOT implemented in this partial milestone. Previously committed identity correction47fd30e remains separate. G2 blocked; G3/G4 unauthorized. Unrelated owner files preserved. No commit made for this partial work.

Independent read-only review found that explicit documents:null was treated as empty. Added a failing rejection test, then changed the decoder to default only an absent documents key. Final new suites4passed and full existing suite53passed, builds exit0. Review confirmed tenant path/cap builders and the explicit transport-proof blocker. No executable approval package was produced.

## Explicit RPC investigation — 2026-11-08

Gate decision: BLOCKED. Investigated installed Firestore protobuf ListDocuments over grpc-js with a deliberately constructed loopback channel. No new packages installed and package-lock unchanged. No GoogleAuth/GAX or token refresh path is used by the new boundary; endpoint is hardcoded127.0.0.1:8080 and project guard requires demo-resqme.

Confirmed local evidence:
- Protobuf requestSerialize/requestDeserialize distinguishes omitted mask from present empty mask. Request includes showMissing:true, bounded pageSize and mask:{fieldPaths:[]}.
- Raw decoded RPC response contains document keys name,fields,createTime,updateTime; the fields map contains2synthetic business fields. No values were printed. Response was rejected before timestamp normalization.
- Positive RPC metadata-isolation assertion remains FAILED; existing/missing classification and child traversal acceptance for RPC were therefore NOT reached/proven. The positive test was not replaced with a negative test.
- REST synthetic regression still reproduces both existing and missing-parent references with leaked fields and correctly rejects them. This does not prove hosted behavior.
- Installed descriptor uses expected camelCase request property names, including mask and showMissing. No evidence of a missing-mask serialization bug was found. Emulator implementation/version behavior is the remaining uncertainty; hosted execution is not an authorized diagnostic.

Validation after final code changes:
- npm.cmd --prefix functions test:58passed,0failed,exit0, including5new protocol/RPC unit tests and all53existing identity/Functions/inventory regressions. Build included,exit0.
- Synthetic integration final run:1passed (REST rejection),1failed (mandatory positive RPC proof),exit1. Last run included the same final RPC production implementation; subsequent edits only added package scripts.
- git diff --check:exit0.
- Standard test script now includes protocol/RPC unit suites; explicit npm.cmd --prefix functions run test:baseline:integration runs synthetic proof and is expected to fail until the blocker is resolved. Requires GCLOUD_PROJECT=demo-resqme and FIRESTORE_EMULATOR_HOST=127.0.0.1:8080.
- Unit cases cover explicit mask/pageToken, missing-reference decoding, unsafe endpoints/projects, unexpected fields, request cap, cancellation and ignored-response timeout. Full verifier traversal/global completeness is NOT implemented or accepted.

Exact task files added/changed: functions/tools/empty_baseline/firestore_rpc.ts (loopback experiment/injected guarded transport); functions/test/empty_baseline_rpc.test.ts (unit cases); functions/test/empty_baseline_integration.test.ts (positive raw RPC proof alongside REST reproduction); functions/package.json (documented scripts); focused transport-resolution plan; this report and companion design checkpoint. Existing protocol files from the prior partial milestone remain. No Flutter, Android, callable, Rules, credentials or dependency-lock changes were made. Owner's dependency/plugin changes and other untracked files were preserved. No commits/pushes or hosted approval package.

Safest next option: inspect the installed emulator's ListDocuments mask handling or test a separately approved emulator version locally, preserving current runtime and fixtures. Do not install/update dependencies, contact hosted Firestore, use guessed masks or download business fields as a workaround. Required owner decision: approve that narrow emulator-compatibility investigation/version experiment if desired. No additional phase is automatically authorized. G2 blocked; G3/G4 unauthorized.
