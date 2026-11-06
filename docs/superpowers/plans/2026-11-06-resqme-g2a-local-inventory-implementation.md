# G2-A local historical inventory implementation plan

Execution: Superpowers executing-plans, native sequential; TDD and verification before completion. Existing checkout only. This owner-authorized implementation supersedes the draft specification's implementation hold, not its hosted-read or remediation holds.

Spec: `docs/superpowers/specs/2026-11-06-resqme-g2-historical-authorization-inventory-design.md` plus the owner-supplied G2-A implementation clarifications.

Goal: a bounded, projection-only, emulator-only inventory utility. No application feature, hosted access, G2-B, G3 or G4 work.

Architecture: four small TypeScript modules under `functions/tools/g2_inventory`: contract/allowlists; constrained loopback REST transport; inventory/classification/reporting; CLI. Existing Node fetch and Functions test/build dependencies suffice. Compile tools through the existing TypeScript build; do not export them as Cloud Functions.

- [x] Task 1 contract: define immutable allowlists/limits, safe errors, local-only configuration and result types; record clarifications and preserve the existing dirty tree.
- [x] Task 2 reads: RED/GREEN fake-transport tests inspect actual REST query bodies. Root discovery uses paginated listCollectionIds; runQuery always has explicit projections. Reference-only queries select `__name__` explicitly; never send an empty projection that could mean all fields. Only approved group names are queried; reject returned paths outside their approved prefixes.
- [x] Task 3 bounds: RED/GREEN deterministic reference ordering, cursor validation, collection/document caps, deadline, request timeout and cancellation. Conservative cap hits are INCOMPLETE; errors never imply empty state.
- [x] Task 4 classification: RED/GREEN independent evidence classification; no evidence means UNRESOLVED. Inventory itself accepts no provenance claims from documents or CLI. Schema/status validation yields concerns, never authority.
- [x] Task 5 reporting: RED/GREEN sanitized aliases/counts, bounded scalar validation, no identifiers/values in shareable output or errors; private synthetic evidence remains outside Git. Preserve distinction between inventory completion, remediation and G2 closure.
- [x] Task 6 runner/validation: CLI requires demo-resqme and loopback Firestore, rejects hosted flags/config before I/O, creates only synthetic temporary evidence. Validate actual projections against one local Firestore emulator including missing parents, sentinels and unexpected group paths. Run focused tests, existing Functions regressions/build and diff check; one final read-only review, then commit explicit milestone paths only.

Review focus: masks must be applied by the server; imported modules must perform no I/O; timeouts must terminate ignored signals; group scans do not prove discovery of unknown nesting; malformed projected values must not enter evidence; no sanitized report can grant clearance.

Defaults: page100/query500/total2000/collectionIDs100/request30s/overall10min, with lower-only limits exposed for local tests. Stop all collection on any unsafe result rather than widening scope. No hosted credential loading or hosted-run shortcut. No remote preflight in this local-only milestone. Local runner does not recheck G1 remotely: that remains mandatory for a future separately reviewed hosted artifact.

Evidence policy: synthetic local temporary files only for this milestone. A future hosted artifact requires an approved private storage path, access-control policy, named operator and retention/disposal policy before any read; no hosted retention policy is invented here.

Commit after checks: `feat(resqme): add local historical authorization inventory`. Preserve unrelated UI changes, permanent/containment Rules and existing untracked documents. Stop after local implementation; report G2-A local completion separately from overall G2.
