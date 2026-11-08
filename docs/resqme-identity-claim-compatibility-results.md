# Identity claim compatibility correction

Date: 2026-11-08. Local-only correction; no credentials, tokens, hosted metadata or records accessed.

## Change

Accept exactly boolean true or string "true" for email_verified. Missing, false, malformed and noncanonical representations reject. If verified_email is also supplied it must be explicitly affirmative; it never substitutes for missing email_verified. Exact operator email/subject, lifetime, same-token, endpoint and G1 checks remain unchanged.

Google documents string true/false: https://docs.cloud.google.com/docs/authentication/token-types and https://developers.google.com/identity/openid-connect/reference . This confirms supported representation; the earlier private failure remains a candidate cause, not a verified diagnosis.

## Validation

- RED: new claim matrix failed at string true before correction (6 passed / 1 failed in focused session suite).
- GREEN hosted adapter: 24 passed, exit 0.
- Final Functions unit/inventory/auth regressions: 53 passed, exit 0, including actual auth-library path with mocked string claim.
- TypeScript build: exit 0 (included in final test command).
- git diff --check: exit 0.
- No emulator/Flutter rerun needed for this auth-tool-only change.

## Artifact binding

Runtime: v24.18.0. Lockfile and dependencies unchanged. Compiled session artifact changed; historical hashes/manifests must not be reused. This table is not an approved manifest or execution permission.

| Artifact | SHA256 |
| --- | --- |
| firestore.containment.rules | 7bff2de50c73415a3b12a6783f42ff621b1b04803ffc4e2634e6ba68e5d655f9 |
| functions/lib/tools/g2_inventory/contract.js | 1b9bffe2798c4d2b0b8fda3180c188c5bad08758841ca8115a1395e1526db6a4 |
| functions/lib/tools/g2_inventory/hosted/approval.js | 892f46b12f8c86d5b21fc71f8c8b3639770d66314a62afca1287d59acaa68a52 |
| functions/lib/tools/g2_inventory/hosted/evidence.js | a74e77b2c094935bdd0e4f27c988f9a0ae2e34f7d38dec5c7f0919b8f6d4e1d8 |
| functions/lib/tools/g2_inventory/hosted/runner.js | 770430d9bd8363d21305da1687eae5ac5ea07cae54f30f9c525816092091905d |
| functions/lib/tools/g2_inventory/hosted/session.js | af9bb72017332d6d13ac6530dff7dfe461a4595177abf64eb5bfb49a56fb12e9 |
| functions/lib/tools/g2_inventory/hosted/transport.js | 5130db21238a34309c513f6c73c8651fb1b2d5fb0325f9ef7a2113b9689b7903 |
| functions/lib/tools/g2_inventory/inventory.js | 2529216ed47a260fac02f78da6c3fa44cef1186e1ec12ce4a8db5a8c9fea7bf0 |
| functions/lib/tools/g2_inventory/query_codec.js | ade58420cf5f18d1c70ed22fa5dd82cce229e0b23fad1641804bc211a9c33a5f |
| functions/lib/tools/g2_inventory/runner.js | 0c3b9aeda985fdcd097208dd9a5f30abf1bd0daf48c4f1bb68f950d839a35649 |
| functions/lib/tools/g2_inventory/transport.js | 4133fdb4956254bc2fa90a2049bc3df76574aad446507370890add602b187a7c |
| functions/package-lock.json | 764c85f94a2ef3e1c081465d65a0639d2ef739729ffeed7698c6c4d4220fd705 |
| functions/tools/g2_inventory/hosted/windows_evidence.ps1 | 4aec535e330a6031811dbcf1fdd2b603be7bbec77a17e53573ad544629304665 |

## Remaining gates

Obtain renewed approval bound to the revised executable/manifest before any identity-only hosted retry. Do not execute the historical inventory adapter under the empty-baseline authorization. The separate bounded empty-baseline verifier still needs scope review for missing-parent Firestore traversal, Auth/Storage metadata, request caps and sanitized output. G2 remains blocked; no deployment, API/IAM change, account creation or data access is approved by this correction.
