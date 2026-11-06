# G2-A local inventory implementation and operation

Date: 2026-11-06. This milestone implements a local-only utility; it does **not** run hosted inventory, establish historical trust, perform G2-B remediation or close G2. G3/G4 remain blocked. The owner's G2-A implementation instructions authorize local code/testing and one scoped commit after validation; earlier specification/deployment documents remain preserved.

## Files and responsibilities

- `functions/tools/g2_inventory/contract.ts`: exact field/path allowlists, fixed safety limits, safe errors and emulator-only target guard.
- `transport.ts`: bounded REST `listCollectionIds` and projected `runQuery`; no Admin/ADC initialization, Auth enumeration, callable invocation or mutation API.
- `inventory.ts`: bounded pagination, timeout/cancellation, scalar validation, independent-evidence classification contract, cross-collection findings and alias-only shareable reporting.
- `runner.ts`: guarded local CLI and synthetic temporary evidence writer; no hosted flags or hosted execution path.
- `functions/test/inventory.test.ts` and `inventory_integration.test.ts`: fake-transport/security tests and actual emulator projection/runner checks.
- `functions/package.json` and `tsconfig.json`: build/test/CLI wiring only; dependencies and configured Node 22 Functions target unchanged. The deployed callable entry point does not import/export inventory tooling.
- Implementation plan: `docs/superpowers/plans/2026-11-06-resqme-g2a-local-inventory-implementation.md`.

## Contract and safety decisions

Only `demo-resqme` with `127.0.0.1:8080` or `localhost:8080` is accepted. The transport normalizes the latter to literal `127.0.0.1` and uses HTTP locally; redirects are rejected. Conflicting project configuration, missing endpoints, arbitrary scopes and hosted flags are rejected before I/O. Imports do not initialize clients or make requests.

The emulator requires its fixed `Authorization: Bearer owner` marker to perform privileged metadata reads under restrictive Rules. It is used only after the loopback/demo guards; it is not a real OAuth credential. No CLI credentials, ADC or hosted execution credentials are loaded. Initial integration failures proved anonymous requests were denied; the marker corrected the local transport without changing Rules.

Every runQuery has explicit `select.fields`. Root queries request only approved metadata fields. Reference-only acknowledgment/request group queries request `__name__` explicitly: an empty REST field list can mean all fields and is never sent. Emulator tests verify sentinel name/contact/medical/QR/digest fields do not reach query results. Unexpected fields, group paths, oversized bodies and malformed/streamed error responses fail closed. Root collection discovery does not recursively scan discovered collections or establish complete discovery of unknown nested collections.

Limits are page100, query500, total2000, collectionIDs100, request30s and overall10min; tests can lower, never raise, them. Hitting a cap is conservatively INCOMPLETE, even if the actual dataset might end exactly there. Queries are ordered by full document reference with validated advancing cursors. A multi-query run is not atomic. Timeouts/cancellation terminate the inventory and abort active requests; remote errors never become empty-database clearance.

The inventory defaults every examined historical record to UNRESOLVED. A separate pure classifier supports TRUSTED/UNTRUSTED only for independently reviewed provenance assertions; no CLI/document fields supply such evidence. Matching UIDs, correct schemas, enabled QA flags, synthetic flags and timestamps never establish trust. Report `COMPLETE` means the bounded inventory finished, not that records are safe: every report includes `clearance: NOT_GRANTED`, `g2Complete:false`, and `g2BRemediationPerformed:false`.

Unexpected projected values are suppressed and halt processing with an incomplete/failed report; raw error messages and identifiers do not enter shareable reports. Missing fields and cross-collection conflicts remain review concerns. Private reference metadata/alias maps remain outside Git. Root IDs and raw UIDs are not printed in shareable results.

## Local operation

Use only fictional fixtures. Verify port ownership and start/reuse one compatible local Firestore emulator session. Do not connect this executable to hosted Firebase.

```powershell
npm.cmd --prefix functions run build
$env:CI = 'true'
firebase.cmd emulators:start --config firebase.integration.json --project demo-resqme --only firestore
```

In another terminal:

```powershell
$env:GCLOUD_PROJECT = 'demo-resqme'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
npm.cmd --prefix functions run inventory:local
```

The CLI outputs sanitized JSON and a local temporary evidence directory. Exit 0 means COMPLETE inventory only; exit 1 means INCOMPLETE/FAILED or local execution failure; exit 2 means configuration/arguments rejected before I/O.

Private synthetic evidence and its alias map are written to a new OS temporary directory `resqme-g2a-synthetic-*` outside the repository; sanitized output is stored beside it. Local files request mode 0600 where supported; this does not establish Windows ACL guarantees. Retention is operator-controlled temporary retention for local review, with no automatic deletion. These defaults are **not an approved hosted evidence policy**.

## Validation

RED/GREEN evidence includes missing implementations, denied anonymous emulator requests, expected failure of the not-yet-created CLI, and a reproduced HTTP-200 error-envelope false-empty regression. One assertion incorrectly expected the root paginator to request 100 IDs after consuming one; corrected it to require the remaining budget of 99 rather than weakening the bound.

| Check | Verified result |
| --- | --- |
| Functions TypeScript build | Passed, exit 0 |
| Inventory focused unit/security suite | 17 passed within the final general command |
| Complete Functions unit/regression command | 29 passed (12 existing + 17 inventory), exit 0 |
| Inventory emulator integration | 3 passed, 0 skipped, exit 0 |
| Existing Firestore Rules suite | 4 passed, 0 skipped, exit 0 |

Integration seeded and removed only its own fictional emulator fixtures, including synthetic authorization flags required to test forgery handling; it did not grant hosted QA entitlement. No hosted SDK, project endpoint, Auth users or Functions emulator was used. Permanent Rules and application functionality were not changed. Flutter rebuilds were unnecessary for this backend-tool-only milestone.

Local validation evidence directory: `%TEMP%/resqme-g2a-validation-20261106201535`. Temporary evidence is not committed. Node 24.18.0 was used locally; Node 22 deployment parity remains a separate gate.

One independent final review found a second false-empty case: an HTTP-200 collection-discovery error object could be accepted as an empty page. A regression reproduced COMPLETE incorrectly, then the parser was restricted to legitimate collection-page keys; the final 29-test suite and three integrations passed. No other blocking findings or deferred minors were reported. This was the single final-review fix pass.

## Hosted inventory remains a separate milestone

This executable has no hosted mode. Before a separately reviewed hosted artifact can run, obtain exact approval for executable/source hash, `resqme-943ee`/`(default)`, named operator identity, field masks, read/query limits, active G1 deny-all verification, private evidence destination and its access controls, retention and disposal policy. Root collection/group coverage limitations must be accepted. No hosted reads are authorized by this implementation.

Following hosted inventory, independently review provenance and obtain exact G2-B remediation approval. Neither a complete scan nor a proposed cleanup establishes overall G2 closure. Keep G1 containment and the G3/G4 hold until the owner accepts verified remediation and G2 closure.
