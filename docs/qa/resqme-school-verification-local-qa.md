# ResQMe School Verification and Pending QR — Local QA

**Date:** 2026-11-10  
**Result:** Local implementation validated; integration and hosted readiness remain blocked.

## Scope and evidence

This change adds private LRN capture, optional enrollment-code roster matching, school review, independent medical completion, and pending QR behavior. A pending QR is inert: public resolution returns only an inactive result until server-side eligibility passes. School reviewers receive only the exact candidate projection, and the backend checks reviewer assignment before reading the requested student profile. The five roster fixtures contain fictional data and are intended only for an isolated emulator.

The prior G4 hosted acceptance result is historical and unchanged. This work is local source only; it does not update the deployed Functions or project configuration.

| Check | Result | Evidence / boundary |
|---|---|---|
| Functions unit/build suite | PASS | `npm.cmd test`; 90 tests passed. |
| Focused Flutter tests | PASS | `flutter test test/features/registration test/features/qr test/features/school/school_review_screen_test.dart`; 56 tests passed. |
| Flutter analysis | PASS | `flutter analyze`; no issues found. |
| Functions build | PASS | `npm.cmd run build`. |
| Patch whitespace | PASS | `git diff --check`; only Git line-ending conversion warnings were reported. |
| Roster/Auth/Firestore/Functions emulator integration | NOT RUN | The local emulator startup previously attempted an ADC-related file write. It was stopped; the file was left untouched. No alternative emulator was used. |
| Physical device reviewer/registration/QR flow | NOT RUN | No device validation was part of this local run. |
| Hosted deployment or hosted data | NOT RUN | No deployment, API/IAM/Rules/App Check change, hosted account, or application-data access occurred. |

## Local workflow coverage

- LRN is required and validated; it is stored only in the private server-side profile and excluded from profile responses, reviewer projections, and QR payloads.
- Enrollment code is optional. A valid roster match can assign the trusted school and approve the school-review step; missing or unmatched codes follow manual review. Caller-supplied approval is ignored.
- Roster matching uses keyed HMAC identifiers, checks the matching name and one-time code claim, and rejects expired, duplicate, or already-claimed claims. The local seeder has loopback/demo-project guards and collision checks. It was not run.
- School approval is independent of medical completion. Completing medical information later can satisfy that separate requirement; revocation remains terminal.
- Pending QR creation and owner display are supported, but public resolution reveals no owner identity or medical data. Server eligibility requires school assignment/approval, completed medical data with matching revisions, and no revocation. Minors remain ineligible without a valid independently verified guardian record.
- The reviewer UI requires Firebase sign-in; trusted reviewer account provisioning and school assignment are not implemented by this change.

## Blockers before a demo or hosted use

1. Run the authored, loopback-only roster integration test in a safe emulator environment, including concurrent code-claim and retry behavior. Do not alter or recreate ADC as part of that work.
2. Provision a real roster through an approved trusted process and protect a high-entropy `RESQME_SCHOOL_ROSTER_HMAC_KEY`; neither is configured here.
3. Provision and verify named school reviewer accounts and trusted school assignments.
4. Resolve the separately approved Functions runtime IAM change: the current custom role lacks `datastore.entities.update`, which the roster claim, review, revocation, and QR activation transitions need. No IAM change was made.
5. Define and independently verify guardian authorization before activating minor accounts. No guardian workflow is added; minor QR activation is denied without a trusted verified guardian record.
6. Review the registration notice/privacy version because it now describes LRN and optional enrollment-code processing while retaining the current notice version identifier.
7. Rebuild/revalidate the deployment artifact and obtain separate deployment authorization. Local tests do not validate deployed behavior.

**Readiness:** The local workflow and focused tests pass, but the transactional emulator test, trusted school setup, required runtime permission, and hosted rollout prerequisites remain outstanding. Do not use this build for hosted school onboarding until those gates are resolved.

## 2026-11-15 — Tier 2 completion evidence update

See `docs/qa/resqme-tier2-completion-acceptance.md` (from this QA directory: `resqme-tier2-completion-acceptance.md`) for the current local results and blockers. Preserve the historical results above: earlier emulator failures and later G6 staging successes concern different environments/dates. G6 section 14 reports active-QR/password-access/rotation staging success on 2026-11-12; physical biometric medical read remained unverified. This session made no hosted/device change and did not revalidate live configuration. Three new offline Tier 2 eligibility-contract regressions fail; no backend fix was applied. Overall readiness is CONTROLLED_DEMO_BLOCKED.
