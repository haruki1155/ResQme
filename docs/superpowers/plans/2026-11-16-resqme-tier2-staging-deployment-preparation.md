# ResQMe Tier 2 Staging Deployment Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` natively after owner authorization. No additional agents/worktrees. Steps use checkboxes.

**Goal:** Deploy only the reviewed eligibility correction, verify it independently, then perform separately authorized physical acceptance.

**Architecture:** Preserve the current Flutter/Keystore/callable architecture and shared student eligibility policy. Use an isolated seven-export package, exact Function selector, and metadata verification. No unrelated service/configuration change.

**Tech stack:** Existing Node 22.23.4, TypeScript, Firebase CLI 15.34.1, Flutter/Android and staging Firebase.

**Spec:** Owner's Phase 1/Phase 2 directive; `docs/resqme-tier2-eligibility-deployment-manifest.md`; `docs/qa/resqme-tier2-physical-device-checklist.md`.

## Global constraints

- Project `resqme-943ee` / `519076598217`, Node 22, Gen 2, `us-central1`, dedicated runtime account.
- Preserve `main` / `7ea3b1f` and all existing changes. No reset/revert, new worktree, unrelated staging, push or automatic deployment.
- No dependency, Rules, App Check, IAM/API, Extensions or cleanup-policy changes. No real student data.
- Approval is required before deployment; APK installation and synthetic hosted creation/use/cleanup are separate later gates.

## Review focus

- Shared-policy dependents must not be omitted: map the three QR plus four Tier 2 callables in Task 1.
- A full repository index contains 16 exports: require exact seven-export package and selector in Tasks 1/3.
- Runtime health and CLI exit can differ after cleanup-policy errors: verify metadata, never retry blindly (Task 3).
- Prior code has a known authorization gap: no automatic insecure rollback (Task 3).
- A correct APK and real fingerprint response are required for device evidence; simulated tests cannot replace them (Task 4).

### Task 1 — Review and freeze candidate (prepared)

**Files:** Six changed backend modules, corresponding backend tests, `functions/package.json`, `test/app/scanner_entry_flow_test.dart`; deployment manifest above. Protected local candidate path and hash are in that manifest.

- [x] Trace modified modules to exact update/exclusion lists.
- [x] Review already completed 150 Functions/154 Flutter checks; package the tested compiled runtime closure without changing production source.
- [x] Load candidate locally under Node 22; verify seven Gen 2 callables and dedicated service account without invoking handlers.
- [x] Record candidate SHA-256, content/source manifest, excluded configuration and recovery procedure.
- [ ] Obtain owner approval for the next scoped actions; preparation is not deployment.

### Task 2 — Preserve source identity

**Files:** Only the exact source/test/document list reviewed in the deployment manifest; no private evidence or generated package.

- [ ] If explicitly approved, stage that scope only, inspect staged diff and create one local commit; record SHA and verify candidate input fingerprints unchanged.
- [ ] Leave unrelated changes unstaged. Do not push. If source/package inputs change, regenerate/revalidate and present the new identity before deployment.

### Task 3 — Approved deployment and verification

**Inputs:** Owner-approved artifact/hash/allowlist, reviewed CLI prerequisites and bounded metadata permissions.

- [ ] Execute the mandatory identity/project/API/IAM/Rules/inventory/artifact preflight in the manifest; stop on mismatch.
- [ ] Capture current exact source/revision metadata and require a recovery decision if no security-safe rollback artifact exists.
- [ ] Deploy the seven Functions once using the exact isolated-root command; record all results/exit code.
- [ ] Independently verify all targets, excluded inventory and preserved policies. Stop on partial failure; no retry or configuration change.

### Task 4 — Separately approved device acceptance

**Files:** `docs/qa/resqme-tier2-physical-device-checklist.md`, acceptance report.

- [ ] Verify installed APK provenance; request installation approval if needed.
- [ ] Request one bounded fictional adult/reviewer session covering exact creation/use/cleanup before hosted writes.
- [ ] Execute active-QR scan, successful owner fingerprint, cancelled/failed authentication, explicit password fallback, wrong password, locking/background/logout/account switching, and old/revoked QR denial.
- [ ] Distinguish QR replacement from terminal school/device revocation; any revocation write/test must be explicitly in the synthetic session scope. Public QR status must never recreate an owner Firebase login or bypass Tier 2 authorization.
- [ ] Verify exact synthetic cleanup and report independent results. Classify demo readiness only after required actual-device rows pass.

**Handoff:** Phase 1 is prepared; stop here for the requested approval checkpoint. Phase 2 remains unexecuted. No new implementation or deployment is inferred from this plan.
