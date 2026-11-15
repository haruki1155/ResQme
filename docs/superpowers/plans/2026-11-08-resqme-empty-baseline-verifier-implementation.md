# Empty-baseline verifier local implementation plan

Spec: docs/superpowers/specs/2026-11-08-resqme-empty-baseline-verifier-design.md (owner approved with three corrections). Native sequential execution; TDD, systematic debugging and final independent review. Existing checkout; no credentials or hosted execution.

- [ ] Task1: correct design tenant path, remaining-cap pagination and metadata-only listing. Write synthetic local Firestore wire test with existing and missing-parent sentinels. Establish supported request before selecting transport; if no field-free response can be established, record blocker and keep executable unavailable.
- [ ] Task2: implement small separate baseline protocol/engine under functions/tools/empty_baseline with mock HTTP and identity injection. Tests first: tenant path, global cap across bucket populations, missing parents, error/early-stop/unknown counts, identity-only no Firebase calls and unchanged Rules. No historical runner imports.
- [ ] Task3: bounded network/session and approval boundary, pure imports, local-only tests, no automatic CLI/credential loading. Reuse verified identity semantics without invoking old inventory. Review exact artifact set before executable package; no package generated until tests and fresh review pass.
- [ ] Task4: focused/full Functions tests, build, synthetic emulator test, diff check and independent read-only review. Correct findings with regression tests; document limitations, preserve Node24 local / Node22 deployment distinction. Scoped commit only validated changes.

Expected commands: npm.cmd --prefix functions run build; node --test functions/lib/test/empty_baseline*.test.js (unit explicit; integration with demo-resqme/loopback env); npm.cmd --prefix functions test; git diff --check. All exit0 before completion. Current compatible emulator may be reused; do not start duplicate or stop unrelated sessions.
