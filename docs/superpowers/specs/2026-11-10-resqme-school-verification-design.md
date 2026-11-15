# ResQMe School Verification and Pending QR — Approved Design Contract

**Status:** Approved feature direction from owner conversation, 2026-11-10. Repository implementation and deployment are **not** approved by this document alone.

## Intent

Let a student register and use public Tier 1 immediately, with a QR visibly labeled **Pending Verification**. School verification can come from an authoritative imported student roster plus a school-issued, one-use enrollment code, or a manually recorded decision by an already trusted school reviewer. Medical completion, school approval, and independently verifiable guardian permission (when applicable) are separate prerequisites to QR activation. A QR never serves as an authentication credential or public source of personal/medical information.

## Chosen approach

Extend the existing Firebase Auth / `createStudentRegistration` callable, `studentProfiles/{uid}`, `schoolReviewers/{uid}`, and QR credential/lookup collections. Use an **emulator-only** five-person synthetic roster to demonstrate roster matching. Later, a real school-authorized import process can supply trusted records; there is no such authority today. Keep manual review on the existing reviewer trust model. Do not replace the app architecture, add a second backend, or implement staff portal-entry/master Tier 2 QR in this milestone.

## Approved behavior

1. Require a **12-digit, string-valued LRN** (preserve leading zeros) during new registrations. Collect an enrollment code for the *automatic verification* route. Missing, wrong, expired or used code never auto-verifies and must not prevent a valid new registration from reaching pending manual review; copy must explain that distinction. Do not permit LRN-only approval.
2. A code is high entropy, school-issued, **bound to one roster student**, and consumed atomically once on successful match. The server checks the roster's LRN and normalized full name, valid code, unclaimed status, and associated trusted school identity. The client supplies no school ID, reviewer, or approval state. Retried requests by the same UID are idempotent; two UIDs cannot claim the same roster identity or code.
3. Add **exactly five clearly fictional student records** to a *local-only* roster fixture: three clean automatic matches; one missing/invalid-code manual-review case; one already-claimed/duplicate conflict. Fixtures never seed `resqme-943ee`, never represent real students, and must not contain credentials usable in hosted environments.
4. Valid roster/code checks record school approval (`approved`, method `roster`) and trusted school assignment. Manual review requires a pre-provisioned active same-school reviewer; it must be audited, idempotent and revocable. The applicant cannot choose school, reviewer or their approval. An unmatched LRN without an authoritative school route remains `unassigned` and cannot be approved until an operator resolves school assignment with outside evidence.
5. Successful registration creates (or can idempotently ensure) one owner QR with a random opaque payload and **pending** state. Owner UI shows **Pending Verification**, with immediate access to public Tier 1/dashboard/scanner. Public resolution of a pending, malformed, revoked or unknown QR yields the same non-identifying inactive result. Pending QR never permits Tier 2, identity lookup, or medical details.
6. QR activation is a **separate server-side eligibility decision**, requiring approved same-school assignment, completed authoritative medical record, an intact credential, and verified guardian authorization for minors if required. A student's privacy checkbox or guardian contact fields do not count as guardian authorization. If the guardian verification mechanism is not implemented, **minor QR activation remains disabled**. Revocations stay revoked; no automatic reactivation of explicitly revoked credentials.

## Compatibility / constraints

- Existing profile schema v1 and older `lrn: null` records must remain readable and restricted. New registration writes contain required LRN, but older accounts require a separately reviewed upgrade flow; never silently claim a roster match.
- Keep existing `status` meaning (`pending_review` / `pending_guardian`) independent from `schoolApprovalStatus` (`pending` / `approved` / `revoked`), `schoolAssignmentStatus`, and QR status (`pending` / `active` / `revoked`). School approval does **not** change guardian status and does **not** imply medical completion.
- Deny direct client writes; use authenticated, server-authoritative callables with minimal owner/reviewer response projections. Never return raw LRN, enrollment code, contacts, or health details in public QR responses, logs, analytics, or errors.
- Only local source/tests/design work is in scope; no deployment, hosted Auth/Firestore writes, IAM, APIs, Rules, App Check, secret provisioning, actual reviewer creation, Git push, or real school roster import.
- Use existing checkout. Preserve unrelated work, avoid extra worktrees due limited disk space, and do not restart Firebase CLI emulators until the previously observed isolated ADC file issue is explicitly cleared.

## Demonstration acceptance

- Three synthetic students register and become school-approved via one-use roster codes, **but QR remains pending** until the remaining eligibility conditions hold.
- A student with a missing/invalid code registers and gets a pending QR; a genuinely trusted same-school reviewer can subsequently approve, without requiring medical completion for the *approval decision*.
- A duplicate LRN/code claim never receives automatic approval. No double consumption, leaked roster existence, or cross-user profile read.
- Every pending user can use public Tier 1; the public QR scan only reveals active/inactive eligibility.
- Adult activation occurs only after medical completion and approval. Minors cannot activate without an independently verified guardian authorization mechanism.

## Not part of this milestone

Staff Admin Portal pairing QR, Tier 2 master authorization QR, school roster production importer, guardian authorization delivery/verification system, broad student-information portal, direct Firestore access from admin clients, hosted provisioning/deployment, and changes to App Check/Rules/IAM.
