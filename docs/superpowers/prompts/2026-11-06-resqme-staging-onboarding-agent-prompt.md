# Agent Kickoff — ResQMe Hosted Staging Onboarding with Synthetic Medical Records

> **Execution gate:** The project owner approved the referenced design on **2026-11-06**. Read the companion implementation plan and obtain its execution approval before editing application code. Hosted staging deployment still requires a separate go/no-go with exact affected resources.

You are working in my existing **ResQMe Flutter Android + Firebase** repository. Use the **Superpowers** workflow: read the approved design and `docs/superpowers/plans/2026-11-06-resqme-hosted-staging-onboarding-implementation.md`, then use `superpowers:executing-plans` (or the execution method I approve), `superpowers:test-driven-development`, `superpowers:systematic-debugging` for failures, and `superpowers:verification-before-completion` before claiming success.

## Mission

Build a **small, working hosted-staging onboarding pilot** against `resqme-943ee`:

**Register/sign in → optional synthetic medical record (Complete now / Skip for now) → server-generated UNVERIFIED Tier 1 QR → existing public emergency dashboard.**

The user can later tap **Finish Medical Record** from a non-blocking dashboard reminder; existing student accounts can sign in, sign out, recover passwords, see their own QR, and view/update their synthetic medical entry. Guest users retain full public first-aid, hotline and DRRM access with **no account**.

This changes only two earlier registration exclusions: (1) self-registered pending accounts may get an **unverified, non-authorizing** QR; (2) synthetic-only medical entries can be saved privately in staging. It does **not** introduce verified student status, real minor guardian authorization, medical responder access, or Tier 2 permissions.

## Source of truth and no-surprises guardrails

1. Read local `AGENTS.md`, the new **owner-approved** 2026-11-06 design, the 2026-11-04 registration spec, existing Superpowers plans, and `docs/registration-milestone-results.md` / `docs/registration-local-testing.md` if present. The prior agent reported registration Tasks 1–6 completed and committed; verify local commits and actual code rather than recreating them.
2. Map actual files before proposing additions. Reuse current theme, dashboard, Auth repository, `createStudentRegistration` callable, Firestore Rules and routing. Avoid new routers, duplicate contacts, duplicate Firebase initialization or unrelated refactors.
3. Use **the existing checkout**, no new worktree (storage constrained). Preserve user changes and untracked `docs/mockups/`; never reset/clean or use `git add -A`. Stage only relevant paths, and commit each independently testable slice.
4. **Staging synthetic-only:** no real student or medical data. Show clear TEST MODE labeling. No nurse/staff permissions, biometric flow, guardian email verification, school approval, roster import, public QR scanner, replacement, production/release Firebase or actual medical emergency response.
5. Allow direct registration/login against **hosted `resqme-943ee` only in an explicit debug/staging mode**. Validate emulator vs hosted selection so there is no accidental remote fallback. Keep the configured Functions Node 22 target unless evidence requires an approved change; local Node 24 testing alone is not a reason to change it.

## Implementation slices — keep them lean and test-first

### Slice A — Hosted sign-up and state recovery

- Verify Email/Password Auth is enabled in staging; if a remote configuration change is necessary, report it and ask before changing settings.
- Reuse existing `createStudentRegistration` server contract, versions and acknowledgments. Auth-created/profile-incomplete recovery must not create a duplicate account.
- Ensure 17 → `pending_guardian`, 18 → `pending_review`; **neither becomes `approved`**, regardless of QR or medical completion.
- Preserve login, sign-out, password-reset, owner-only profile read and public guest dashboard. No email or guardian verification is implied or silently marked complete.
- Check the previously reported backend metadata omissions and possible concurrent-session mutation race; reproduce and repair only demonstrated problems that affect this flow. Require tests for any fix. If unresolved identity/authorization races remain, block staging deployment and report them.

### Slice B — Private synthetic medical record and reminder

- Implement an optional phone/tablet screen with **Medical conditions**, **Allergies**, and **Emergency contact**, plus **Skip for now** and **Save Test Record**. For conditions/allergies, distinguish `unknown` from `none_known` and `listed`; require details only when `listed` is chosen. An empty field must not mean medically clear.
- Reuse the existing private student emergency-contact fields as the canonical source, prefill when possible, and use an authorized update path instead of silently duplicating conflicting contacts.
- Show the **exact proposed synthetic-only notice** in the approved new design. Checkboxes start unchecked. Require the fictional-test-data acknowledgment for a save, plus the separate minor-only statement that guardian authorization is **not verified**. Never record `guardianConsentGranted=true` or treat a student's tap as verified parental consent.
- Do not send or claim success for guardian/email verification. A future-email placeholder, if present, is disabled and clearly labeled.
- Add or reuse a trusted authenticated callable (e.g. `saveMySyntheticMedicalRecord`) with UID from Auth, server-side validation, bounds, a **server-configured QA UID allowlist or equivalent existing tester entitlement**, server timestamps, `syntheticOnly:true`, `completed_synthetic`, and `guardianAuthorizationStatus:not_verified`. Do not let clients assert tester entitlement. The authorized QA operator must explicitly allowlist a freshly created test UID before that tester can save the synthetic medical form; until then, show a clear test-eligibility message and preserve Skip/QR/dashboard. Restrict private medical reads to the owner; deny client mutation of server-controlled status/acknowledgment and all anonymous/cross-user reads. Do not log field contents.
- Skipping writes **no** medical record and does not block QR or dashboard. A signed-in unfinished account sees a dismissible, non-blocking **Finish Medical Record** reminder, not on every screen rebuild. Successful private save hides the reminder and permits viewing/updating/clearing the test entry.
- RED/GREEN tests: skip vs save, minor/adult acknowledgment, unchecked/declined, unknown/none/listed, existing contact handling, empty/invalid/oversize, unauthenticated/cross-user attempts, remote failure/retry, no public data leaks, reminder state, restart persistence.
- Commit once those focused tests pass, with a scoped message such as `feat(resqme): save synthetic medical records privately`.

### Slice C — Server-issued unverified account QR

- Add a minimal trusted `ensureMyTier1Qr` callable. Require a signed-in UID and existing **server-created pending** profile; never accept client-supplied UID, ownership, token, LRN, role, status or authorization flags.
- Generate a high-entropy opaque QR reference **once** and return the same active reference for repeated calls, app restarts and concurrent sessions. Use transaction-based idempotency; do not generate a new token for a timeout retry. The payload must contain **no** names, ages, emails, LRN, contacts, conditions or allergies.
- Store the reference privately; deny unauthenticated reads and client writes. QR is **UNVERIFIED** and not a login credential, school ID, medical-data key, or Tier 2 access grant. No public verification endpoint/scanner in this slice.
- Display the QR after the optional medical step and within signed-in My QR, with a visible banner: **Unverified ResQMe account — not proof of school enrollment**. If issuance fails, offer retry without recreating Auth or profile. Medical completion is never a prerequisite.
- RED/GREEN tests: no Auth, missing profile, pending statuses allowed only as unverified, forged role/status/QR rejected, repeat/concurrent issuance returns one reference, QR persistence, no PII in payload, cross-user access denied, guest public access unchanged.
- Commit a scoped slice such as `feat(resqme): issue unverified account QR in staging`.

### Slice D — Integration and bounded staging smoke

- Write route/widget tests for registration → medical Complete/Skip → My QR → dashboard; later dashboard **Finish Medical Record**, login/logout/reset, offline, partial Auth/callable failure, and guest dashboard.
- Run with exact pass/fail outputs and exit codes: `flutter analyze`, `flutter test`, relevant Functions build/unit/integration suites, Firestore Emulator Rules tests, `flutter build apk --debug`, `git diff --check`. Use `demo-resqme` and loopback-only endpoints for emulator tests. Do not treat emulator startup failures as passing tests.
- Prepare a **staging-only deployment manifest** listing exact `resqme-943ee` Functions/Rules and effects, expected App Check/debug requirements, rollback and smoke-test plan. **Ask for explicit go/no-go before remote deployment**; do not assume this prompt authorizes it. Never push/deploy production or unrelated Functions.
- Once staging deployment is approved, install the debug APK and use **invented** test records on an available phone/tablet. Test the unaffiliated new-account path (medical save not enabled, but Skip/QR/dashboard working), then have an authorized QA operator allowlist its UID and verify medical Save, callable/Firestore persistence, post-login QR restoration, reminder changes, duplicate/session behavior, logout, reset, and guest first aid/hotlines/DRRM. Mark device or parity checks pending when genuinely unavailable.
- Final report: changed files, commit hashes, validation matrix, exact deployed resources and staging project (if approved), failed/pending checks, proof no real medical data, unresolved backend metadata/concurrency issues, and a clean QR/Tier 2 separation statement.

## Definition of done

- A tester can use a **synthetic** email/password account on hosted staging after approved deployment; it remains pending, never verified/approved.
- Medical data is optional, fictional, privately stored only after explicit demo acknowledgment, editable later, and never made public or available to nurse/Tier 2 workflows.
- Minors' checkboxes **do not** mark guardian consent verified; no confirmation email is sent or claimed.
- Exactly one persistent **unverified** QR is issued per eligible pending account, even on retries; QR content contains no personally identifying or medical data and grants no authority.
- The guest emergency dashboard continues working without registration, medical details or QR.
- Required automated tests and debug APK pass; hosted staging and device outcomes are reported honestly.

**Stop and ask** if the real repository contradicts the approved scope, hosting permissions fail, real data appear, a security-critical race cannot be resolved safely, or anyone requests real medical-data collection or guardian verification under this synthetic-only milestone.
