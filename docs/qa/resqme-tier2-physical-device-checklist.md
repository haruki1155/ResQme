# ResQMe protected Tier 2 — physical-device acceptance checklist

**Status: PREPARED, NOT EXECUTED.** All rows below require new evidence; passing local tests are not physical acceptance. Controlled staging demo remains BLOCKED until mandatory rows and cleanup pass.

## Preconditions and authorization

- [ ] Separately reviewed deployment authorization for the new backend eligibility corrections; verify the deployed artifact/revisions before using staging as evidence for those fixes. Do not redeploy from this checklist without approval.
- [ ] Bounded read-only staging verification approved: exact project `resqme-943ee` / `519076598217`, expected Function inventory/runtime/dedicated account, unchanged deny-all Rules and App Check posture. Stop on mismatches; no configuration repair is implied.
- [ ] Record installed debug build package/signer/hash and confirm it contains the committed biometric/session fixes. If an update is needed, obtain APK installation approval; do not clear device data automatically.
- [ ] One separately approved fictional-only session, at most two disposable adult accounts (student and reviewer/auth-only second account), maximum 60 minutes. Approve exact Route A reviewer/school-assignment writes and creation/use/cleanup of per-UID profile, acknowledgment, medical, approval/receipt, credential/lookup, device, challenge and password-rate records. Do not reuse old approvals or overwrite preexisting resources.
- [ ] Owner present for fingerprint prompt. Biometrics already enrolled on the owner's test device; no biometric images/templates are collected. Do not change fingerprint enrollment or deliberately induce OS lockout without permission. Any biometric enrolled on the device may satisfy Android's prompt; account-bound signing and backend authorization remain mandatory.
- [ ] Evidence records only PASS/FAIL/BLOCKED, counts, safe error categories, build/function metadata and cleanup outcome. No passwords/tokens/QR payloads/full UIDs/signatures or medical/contact values in retained logs/screenshots. Use only fictional adult data and ephemeral exact-path tracking for cleanup.

## Independent test rows

| ID | Scenario / action | Required result | Result |
|---|---|---|---|
| P1 | Register fictional adult; inspect privacy dialog before and after explicit check/confirmation | Initially unchecked; decline/dismiss do not register; one explicit checked confirmation creates one acknowledgment | NOT RUN |
| P2 | Trusted reviewer assignment/approval, required medical form, active QR | School and medical gates enforced; public QR only returns active status; no owner/medical disclosure | NOT RUN |
| B1 | Authenticate owner; enroll account-bound device key using fresh password; complete fingerprint prompt | Backend validates challenge/proof/eligibility; only conditions, allergies and primary contact appear | NOT RUN |
| B2 | Unlock using existing biometric enrollment | Successful fingerprint signs a fresh one-use challenge; no medical values before server authorization | NOT RUN |
| B3 | Cancel prompt | Safe cancellation message; remains locked; no automatic password fallback or protected read | NOT RUN |
| B4 | One unsuccessful fingerprint attempt, then cancel or explicitly retry | No unlock after failure; OS retry remains possible; terminal failure/cancel remains locked | NOT RUN |
| B5 | OS lockout | Distinct lockout guidance; no unlock; explicit account-password fallback remains available | NOT RUN — simulate only unless safely authorized |
| B6 | Biometrics unavailable/no enrollment/invalidated key | Safe unavailability or re-enrollment guidance; never grant access locally | NOT RUN — no OS enrollment change authorized |
| F1 | Explicit Use password once with correct account password | Fresh same-owner reauthentication; server eligibility and limits apply; only approved fields returned | NOT RUN |
| F2 | Wrong password | Password-specific error; no record displayed, no automatic biometric success | NOT RUN |
| S1 | Press Lock with a displayed record and password text present | Medical values, contact values and password text disappear | NOT RUN |
| S2 | Background while record displayed, then resume | Sensitive view cleared; fresh explicit authorization required | NOT RUN |
| S3 | Background during outstanding authentication/read, then resume | Prompt/request cannot repopulate the view through late success/error; explicitly reauthorize | NOT RUN |
| S4 | Logout; switch to second account; switch back | Old protected record never appears; prior response cannot cross account/session boundaries | NOT RUN |
| S5 | Navigate away/back while operation completes | Disposed/locked screen cannot be repopulated by a stale completion | NOT RUN |
| A1 | Expired/replayed/wrong-owner/device/operation proof, if included in approved session | Server denies; no medical fields; challenge cannot authorize a second read | NOT RUN |
| A2 | No trusted school assignment, unapproved/revoked school, incomplete/mismatched medical revision | Every protected server entry denies; no QR/prompt bypass | NOT RUN |
| Q1 | Reopen My QR; cancel replacement; explicitly replace once | Ensure reuses credential; cancelled replacement creates no lookup; exactly one confirmed replacement call; old inactive/new active | NOT RUN |

For unsupported/unsafe physical conditions, retain BLOCKED/NOT RUN and report corresponding automated simulation separately. Do not label a simulated lockout or a mocked signature as physical proof. If a mandatory acceptance requirement remains unverified, do not claim demo readiness.

## Closeout

- [ ] Track exact session-created resources and ownership in ephemeral private memory/evidence. Verify every document/user is test-owned before deleting it.
- [ ] Delete only approved exact documents (including acknowledgment, approval/medical receipts, every session lookup/challenge/device/rate entry) and the two exact disposable Auth users. Verify each exact path/user absent. No collection-wide deletion or unrelated data access.
- [ ] If cleanup ownership/outcome is uncertain, preserve resources and report the minimum required cleanup reference through an authorized channel. Do not guess or broaden deletion.
- [ ] Lock/leave the protected view and restore only session-changed settings. No uninstall, app-data clear, unenrollment or device reset without authorization.
- [ ] Preserve sanitized results and remove ephemeral secrets according to the approved session handling. Confirm no credential or medical values appear in retained evidence.
- [ ] Record final PASS/FAIL/BLOCKED per row, counts, device/build and deployed revision provenance, cleanup verification, unresolved QR findings, and `CONTROLLED_DEMO_READY` or `CONTROLLED_DEMO_BLOCKED` with reasons.

This checklist grants no deployment, hosted write, device install or real-student rollout permission. Guardian provisioning, real-school authority and privacy/security approval remain separate requirements; fictional positive guardian unit fixtures are not consent evidence.
