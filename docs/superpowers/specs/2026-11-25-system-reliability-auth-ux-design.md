# ResQMe — System Reliability, Student Authentication & UX Improvement Specification

**Date:** 2026-11-25  
**Repository:** `resqme`  
**Branch:** `feat/resqme-admin-tier2-access`  
**Baseline HEAD:** `b1958e3531ca2a18e1d57be0e45711b8a650c377` (`b1958e3`)  
**Staging Project:** `resqme-943ee` (Local Emulator Project: `demo-resqme`, Region: `us-central1`)  
**Packages:** `com.example.resqme` (`student` flavor, `1.0.0+1`), `com.example.resqme.admin` (`admin` flavor, `1.0.0+1`)

---

## 1. Verified Baseline & Preservation Boundaries

1. **Git State:**
   - Verified `HEAD`: `b1958e3531ca2a18e1d57be0e45711b8a650c377` (preceded by `67b7e05` IFRC 2025 First Aid expansion and `39957a7` biometric student identity reveal).
   - Pre-existing working-tree modifications in reviewer/QA flows (`approve_student_qr.ts`, `school_review_screen.dart`, `school_review_repository.dart`, `resqme_app.dart`, `account_dashboard_panel.dart`, `qr_scanner_screen.dart`, `functions/src/index.ts`, and QA docs) are strictly preserved.
2. **Baseline Exported Functions Inventory (`functions/src/index.ts`):**
   - Student Onboarding & Profile: `createStudentRegistration`, `getMyStudentProfile`
   - Medical Records: `saveMySyntheticMedicalRecord`, `clearMySyntheticMedicalRecord`, `getMyMedicalRecordStatus`, `getMySyntheticMedicalRecord`, `completeMyMedicalRecord`
   - School Review & Roster: `approveStudentQr`, `revokeStudentQr`, `getSchoolReviewCandidate`, `getSchoolReviewCandidateByQr`, `getSchoolReviewStatus`, `previewSchoolRosterImport`, `commitSchoolRosterImport`, `listSchoolRosterImports`
   - Student QR & Tier 2: `ensureMyTier1Qr`, `resolveTier1Qr`, `replaceMyTier1Qr`, `issueStudentEnrollmentChallenge`, `enrollTier2Device`, `issueTier2Challenge`, `readMyTier2Record`, `revealMyStudentIdentity`, `readMyTier2WithPassword`, `revokeMyTier2Device`
   - Staff & Admin Portal: `getStaffAccess`, `issueStaffEnrollmentChallenge`, `enrollStaffTier2Device`, `revokeStaffTier2Device`, `issueStaffTier2Challenge`, `readStudentTier2`, `changeMyStaffPassword`, `syncMasterAdminEmail`, `createAuthorizedAccount`, `listAuthorizedAccounts`, `updateAuthorizedAccount`, `setAuthorizedAccountStatus`, `resetAuthorizedPassword`, `revokeAuthorizedDevice`, `getPortalDashboardStats`, `listSchoolStudents`, `getSchoolStudentDetails`, `verifySchoolStudentAccount`, `setStudentAccountStatus`, `listSchoolRoster`, `issueAdminLrnRevealChallenge`, `revealStudentLrn`, `issueAdminQrReplaceChallenge`, `replaceSchoolStudentQr`, `listSchoolActivityLogs`
3. **Preservation Invariants:**
   - Permanent accounts, school assignments, existing hardware biometric enrollments, permanent Tier 1 emergency QR behavior, guardian authorization requirements for minors (`< 18`), and medical records remain backward-compatible and intact.

---

## 2. Phase 1 — Admin Portal Intermittent Data Loading Root Causes & Architecture

### Confirmed Root Causes
1. **RC-1 — Shared Fail-Fast `AccountOperationLock` Rejects Overlapping Reads:** `lib/main_admin.dart` passes a single `AccountOperationLock` instance (`if (busy) throw StateError('An account operation is in progress.')`) into `FirebaseStaffAccessRepository`, `FirebaseStaffManagementRepository`, and `FirebasePortalStudentRepository`. Every read callable (`loadDashboardStats`, `listStudents`, `getStudentDetails`, `listRoster`, `listActivityLogs`, `listRosterImports`, `listAccounts`, `loadAccess`) executes inside `operationLock.run(...)`. Tab switches, opening details/logs while Dashboard loads, debounced searches, and returning from child routes trigger `StateError`, which `_rethrowMapped` converts into generic `"Unable to load..."` failures.
2. **RC-2 — Cold-Start Auth Readiness Race & Destructive Sign-Out:** `_StaffAccessShell.initState()` only checks synchronous `currentUid != null` once without awaiting Firebase Auth persistence restoration (`authStateChanges()`), while `loadAccess()` uses a 10s timeout, maps all network/cold-start timeouts to `StaffAccessDenied`, and `_verifyExistingSession()` calls `signOut()` on any error—destroying valid sessions on transient network/cold-start delays.
3. **RC-3 — Destructive Refresh State Wipes Valid Data:** Portal screens set `_loading = true; _error = null` on refresh/search/filter and render a full-screen spinner or full-screen error `PortalStateView`, causing previously loaded valid lists/cards to disappear during refresh or transient errors.
4. **RC-4 — Out-of-Order Concurrent Responses & Missing Request Deduplication:** Screens neither deduplicate identical concurrent reads nor guard `setState` with monotonic request generation IDs, allowing slow superseded queries to overwrite newer results.
5. **RC-5 — Unclassified Errors & Missing Read-Only Retry:** Read callables lack bounded exponential-backoff retry on transient Firebase codes (`unavailable`, `deadline-exceeded`, `network-request-failed`, timeout) and do not separate transient errors from session authorization loss (`unauthenticated`, staff `permission-denied`).
6. **RC-6 — Scope Isolation & Cache Purge:** `_StaffAccessShell` lacks a scope `ValueKey` (`uid:schoolId:role`), `WidgetsBindingObserver` app-resume verification, and immediate repository cache invalidation upon logout, account switch, or suspension.
7. **RC-7 — Backend Null Payload & Exact-Match Pagination Cursors:** `getStaffAccess` and `syncMasterAdminEmail` reject `null` `request.data`; `listSchoolStudents`, `listSchoolRoster`, and `listSchoolActivityLogs` throw `Invalid pagination cursor.` if the boundary item changes status between pages; `firestore.indexes.json` lacks composite indexes for school-scoped collections.

### Architecture Solution
- **`PortalReadCoordinator`:** Coordinates all read operations outside `AccountOperationLock` (which remains strictly for mutually exclusive auth/destructive mutations). Enforces auth readiness, deduplicates identical in-flight reads per `(uid, schoolId, queryKey)`, runs bounded exponential-backoff retry on transient read failures only, caches last-known valid data strictly per `uid:schoolId:role` scope, and purges all state immediately on logout, account switch, or authorization loss.
- **Explicit Screen State Model (`PortalLoadStatus`):** Separates `initialLoading`, `refreshing`, `loaded`, `empty`, `transientError`, and `authorizationError`, guarded by monotonic `_requestSeq` generation IDs.
- **Keyset Pagination Cursors:** Backend cursors encode sort keys (`(name, id)` / `(timestampMs, sourceCollection, id)`) while remaining backward-compatible with legacy plain IDs.

---

## 3. Phase 2 — Automatic Student Registration & Security Distinction

### Security Distinction: Roster Match vs. Identity Ownership Verification
> **Critical Security Principle:** Matching a 12-digit LRN, normalized full name, and exact birth date (`YYYY-MM-DD`) against an imported DepEd SF1 school roster proves **roster existence and attribute consistency (Roster Match)**—it does **not** by itself prove that the person typing those biographical values is the rightful student (**Identity Ownership**), because classmates or third parties may know or observe a student's name, birth date, and LRN.

Accordingly, ResQMe maintains **five distinct server-authoritative states** on `studentProfiles/{uid}` and companion records:
1. **Roster Match (`rosterMatchStatus`):** Exact 12-digit LRN + deterministic normalized full name + exact `YYYY-MM-DD` birth date matched against `schoolRosterClaims/{hmac(lrn)}`, inheriting authoritative `schoolId`, `gradeLevel`, `sex` (if present), and `birthDate` (used to compute authoritative `ageYearsAtRegistration` and minor `< 18` status).
2. **Identity Ownership (`identityOwnershipStatus`):** Verified via the school-issued one-time **Enrollment Code** (`enrollmentCodeHash` on `schoolRosterClaims`) or verified school-controlled channel.
   - **Roster Match + Valid Enrollment Code:** Transactionally claims the roster record (`claimedByUid = uid`), locks `studentLrnLocks/{schoolId}_{lrn}`, and automatically sets `schoolApprovalStatus = 'approved'`, `schoolVerificationMethod = 'roster'`, `schoolVerificationOutcome = 'verified'` **without routine Master Admin approval**.
   - **Roster Match WITHOUT Enrollment Code (or Unmatched Record):** Account is created in `pending` school review (`schoolVerificationOutcome = 'manual_review'`) so legitimate students without a code retain manual Master Admin assistance, while preventing unauthorized third parties from hijacking a roster claim or auto-verifying an identity using biographical fields alone!
   - **Conflicting / Already-Claimed LRN:** Rejected or flagged cleanly with generic non-enumerating messages that **never** leak roster names, birth dates, grades, or school assignments.
3. **Medical Completion (`medicalStatus`):** Remains independent (`not_started` -> `complete`).
4. **Guardian Authorization (`studentGuardianAuthorizations/{uid}`):** Mandatory for all minors (`ageYearsAtRegistration < 18` computed from authoritative roster `birthDate`); automatic roster verification **never** bypasses guardian authorization.
5. **QR & Tier 2 Eligibility:** Evaluated strictly across all authoritative prerequisites (`evaluateStudentEligibility` / `evaluateQrEligibility`).

---

## 4. Phase 3 — Student QR Login Contract

- **Purpose-Separated Opaque Login QR (`resqme:login:v1:<opaqueToken>`):** Distinct from the public emergency Tier 1 QR (`resqme:v1:<token>`) and short-lived Tier 2 presentation token (`resqme:tier2:v1:<token>`).
- Stored hashed (`SHA-256`) in `studentLoginQrTokens/{tokenHash}` -> `{ uid, tokenVersion, status: 'active' | 'revoked' }`, rotatable/revocable by the student or on account disablement.
- **Mandatory Password Verification:** Scanning a Login QR invokes `resolveStudentLoginQr` (rate-limited per caller IP/device fingerprint, constant-shape error responses to prevent enumeration) to resolve the login identifier and masked account hint ONLY. It **never** issues a Firebase custom token or session—the student **must** enter their password via `FirebaseAuth.signInWithEmailAndPassword`.
- **Shared-Device Security Notice:** Displayed prominently on the Student Sign-In QR flow explaining that signing in on a shared or unfamiliar device grants session access only and will not transfer trusted personal-device biometric Tier 2 keys.

---

## 5. Phase 4 — Personal-Device Biometric Protection & Tier 2 QR Presentation

- **Trusted Personal Device vs. Password Session:**
  - Enrolling a personal device requires Android Keystore hardware-backed EC P-256 key generation (`setUserAuthenticationRequired(true)`) + cryptographic challenge-response (`issueStudentEnrollmentChallenge` -> `enrollTier2Device` v2).
  - Password login on another device allows ordinary account access and legitimate student medical profile maintenance through authorized workflows, **never** silently replaces `tier2Devices/{uid}`, and restricts Tier 2 biometric QR presentation to the enrolled personal device.
  - Replacing a trusted device requires either existing trusted-device approval or verified recent-password + identity recovery (`enrollTier2Device` revokes prior `keyVersion` atomically and invalidates outstanding challenges/tokens).
- **Short-Lived Opaque Tier 2 Presentation Token:**
  - Unlocking Tier 2 QR requires a fresh hardware biometric signature (`issueTier2Challenge` -> `issueStudentTier2PresentationToken`), minting a short-lived (e.g., 90s) opaque token `resqme:tier2:v1:<random>` stored hashed in `studentTier2PresentationTokens/{hash}` (zero medical data embedded!).
  - Presentation screen displays **only** the QR code, countdown timer, and concise instructions, enforces `FLAG_SECURE`, and immediately clears/hides the token when backgrounded (`AppLifecycleState != resumed`) or expired.
  - `readStudentTier2` accepts both the short-lived Tier 2 presentation token and existing permanent emergency QR payloads (preserving existing emergency behavior) while keeping staff biometric authentication mandatory.

---

## 6. Phases 5–9 — SF1 Import, Activity Logs, Feature Guide, Skeletons & Sync

- **Phase 5 (SF1 Import):** Verified `xlsx@0.20.3` data-only parsing (`cellFormula: false`, `cellHTML: false`, `cellText: false`, strict `.xls`/`.xlsx` magic-byte check, `<= 2 MB` payload limit, worksheet/row/column caps), SHA-256 preview-to-commit binding (`actorUid + schoolId + fileSha256`), mandatory Data Privacy Act disclaimer + explicit checkbox acknowledgement before commit, truthful stage/progress states, idempotent recovery of enrollment credentials, TTL preview expiration, and automatic refresh of Roster + Dashboard counts via `PortalReadCoordinator.notifyMutation()`.
- **Phase 6 (Activity Logs):** Server-timestamped audit coverage across student/staff/admin/Tier2 boundaries, explicit allowlists, actor safe display name + role, `Asia/Manila` (`UTC+08:00`) date boundaries and formatting, date-grouped UI cards, and lossless composite keyset pagination across `staffManagementAudits` and `tier2AccessAudits`.
- **Phase 7 (Feature Guide):** Reusable offline-bundled `FeatureGuide` modal + AppBar/header `Icons.info_outline` (`>= 48 dp` tap target) + post-dismissal non-blocking locator hint, persisted per `accountScope + featureId + guideVersion` in `SharedPreferences` with zero PII/medical data.
- **Phase 8 (Skeletons & Responsive UI):** Zero-dependency `ResQMeSkeleton` components matching Portal & Student layouts, rendered strictly during `initialLoading`, honoring `MediaQuery.disableAnimationsOf(context)`, keyboard-safe dialogs, verified across `360 dp`, `412 dp`, tablet (`800 dp`), and enlarged text (`1.6x–1.8x`).
- **Phase 9 (Two-App Synchronization):** Verified end-to-end across all 10 synchronization scenarios against Auth, Firestore, and Functions emulators without duplicate student profile collections.
