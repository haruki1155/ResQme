# Hosted inventory approval checkpoint

Date: 2026-11-08

## Current acceptance

Owner reports emulator and phone registration/QR testing completed. This is owner-reported device acceptance, not an agent-observed hosted Firebase result. Registration/QR backend emulator integration most recently passed 9/9 tests. Application source checkpoint: 50670a2.

## Source synchronization review

Local main was 33 commits ahead of freshly fetched origin/main with no divergence. Outgoing commit snapshots were checked for private-key/service-account/long refresh-token/GitHub-token patterns: no matches. No runtime inventory manifests, private metadata, alias maps or completion receipts were found tracked. No checked-in GitHub Actions or Vercel deployment configuration was found. This is a bounded review, not a guarantee against every secret or an audit of external GitHub integrations. Existing Firebase client configuration is unchanged; it is not a server credential.

Uncommitted url_launcher dependency/lock and Windows generated-plugin changes remain excluded from the push. No new source/backend work is needed merely to synchronize commits.

## Remaining inventory approval decisions

Reuse the previously designated Firebase operator. No new Firebase account or repeated operator-email selection is required. The prior CLI deployment identity must not be confused with verified ADC token-principal identity. Recover the existing private identity record when assembling the manifest; missing ADC claims still fail closed. Do not load ADC or request a token under this preparation.

Owner must approve these values before execution:

1. Evidence directory: exact pre-existing local Windows fixed-NTFS directory outside Git, reparse points and sync locations; owner SID and approved reader SIDs. SYSTEM/Administrators only when explicitly approved. Adapter inspects but never repairs ACLs. Operator attests unsynced storage.
2. Retention: exact deadline, responsible operator and disposal method. No default retention period or automatic deletion is assumed.
3. Scope: reuse the approved engine's exact projection allowlists, not full student or medical documents; reference-only discovery for unknown collections. Maximum page100/query500/total2000/collectionIDs100/request30s/overall10min. Incomplete/error/unresolved results never mean clearance.
4. Target: resqme-943ee / 519076598217 / (default) / nam5. Expected G1 ruleset aa4be7e8-ce25-44d1-afd8-c10654658bab and containment SHA256 7bff2de50c73415a3b12a6783f42ff621b1b04803ffc4e2634e6ba68e5d655f9; verify fresh before and after separately authorized reads. Never restore public Rules.
5. Execution: unique run ID, UTC validity window, approval reference, exact compiled artifacts/lock/runtime and final canonical manifest digest. Refresh local hashes before approval; do not reuse a previous digest after changes. The named operator must perform the exact interactive confirmation; agent-created configuration is not approval.

The private manifest binds existing ADC path/hash and effective expected email/stable subject. It is stored outside Git with approved access controls. Do not paste credentials or raw private evidence in chat or commit them.

## Subsequent gates

After inventory, review provenance and approve exact remediation if needed. G2 is not automatically closed by an inventory COMPLETE result. G3 API/IAM/App Check/Node22 readiness, G4 deployment and hosted synthetic account creation each retain their separate approval boundaries. No API enablement, deployment, QA grants, account creation or historical record changes occurred during this checkpoint.

## Authorized bounded empty-baseline attempt � 2026-11-08

The owner explicitly authorized read-only verification of staging project/database, deployed Rules, Firestore record existence (including missing-parent descendants), Auth-user existence and Storage-object existence. This replaces the full historical-inventory execution requirement for an empty-baseline attempt only. Deployment, configuration changes, account creation and contents remain excluded.

Result: BLOCKED before Firebase metadata or data requests. The existing authorized-user ADC token matched the designated operator email, had a subject identifier with no conflicting subject claims, and sufficient lifetime. The required `email_verified === true` assertion was not satisfied. The installed Google auth library preserves token-info response claims; it does not discard that field. No credential replacement, scope expansion or weakened identity condition was attempted. This result does not establish whether the field was absent or false, nor whether a differently named provider claim would be equivalent; such a compatibility change requires evidence and review.

Firestore existing-document count: UNKNOWN. Nested-document check: NOT RUN. Auth-user count: UNKNOWN. Storage-object count: UNKNOWN. Deployed G1 Rules: NOT REVERIFIED. Empty baseline: NOT ESTABLISHED. G2 remains blocked; G3/G4 are not authorized by this attempt.

One initial identity request was rejected with HTTP400 because the temporary request adapter omitted the library's authorization header. This local adapter defect was corrected; the subsequent identity result above is the actual blocker. No Firebase requests occurred in either attempt. The temporary diagnostic is outside Git and contains no credential values, token values, identifiers from records or private evidence. Only sanitized identity booleans were emitted.

Next step: review identity-claim compatibility in a bounded token-info diagnostic that reports claim presence/types only, then either demonstrate the same verified-identity guarantee or use suitable existing credentials under explicit approval. No ADC setup or permission changes are implied. Preserve deny-all containment; never treat unperformed existence checks as an empty database.

## Owner disposition after the blocked attempt

The owner subsequently confirmed that `resqme-943ee` is a debug-only project and has never stored ResQMe application data, accepted the submitted Firestore `(default)`, Authentication, and Storage screenshots as supporting evidence, and explicitly approved the owner-attested empty-baseline evidence standard with its residual uncertainty.

**G2 is accepted under this owner-attestation exception.** This supersedes the earlier pending/blocked disposition only as an evidence-standard decision. It does not change the historical result above: the verifier made no Firebase requests, no emptiness was technically established, and the screenshots are not an exhaustive historical inventory. It also does not verify deployed Rules or authorize any remote operation.

The next authorized work is the read-only G3 backend readiness review. G4 deployment and hosted testing remain unauthorized pending separate approval.
