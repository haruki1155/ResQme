# Resolve empty-baseline Firestore transport — focused plan

Local-only, existing checkout. No commit/push, credentials, hosted requests or new dependencies. Preserve identity correction47fd30e and unrelated owner files.

1. Re-run REST sentinel reproduction. Positive metadata-only assertion must fail before transport correction; keep existing rejection regression.
2. Use already installed grpc-js/proto-loader and Firestore definitions for deliberately constructed loopback-only RPC. Verify request protobuf contains present empty mask and showMissing; no SDK auth/GAX/auto pagination/retries. Raw existing/missing response must have no business fields; listCollectionIds must discover missing-parent children.
3. TDD small injected transport: fixed demo namespace/endpoint guard; page sizes/tokens and shared request budget/deadline/cancellation. Normalize protobuf metadata only after validating raw response keys. Tests for unexpected fields, no request on unsafe config, timeout/cancel/cap, missing traversal and raw mask encoding.
4. Include new non-emulator tests in npm test and synthetic proof in explicit documented emulator script. Build, focused tests, existing regressions, diff check; report LOCALLY PROVEN only with positive raw proof. No remaining hosted verifier orchestration or executable package. No extra subagent required for this focused task; separate final self-review.
