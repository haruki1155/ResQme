# ResQMe test-contract reconciliation — 2026-11-10

**Result:** The four reported failures are outdated fixture/assertion contracts. No backend or public-privacy defect was established by these failures. Offline validation passes; emulator integration was not run in this task. The existing isolated CLI profile is not cleared for reuse.

## Contract decisions and exact changes

The approved School Verification and Pending QR design supersedes the older active-only issuance assumptions. It requires a 12-digit string LRN, permits an inert pending QR, separates school approval from medical completion, and requires independently verified guardian authorization for minor activation. The owner-profile compatibility response is separate from public QR resolution, which returns only `{active:boolean}`.

| Failure | Classification | Authorized test-only correction |
|---|---|---|
| Shared onboarding setup omits LRN | Outdated fixture | Add distinct fictional 12-digit LRNs to the three test users. Preserve invalid-LRN rejection elsewhere. |
| Eligibility setup assumes an old `unverified` QR can be reused | Outdated fixture / deferred migration | Explicitly assert that legacy issuance is rejected without mutating that credential and public resolution is inactive. Delete only that synthetic legacy fixture before exercising fresh pending issuance. No application migration is implemented. |
| Owner profile assertion omits medical status/revision | Outdated assertion | Include `medicalStatus:not_started` and `medicalRevision:0` in the existing exact response assertion. Keep private-field and foreign-UID checks. |
| Five-student test forbids all owner contact fields | Outdated assertion using public restrictions on an owner-only response | Assert the exact owner compatibility key allowlist, null optional phone, and exact fictional/empty contact projection. Keep private LRN omission, exact reviewer projection, and boolean-only public resolver assertions. |

`onboarding_integration.test.ts` also now verifies that unassigned/synthetic-only users receive **pending** credentials and that anonymous public resolution remains inactive. The old test expected issuance itself to fail, contradicting the approved pending-QR flow. It still forbids activation. No tests were removed.

Cleanup in `onboarding_integration.test.ts` and `profile_integration.test.ts` now removes the exact test-owned lookup derived from each credential before deleting its credential. Existing unrelated cleanup remains unchanged.

Changed application-tree files are exactly four existing tests:

- `functions/test/onboarding_integration.test.ts`
- `functions/test/eligibility_integration.test.ts`
- `functions/test/profile_integration.test.ts`
- `functions/test/school_roster_fixtures_integration.test.ts`

This report is the only new documentation file. No production code, dependencies, security validation, Rules, or configuration changed.

## Fresh offline validation

| Check | Result | Evidence |
|---|---|---|
| Configured offline Functions suite | PASS | Node 22.23.4; `npm.cmd --prefix functions test`; 90 tests passed, zero failed/skipped/cancelled. |
| TypeScript build, including changed integration files | PASS | The configured test command runs `npm run build` / `tsc` first; exit code 0. |
| `git diff --check` | PASS | Exit code 0; existing CRLF conversion warnings only. |
| Production-source preservation | PASS | All 23 pre-edit `functions/src` SHA-256 fingerprints match. No credential was hashed. |
| Emulator or hosted integration | NOT RUN | No Firebase CLI invocation, emulator, handler invocation, or hosted access in this task. |

Offline unit success and compilation do not establish that the corrected integration tests pass. No emulator result is implied.

## Corrected integration matrix

Each row below is **NOT RUN after reconciliation**. Fourteen integration tests and four Rules tests remain in the existing commands.

| Existing scenario | What should now execute | Remaining limitation |
|---|---|---|
| Five synthetic students | Three automatic matches; missing-code manual-review case; already-claimed conflict; stable pending QR; owner-only profile projection | Requires emulator rerun; no real roster authority implied. |
| Enrollment-code race | Two UIDs cannot claim the same code/roster identity; winner retry remains idempotent | Previously passed, but no fresh emulator run here. |
| Registration validation/retry | Anonymous rejection, invalid LRN rejection, unchanged repeated registration, altered-data rejection | Existing assertions retained. |
| School approval and legacy QR | Legacy rejection without mutation; inactive legacy resolution; trusted manual approval independent of medical | No automatic upgrade or production legacy migration. |
| Reviewer authorization | Self-review and wrong-school approval rejection; candidate access by unauthorized/cross-school users rejected | Provisioned reviewer fixtures are fictional and local only. |
| Medical completion | Required fields/replay; school-approved adult remains pending until complete; synthetic save/replay/concurrent revisions/stale-contact/clear | LRN setup now allows all five formerly hook-blocked test bodies to execute. |
| QR lifecycle | Pending → active after full adult eligibility; old replacement inactive; replacement active; revocation terminal | No activation assertion was weakened. |
| Minor guardian gate | Complete medical information still leaves a minor inactive without independent guardian proof | No fake guardian verification is added. |
| Owner profile/privacy | Metadata and compatibility fields; private LRN absent; arbitrary fields excluded; foreign UID rejected; pending QR persistence | Public privacy remains a separate exact `{active}` response assertion. |
| Unassigned/synthetic-only accounts | Pending credential allowed; inactive public response; unassigned school preserved | Pending issuance is not Tier 2 authorization. |
| Firestore Rules | Unauthenticated/cross-account denial; protected profile/medical/QR writes rejected | Local checked-in Rules tests do not prove hosted deny-all Rules. |

Existing gaps remain: the current integration scripts do not provide full device biometric/password Tier 2 acceptance, all expired/invalid enrollment-code combinations, a resolver rate-limit integration matrix, or a QR activation race matrix. Related offline unit coverage is not emulator or device proof.

## Isolated two-byte config-store assessment

Assessment used only file metadata, file/parent ACLs, installed CLI source, and existing sanitized incident evidence. No credential or config-store contents were read, copied, hashed, modified, or deleted. The profile was not reused.

- File remains 2 bytes; created `2026-11-10T13:40:41.6415535Z`, modified `2026-11-10T13:40:41.6430623Z`, during the prior session shutdown.
- Owner is the current Windows account. File ACEs are inherited Full Control for only that account, SYSTEM, and Administrators; no sandbox-group read grant was found.
- Installed Firebase CLI 15.34.1 `lib/bin/cli.js:71–95` registers an exit hook that deletes `lastError` when the error/TTY branch does not apply.
- Installed `configstore/index.js` returns an empty object when its file is absent. Its `delete(key)` unconditionally saves the resulting object; its writer serializes JSON. An empty-object serialization has length 2. This provides a source-supported non-authentication explanation consistent with the observed size and shutdown timing.
- `firebase-tools/lib/configstore.js` constructs `Configstore` without defaults. Config-store presence alone does not demonstrate a valid Firebase account or credential bridge.
- **Likely explanation:** ordinary CLI exit bookkeeping. **Not confirmed:** actual bytes, exact writer, or current account/session contents. No misuse is established, and absence of observed misuse is not a security clearance.

The exact file is left untouched. Operator acceptance of this metadata/source assessment, or a separately authorized safe profile decision, remains required before reusing the isolated profile. This task does not authorize startup or credential remediation.

## Preservation and next gate

Baseline was `main`, HEAD `cd5d9f2a412e3bcb6aa501a5729824ea6685dc73`, with 100 existing Git status entries. Pre-edit copies of the four test files, status, and production-source fingerprints were stored outside the repository in a protected reconciliation directory. Incremental test deltas are recorded separately from the owner's pre-existing changes. Existing modifications were not reset or overwritten.

Expected added status entries are the newly modified tracked onboarding integration test and this new report; the other edited tests already had status entries in the original 100. The original untracked five-student test remains untracked.

**Readiness:** test-contract reconciliation is ready for review and a separately authorized isolated integration run after profile clearance. It is not an integration PASS. Resolve any newly exposed backend/privacy failure with separate application-change authorization; do not edit production behavior to force these tests green. Legacy production migration, trusted school provisioning, guardian authority, runtime IAM, deployment, and device acceptance remain outside this task.
