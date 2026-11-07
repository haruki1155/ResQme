# G2-A Hosted Inventory Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` in native sequential mode. Use test-driven development, systematic debugging on failures and verification before completion. Steps use checkboxes for tracking.

**Status:** Owner approved 2026-11-07; local implementation and validation completed. No hosted execution is authorized. Results: `docs/resqme-g2a-hosted-adapter-local-results.md`.

**Goal:** Prepare a separately invoked, locally tested staging inventory adapter that reuses the existing engine and cannot mistake available credentials for execution approval.

**Architecture:** Retain the emulator-only CLI. Extract shared query encoding/decoding and add a fixed staging namespace to the engine, then layer manifest approval, user ADC identity verification, read-only preflight/transport and a narrow Windows evidence writer around it. No application or Cloud Function integration.

**Tech Stack:** Existing TypeScript/Node, native fetch, `node:test`, Firestore emulator; direct pinned `google-auth-library@11.3.1` dependency, already present transitively. Node 24 local validation; Functions target remains Node 22.

**Spec:** `docs/superpowers/specs/2026-11-06-resqme-g2a-hosted-adapter-design.md`, approved for planning with its three owner clarifications.

## Global constraints

- Existing checkout only. Preserve dirty Flutter files, mockups, owner documents, permanent Rules and containment artifacts. No reset, broad staging, push or deployment.
- All implementation verification uses fake auth/HTTP/filesystem or synthetic loopback emulator data. No actual ADC file, token endpoint, hosted metadata or private record access.
- Hosted target is exactly `resqme-943ee` / `519076598217` / `(default)` / `nam5`. Default emulator target remains `demo-resqme`.
- Preserve exact field allowlists and maxima: page100/query500/total2000/collectionIDs100/request30s/overall10min; lower-only overrides.
- Missing identity claims fail closed. Never expand scopes, replace credentials, switch accounts or weaken checks.
- Adapter restrictions are not IAM least privilege. Do not query/change IAM or certify the operator's permissions.
- Evidence validation supports only local Windows NTFS with read-only inspection. No permission repair, general ACL framework or cross-platform support.
- No G2-B remediation or G2 closure. G3/G4 remain blocked. Final hosted authorization still needs exact artifacts, operator, manifest digest and evidence policy.

## Review focus

1. Cross-project document references must not bypass path validation (Task 2).
2. Valid CLI identity but mismatched/missing token claims must fail before inventory (Task 3).
3. HTTP-200 error envelopes, expired approval and late G1 changes must never produce COMPLETE clearance (Tasks 1/3).
4. Junctions, broad inherited rights and evidence-write failures must stop rather than redirect output (Task 4).
5. Dependency imports, test setup and token-refresh defaults must not contact Google during local validation (Tasks 3/5).

## Task 1 — Manifest and explicit approval contract

**Create:** `functions/tools/g2_inventory/hosted/approval.ts`; `functions/test/hosted_inventory_approval.test.ts`.

**Interfaces:** Export `HostedManifest`, `ValidatedApproval`, `canonicalManifest(value): string`, `validateApproval(value, artifacts, now): ValidatedApproval`, and `confirmApproval(approval, input): Promise<void>`. Artifact inputs are injected file/hash results; this module reads no credentials and performs no I/O on import.

Manifest schema is version 1 with exact keys: `runId`, `approvalReference`, `validFrom`, `validUntil`, `artifacts`, `nodeVersion`, `operator`, `target`, `g1`, `scopes`, `limits`, `evidence`. Operator includes expected email/stable subject, ADC absolute path/hash; evidence includes resolved path, owner SID, approved reader SIDs, retention deadline, disposal method and responsible operator. Artifacts are sorted relative-file SHA256 entries plus lockfile hash; include compiled tool/shared modules and approved containment bytes. Do not include approval manifest in its own artifact hash set.

- [x] RED: test missing/extra keys, wrong targets/baseline, hash/runtime mismatch, missing policy, expanded fields/limits, invalid/expired windows and noncanonical types; all reject without any network call. Assert canonicalization sorts object keys recursively, retains array order and rejects non-JSON/unsafe numbers.
- [x] Run `npm.cmd --prefix functions run build` then `node --test functions/lib/test/hosted_inventory_approval.test.js`; observe meaningful failure before implementation.
- [x] GREEN: implement strict validation and SHA256 over canonical UTF-8 JSON. Expected G1 ruleset is `aa4be7e8-ce25-44d1-afd8-c10654658bab`; source hash is `7bff2de50c73415a3b12a6783f42ff621b1b04803ffc4e2634e6ba68e5d655f9`.
- [x] Test exact interactive text `APPROVE READ-ONLY INVENTORY <digest>` and matching approval reference; reject EOF, non-TTY, `--yes` or unattended input. Document that this is operator attestation, not cryptographic owner authentication; an agent-created manifest never constitutes owner approval.
- [x] Re-run focused tests; expected PASS/exit0. Failure produces safe approval codes and zero credential/network activity.

## Task 2 — Reusable namespace and projected query codec

**Modify:** `functions/tools/g2_inventory/{contract,inventory,transport}.ts`. **Create:** `functions/tools/g2_inventory/query_codec.ts`, `functions/tools/g2_inventory/hosted/transport.ts`; `functions/test/hosted_inventory_transport.test.ts`. Extend existing inventory tests only for namespace regressions. Leave local `runner.ts` and `localConfig` guards unchanged.

**Interfaces:** `DocumentNamespace = 'demo' | 'staging'`; `documentPrefixFor(namespace)`; `validName(scope,name,namespace='demo')`; `runInventory` gains optional `namespace` defaulting to demo. Query codec exports body builders and response decoders parameterized by this closed namespace. `HostedFirestoreTransport` implements existing `ReadTransport`, consuming a verified-session HTTP sender from Task 3; constructor/import performs no network I/O.

- [x] RED: prove hosted paths currently fail; assert every root/group projection, `__name__` reference-only select, cursor ordering and streamed response validation matches the local codec. Reject foreign databases/projects, malformed paths, unapproved group prefixes, redirects and error envelopes, including HTTP200 errors.
- [x] Run build and `node --test functions/lib/test/hosted_inventory_transport.test.js functions/lib/test/inventory.test.js`; observe RED.
- [x] GREEN: extract the existing codec without rewriting pagination/classification. Local transport continues using literal loopback and `Bearer owner`; hosted transport uses only the verified OAuth token and fixed `https://firestore.googleapis.com` read endpoints. It exposes no arbitrary URL/method/body or write method.
- [x] Test exact outgoing POST bodies for `listCollectionIds`/`runQuery`, no full-document mask, no recursive unknown discovery and no mutation/Auth/callable request. Assert local CLI still rejects hosted configuration and imports no hosted auth module.
- [x] Re-run the same focused command; expected PASS/exit0. Errors retain safe codes and no raw paths/values. No endpoint fallback.

## Task 3 — User ADC identity, fixed HTTP and G1 preflight

**Create:** `functions/tools/g2_inventory/hosted/session.ts`; `functions/test/hosted_inventory_session.test.ts`. **Modify:** `functions/package.json` and lockfile only to declare the pinned auth dependency; no auth initialization hooks.

**Interfaces:** `VerifiedSession` exposes bounded read-only metadata/query operations, never the token to reports. `openVerifiedSession(approval, dependencies, signal): Promise<VerifiedSession>` consumes injected ADC bytes, auth-library factory, HTTP, clock and timer. `verifyG1(session, approval, signal): Promise<BaselineEvidence>` validates release and source. Reuse safe response handling; all requests share the approval-bound deadline.

- [x] RED: mock ADC type, token response and token-info claims. Missing `sub`/`user_id`, absent or false verified email, subject disagreement, identity mismatch, insufficient lifetime and any refresh/auth failure reject before project/inventory requests. Test no discovery, metadata server, credential-file write, replacement or consent/scope expansion.
- [x] Run build and `node --test functions/lib/test/hosted_inventory_session.test.js`; observe RED.
- [x] GREEN: load only supplied `authorized_user` bytes through Google's library. Use one token, verify its principal via `getTokenInfo`, require remaining overall budget plus60s lifetime, and prohibit automatic mid-run refresh/retry. Restrict the auth library's injected transporter to fixed OAuth token/token-info HTTPS endpoints with redirects/retries disabled and30s/remaining deadline bounds. Mock this boundary in every test.
- [x] Verify fixed project/database metadata and exact G1 release/ruleset/source, single file and byte hash before document queries. Verify active release again after inventory; mismatch/unverifiable final baseline forces INCOMPLETE even if queries finished. Test API/permission errors, timeout and cancellation; no enabling APIs or corrective writes.
- [x] Assert fixed endpoints only: OAuth, Firebase project metadata, Firestore database/projected reads and Firebase Rules metadata. Reject emulator variables/custom endpoints. Console/evidence errors contain no token, ADC content or unsanitized library exception.
- [x] Re-run focused tests; expected PASS/exit0. Reports explicitly state `adapterReadOnly:true` and `operatorIamPermissions:'NOT_ASSESSED'`; do not infer broader IAM permissions.

## Task 4 — Narrow Windows evidence boundary

**Create:** `functions/tools/g2_inventory/hosted/evidence.ts`, `functions/tools/g2_inventory/hosted/windows_evidence.ps1`; `functions/test/hosted_inventory_evidence.test.ts`.

**Interfaces:** `prepareEvidence(approval, io, signal): Promise<EvidenceWriter>`; writer supports exclusive run reservation, separate private metadata/aliases/sanitized report writes and failed-run finalization. IO is injected for tests. PowerShell helper performs only read-only volume/path/ACL inspection and returns bounded structured facts; invoked without shell string interpolation and with literal paths.

- [x] RED: mock Windows/local NTFS acceptance; reject unsupported OS, UNC/network/removable/cloud-backed paths, any reparse-point component, Git-contained directories, unresolved owner, unapproved/broad inherited access, deny/conditional/object ACE ambiguity, duplicate run IDs and unavailable evidence writes.
- [x] Run build and `node --test functions/lib/test/hosted_inventory_evidence.test.js`; observe RED.
- [x] GREEN: support only a pre-existing local fixed NTFS directory whose resolved owner SID and simple inherited/explicit allow entries are confined to the manifest's approved SIDs. Reject ACL semantics the narrow validator cannot establish; SYSTEM/administrators are permitted only if explicitly approved. Reject OneDrive-known locations and offline/recall/cloud/reparse attributes; require operator attestation of an unsynced directory because filesystem inspection cannot prove absence of every third-party sync agent. No ACL edits or directory-permission repair.
- [x] Before network access, verify policy, exclusive run reservation and safe writability. Split private projected metadata, alias mapping and sanitized report. Never fall back to stdout/public temp on failure. Retention is recorded operator policy, not automatic deletion. Recheck paths/access policy before final writes; preserve failed-run markers without publishing private values.
- [x] Test malformed values suppressed, identifiers absent from shareable output, write failure cancels further reads, and no chmod/Set-Acl/icacls mutation/deletion operation exists. Re-run focused command; expected PASS/exit0.

## Task 5 — Separate runner, regression and handoff

**Create:** `functions/tools/g2_inventory/hosted/runner.ts`, `functions/test/hosted_inventory_runner.test.ts`, `docs/resqme-g2a-hosted-adapter-local-results.md`. **Modify:** package scripts and synthetic inventory integration tests as needed. No hosted default in the existing local script.

**Interfaces:** `runHostedInventory(dependencies): Promise<{status,exitCode}>` orchestrates validated approval → evidence readiness/confirmation → identity/project/G1 preflight → shared engine → final G1 check → safe report. CLI accepts only `--manifest <absolute-path>` and interactive confirmation; no `--yes`, alternate endpoint or automatic approvals. Exit0 means inventory COMPLETE only; exit1 incomplete/failed; exit2 locally rejected configuration/approval. Imports are side-effect free.

- [x] RED: test the entire request ordering with fake auth/network/IO; absent approval produces zero credential reads or HTTP. Cover cancellation, partial responses, caps, token expiry, permission failure, evidence failure and final G1 change. Assert no request after stop and never G2 clearance or remediation.
- [x] GREEN: orchestrate existing components; preserve overall10min/request30s deadlines from initial authorization validation through finalization. Reserve time for final baseline/evidence; if it cannot finish in budget, output INCOMPLETE rather than silently extending the deadline. Keep original private/report semantics and ensure malformed raw values are not persisted.
- [x] Add scripts `test:inventory:hosted` (build plus explicit hosted unit tests) and `test:inventory:hosted:integration` (existing compiled synthetic emulator tests); no automatic hosted run/postinstall script. Hosted tests replace every auth/HTTPS operation with mocks. Emulator integration exercises the shared codec/engine and sentinels; never redirect a production transport to loopback via a runtime flag.
- [x] Run `npm.cmd --prefix functions run test:inventory:hosted`, `npm.cmd --prefix functions test`, `npm.cmd --prefix functions run build`. Expected all PASS/exit0; existing inventory suite still rejects hosted targets. Include hosted tests in the general non-emulator test list after they pass.
- [x] With ports inspected, start/reuse one compatible `demo-resqme` loopback Firestore session using `firebase.integration.json`; run existing `test:inventory:integration`, new hosted-integration script and `test:rules` with correct emulator environment. Build before emulator tests, never trigger hosted credentials or discovery. Capture actual results; stop only session processes owned by this work.
- [x] Run `git diff --check`, inspect explicit diff and obtain one final read-only code review. Fix demonstrated blockers with RED/GREEN tests; do not claim tests ran during planning. Record artifact hashes/runtime/lockfile, commands/counts/exit codes, evidence limitations and remaining owner decisions in the results document. Exclude credential/evidence manifests and raw IDs from Git.
- [x] Commit only reviewed adapter/shared-tool/test/dependency/docs changes after validation; preserve unrelated work. Suggested commit: `feat(resqme): prepare gated hosted inventory adapter`. No push/deploy or hosted execution.

## Self-review and approval checkpoint

Coverage checked against design sections1–7: existing-engine reuse/local isolation→Task2; strict manifest/approval→Task1; user ADC/effective identity/target/G1→Task3; private Windows-only evidence→Task4; bounded orchestration/regression/handoff→Task5. Five review-focus failure classes have explicit tests. No implementation or test results are claimed in this plan.

Missing identity claims fail closed with no credential/scope fallback. Read-only adapter capabilities are explicitly distinct from actual operator IAM permissions. Windows validation is a conservative validator for one supported environment, not an ACL-management framework; unsupported/ambiguous cases stop.

Owner-specific ADC identity/path, evidence directory/SIDs/retention/disposal, exact executable digest and execution window remain mandatory **future hosted-execution decisions**. Local tests use fictional values. Plan approval authorizes only later local implementation, not live identity verification, preflight or inventory. G1 remains unchanged; G2-B/G3/G4 remain blocked.

**STOP after local implementation: hosted execution requires a separate exact-artifact authorization.**
