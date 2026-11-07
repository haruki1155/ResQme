# G2-A hosted adapter — local implementation evidence

Date: 2026-11-07. Scope is LOCAL ONLY. No actual ADC credentials were loaded, no Google token/metadata endpoints were contacted, and no hosted student documents were read. No remote changes, deployment, API enablement, IAM/billing operations, account creation, QA grants or G2-B remediation occurred. G3/G4 remain blocked.

## Implementation

The existing inventory engine now accepts only the closed demo/staging document namespaces, with demo as its unchanged default. The emulator CLI and endpoint guard remain unchanged. Both transports share the same query builders/decoders, field projections and fail-closed response checks; pagination, limits, classification and report logic remain in the original engine.

The separate hosted boundary provides:

- Strict versioned manifest, canonical SHA256, exact compiled artifact/helper/lock hashes, target/G1/identity/evidence-policy binding, validity window and interactive digest/reference confirmation. Confirmation is operator attestation, not cryptographic owner authentication or a substitute for external owner approval.
- Existing explicit user ADC only; no discovery, account switching, credential replacement or scope expansion. Exact effective token principal verified through Google's library; missing/conflicting identity claims stop. The same token is used for fixed metadata/read endpoints, with no silent mid-run refresh, retry or redirect.
- Fixed staging project/database/location and G1 source/release verification before queries and again afterward. No full-document reads or arbitrary hosted URLs. Session-level request-body validation independently rejects unapproved masks/scopes/page sizes.
- Read-only Windows local NTFS path/owner/ACL inspection; no ACL-management operations. Approved private evidence is separated from aliases and shareable summaries, with exclusive run reservation and no automatic deletion or public fallback.
- Shared deadlines/cancellation and safe failure status. Every report retains NOT_GRANTED and `g2Complete:false`. Adapter read-only behavior is explicitly separate from `operatorIamPermissions: NOT_ASSESSED`.

## Milestone file map

| Files | Responsibility |
| --- | --- |
| `functions/tools/g2_inventory/hosted/approval.ts` | Strict manifest, immutable validated approval and exact confirmation |
| `hosted/session.ts` | User ADC library boundary, principal, fixed HTTP and G1 verification |
| `hosted/transport.ts` | Authenticated projected read adapter |
| `hosted/evidence.ts`, `hosted/windows_evidence.ps1` | Narrow Windows validator and separate private evidence writer |
| `hosted/runner.ts` | Separate guarded CLI/orchestration; no import-time I/O |
| `query_codec.ts`, edits to `contract.ts`, `inventory.ts`, `transport.ts` | Shared projection codec and closed namespace compatibility |
| `functions/test/hosted_inventory_*.test.ts`, fixture helper and integration extension | Mock auth/HTTP/IO, regression and synthetic emulator tests |
| Functions package/lock | Direct `google-auth-library@11.3.1` pin and test scripts; no runtime-target change |
| Approved hosted design/implementation plan and this report | Authorization, task checklist and validation handoff |

Source paths in the first column after the first row are relative to `functions/tools/g2_inventory/`. No application/callable source or security artifact is part of this change set.

## Final validation

| Command/check | Verified result | Exit |
| --- | --- | --- |
| `npm.cmd --prefix functions run test:inventory:hosted` | 23 passed | 0 |
| `npm.cmd --prefix functions test` | 52 passed, including existing Functions/inventory regressions | 0 |
| `npm.cmd --prefix functions run build` | TypeScript compiled | 0 |
| `npm.cmd --prefix functions run test:inventory:integration` | 4 passed, synthetic emulator only | 0 |
| `npm.cmd --prefix functions run test:inventory:hosted:integration` | 1 passed, same emulator-projected data via mocked hosted session | 0 |
| `npm.cmd --prefix functions run test:rules` | 4 passed | 0 |
| PowerShell AST syntax parse | Passed; no real ACL directory was inspected | 0 |
| Diff/preservation checks | Permanent/containment artifacts and four dirty UI files match captured hashes | 0 |

One independent read-only review identified two Important findings and no Critical/deferred minor findings: a delayed ignored-signal write could publish COMPLETE after timeout, and an evidence directory inside another Git repository could pass. Both were reproduced with RED tests and fixed in one review pass; final focused/full unit suites passed afterward. The second regression also led to a separately tested check that private manifest files cannot reside in Git repositories. No second review was requested.

Focused TDD included strict manifest rejection, effective identity/secondary-claim rejection, exact body validation, the actual Google auth-library code path driven by mocked HTTP, unsupported/broad evidence-policy rejection and end-to-end fake runner sequencing. Fixtures are fictional; no credential store was inspected. The PowerShell helper was syntax-parsed without inspecting a real evidence directory or changing permissions.

Evidence: `%TEMP%/resqme-hosted-adapter-local-20261107233547`. Logs contain synthetic validation diagnostics and are not committed. Exactly one Firestore session was started for this milestone. Only its identified root PID18488/descendants were stopped; port8080 was then verified free. The emulator log contained no remote API request entries. Snapshots confirm user UI changes and security artifacts were preserved.

## Rulings and important limits

- Ruling: include explicit `schemaVersion:1`. The plan specified version1 but omitted its key from the example key list; explicit schema binding removes ambiguity. The validator rejects manifests with missing/extra keys, so any future request must use this exact reviewed schema.
- Ruling: evidence publication requires a separate exclusive synchronous final receipt after asynchronous evidence writes finish. Cost: reviewers must validate this receipt and its report digest; a candidate report alone never proves a complete execution. This fixes the demonstrated late-write race without building an ACL-management framework.
- The artifact set includes the complete executable tool modules, containment artifact, helper and dependency lock. It is not a cryptographic attestation of the entire workstation or installed dependency directory. Review/reproducible installation and a trusted operator environment remain necessary.
- Identity claims and ADC compatibility were tested with mocks, not real credentials. Missing claims remain a stop condition; prerequisite credential changes are not authorized or automated.
- Local Windows evidence inspection is conservative and supports only the approved environment. It does not prove the absence of every third-party sync agent; an operator's explicit unsynced-directory attestation remains required. Mode0600 is not used as a Windows ACL guarantee. Permission correction must happen outside this adapter under separate approval.
- No actual operator IAM permission set was examined or reduced. G1 deny-all client Rules do not constrain a privileged Admin/IAM principal; this tool's read-only interface does not turn that principal into a read-only account.
- Initial/final G1 checks do not establish an atomic snapshot or exclude a transient administrative change during the run. All historical authority remains unresolved absent independent provenance.
- A deadline/cancellation may prevent recording further local evidence; an unfinished exclusive run reservation must be treated as incomplete, never a successful run or reusable approval.

### Reading the evidence safely

`sanitized-report.json` is explicitly PROVISIONAL and has status INCOMPLETE, with the engine's candidate result in `inventoryStatus`. Only a successfully completed runner plus its exclusive `run-complete.json` receipt can finalize a run; the receipt binds the report SHA256, manifest digest, status and deadline. Validate the digest and receipt times, and treat missing/malformed receipts or any `run-failed.json` as incomplete/failed regardless of candidate content. Never infer G2 clearance from either file. Async writes finishing after cancellation can leave only provisional evidence; they cannot publish the synchronous final receipt. System suspension/filesystem failure is not a hard real-time guarantee: ambiguous finalization remains incomplete and requires operator review.

The Windows helper checks `.git` markers through the evidence path's ancestors as well as ResQMe's known worktree list. It rejects unrelated repository membership without scanning the disk. No repository/evidence ACLs were modified. The private manifest entry point also rejects Git-contained, redirected or non-file manifests before reading their contents.

## Future hosted execution requirements

This milestone is not authorization to run the hosted entry point. Before any real identity validation, metadata preflight or projected inventory, the owner must approve:

1. Exact reviewed executable, dependency lock, Node version and manifest digest.
2. Exact named operator email/stable subject and existing user ADC file/hash; separate identity-only authorization if claims are not yet established.
3. `resqme-943ee` / `519076598217` / `(default)` / `nam5`, expected G1 ruleset/source hash, fixed scopes and limits.
4. Exact local private evidence directory, owner/readers' OS SIDs and ACL policy, retention deadline and manual disposal responsibility/method.
5. One run ID, valid window and external approval reference, followed by the operator's exact interactive digest confirmation.

Do not manufacture these values from mock fixtures or a draft manifest. Do not reuse an incomplete run ID. Hosted inventory, subsequent G2-B decisions and overall G2 closure remain separate approvals.

## Reviewed local artifact hashes

Node runtime: `v24.18.0`. SHA256 of canonical sorted artifact-hash map: `d60307ec328317c8a653c3322a846e0b489362f0ea40037d6a79dde5ad74f50d`. This is an artifact-set digest, not an approved execution-manifest digest. It contains no ADC/evidence policy or execution approval. Rebuild/hash mismatches require review; do not copy mock credentials into a live manifest.

| Artifact | SHA256 |
| --- | --- |
| `firestore.containment.rules` | `7bff2de50c73415a3b12a6783f42ff621b1b04803ffc4e2634e6ba68e5d655f9` |
| `functions/lib/tools/g2_inventory/contract.js` | `1b9bffe2798c4d2b0b8fda3180c188c5bad08758841ca8115a1395e1526db6a4` |
| `functions/lib/tools/g2_inventory/hosted/approval.js` | `892f46b12f8c86d5b21fc71f8c8b3639770d66314a62afca1287d59acaa68a52` |
| `functions/lib/tools/g2_inventory/hosted/evidence.js` | `a74e77b2c094935bdd0e4f27c988f9a0ae2e34f7d38dec5c7f0919b8f6d4e1d8` |
| `functions/lib/tools/g2_inventory/hosted/runner.js` | `770430d9bd8363d21305da1687eae5ac5ea07cae54f30f9c525816092091905d` |
| `functions/lib/tools/g2_inventory/hosted/session.js` | `d02736bbb100fcd8515695be3efe3bcb92fa135b4c66c4374718c359651e7b2e` |
| `functions/lib/tools/g2_inventory/hosted/transport.js` | `5130db21238a34309c513f6c73c8651fb1b2d5fb0325f9ef7a2113b9689b7903` |
| `functions/lib/tools/g2_inventory/inventory.js` | `2529216ed47a260fac02f78da6c3fa44cef1186e1ec12ce4a8db5a8c9fea7bf0` |
| `functions/lib/tools/g2_inventory/query_codec.js` | `ade58420cf5f18d1c70ed22fa5dd82cce229e0b23fad1641804bc211a9c33a5f` |
| `functions/lib/tools/g2_inventory/runner.js` | `0c3b9aeda985fdcd097208dd9a5f30abf1bd0daf48c4f1bb68f950d839a35649` |
| `functions/lib/tools/g2_inventory/transport.js` | `4133fdb4956254bc2fa90a2049bc3df76574aad446507370890add602b187a7c` |
| `functions/package-lock.json` | `764c85f94a2ef3e1c081465d65a0639d2ef739729ffeed7698c6c4d4220fd705` |
| `functions/tools/g2_inventory/hosted/windows_evidence.ps1` | `4aec535e330a6031811dbcf1fdd2b603be7bbec77a17e53573ad544629304665` |
