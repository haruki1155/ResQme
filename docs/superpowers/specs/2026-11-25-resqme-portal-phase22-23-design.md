# ResQMe Portal — Phase 2.2 & 2.3 Design and Phase 3 SF1 Import Specification

**Date:** 2026-11-25
**Target Flavor:** `ResQMe Portal` (`com.example.resqme.admin`, entry point `lib/main_admin.dart`)
**Branch Baseline:** `feat/resqme-admin-tier2-access` (`abee70a`)

---

## 1. Objectives and Non-Goals

### Objectives
1. **Professional Red-and-White Portal Redesign (Phase 2.2):** Transform `ResQMe Portal` into a clean, mobile-first administrative application built on `ResQMeTheme.light` (`#E92B32` primary brand red, `#F1F3F7` neutral background, white `Card` surfaces) without introducing a second design system or modifying the Student App.
2. **Role-Scoped Navigation:**
   - **Master Admin (`role == 'admin' && isMasterAdmin == true`):** Primary bottom `NavigationBar` with 4 destinations (**Dashboard**, **Active Students**, **Student Roster**, **Authorized Personnel**), prominent **Scan Student QR** action on the Dashboard, and an **Account & Security** menu in the top app bar (`Trusted Device Biometrics`, `Change Password`, `Email Verification & Recovery`, `Sign Out`).
   - **Authorized Personnel (`role == 'authorized'`):** Restricted operational workspace with prominent **Scan Student QR** and **Account & Security** menu (`Trusted Device Biometrics`, `Change Password`, `Sign Out`). Zero navigation routes or controls for Active Students, Student Roster, or Authorized Personnel.
3. **School-Scoped Dashboard Statistics:** Server-authoritative statistics separating **Imported Roster Students** (`schoolRosterClaims`) from **Registered Student Accounts** (`studentProfiles`), **Verified Students**, **Disabled Students**, and **Authorized Personnel**.
4. **Active Students, Manual School Verification & Account State Management (Phase 2.3):**
   - Rename Student Management to **Active Students** (`All`, `Registered`, `Verified`, `Disabled` visible categories — removing *Pending* and *Revoked* as top-level account categories while preserving internal `pending` verification states and `revoked` QR credential states).
   - Search by student name or exact 12-digit LRN (preserving leading zeros), filter by grade level (`Unassigned Grade` fallback), alphabetical sorting, and bounded cursor pagination (`limit <= 25`).
   - **Student Details** showing administrative metadata only (name, LRN, grade level, sex, birth date / registration age, account category, registration status, school verification status & method, medical completion status, guardian authorization status, QR credential status) — **never** exposing protected medical contents (`conditions`, `allergies`, medications, clinical notes) or raw QR payloads.
   - **Manual Master Admin Verification** reusing the school approval contract (`schoolApprovalStatus: 'approved'`, `schoolVerificationMethod: 'manual_admin'`, `schoolVerificationOutcome: 'verified'`, `schoolApprovedBy`, `schoolApprovedAt`, `schoolApprovals/{requestId}`) with transactional LRN uniqueness locks (`studentLrnLocks/{schoolId}_{lrn}`) and roster-claim conflict checks. QR credentials are only transitioned from `'pending'` to `'active'` when `evaluateQrEligibility` passes.
   - **Student Account Disablement & Reactivation** (`accountStatus: 'disabled' | 'active'`, `accountDisabled: true | false`) enforced across student, medical, QR, and Tier 2 chokepoints, paired with Firebase Auth `disabled` state + refresh-token revocation. Reactivation preserves audit history and **never** restores `'revoked'` QR credentials.
5. **Separate Student Roster Screen (Phase 2.3):** Read-only school roster view backed by `schoolRosterClaims` (without creating duplicate student profile collections), supporting grade-level filtering (`Unassigned Grade` fallback), name and exact-LRN search, alphabetical sorting, `Not Registered` / `Registered` / `Verified` registration linkage badges, bounded pagination, read-only roster details, and a truthful empty state with **no nonfunctional Import button**.

### Non-Goals in Phase 2.2 & 2.3
- Do **not** modify any Student App screens or visual styles.
- Do **not** implement `.xls` / `.xlsx` SF1 file parsing or import execution (reserved for Phase 3; documented in Section 4 below).
- Do **not** deploy to staging (`resqme-943ee`) or install a new APK until explicit owner approval after the Phase 2.2 & 2.3 acceptance gate.

---

## 2. Visual & Navigation Architecture (`lib/features/admin/`)

### Brand Tokens (Reusing `ResQMeTheme.light`)
- **Primary Brand Red:** `#E92B32` (`ResQMeTheme.emergencyBlue` / `colorScheme.primary`)
- **Canvas Background:** `#F1F3F7` (`scaffoldBackgroundColor`)
- **Surface Cards:** `#FFFFFF` with subtle `1px` neutral border (`#E2E6EE`) and `16dp` border radius (`0`–`1dp` elevation, minimal shadows)
- **Text Hierarchy:** `#15181E` primary ink, `#525866` secondary ink, semantic status pills meeting WCAG AA contrast (`>= 4.5:1`) and `>= 48dp` interactive touch targets
- **Responsive Mobile Breakpoints:** Verified at `360 dp` and `412 dp` widths using flexible layouts (`Wrap`, `Expanded`, responsive 2-column stat grids) with zero horizontal or vertical overflow.

### Shared Minimal Components (`lib/features/admin/widgets/portal_widgets.dart`)
Following `Ponytail` minimal-abstraction principles, reuse Material 3 widgets plus four small composable Portal helpers:
1. `PortalPageHeader` — compact title + contextual school/section description.
2. `PortalStatCard` — compact metric card with label, count, subtle caption, and restrained icon.
3. `PortalStatusBadge` — accessible semantic pill (`Registered`, `Verified`, `Disabled`, `Not Registered`, `Active`, `Revoked`).
4. `PortalStateView` — unified loading, truthful empty, and error + retry state widget.

---

## 3. Backend & Security Design (`functions/src/`)

### Least-Privilege Runtime Compatibility
Hosted Cloud Functions execute as `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com`, which intentionally omits `datastore.entities.delete`. All new callables strictly use `get`, `list` (`where`), `create`, `set`, and `update` — **never** `.delete()`.

### Student Account Disability Chokepoints
A helper `isStudentAccountDisabled(profile)` (`profile?.accountDisabled === true || profile?.accountStatus === 'disabled'`) is enforced at:
- `requirePending` & `requireQrEligible` (`functions/src/onboarding/authorization.ts`) — blocks `saveMySyntheticMedicalRecord`, `clearMySyntheticMedicalRecord`, `getMyMedicalRecordStatus`, `getMySyntheticMedicalRecord`, `completeMyMedicalRecord`, `ensureMyTier1Qr`, `replaceMyTier1Qr`.
- `sanitizeStudentProfile` (`functions/src/profile/get_my_student_profile.ts`) — blocks `getMyStudentProfile`.
- `evaluateStudentEligibility` (`functions/src/qr/qr_eligibility.ts`) — blocks `enrollTier2Device`, `issueTier2Challenge`, `readMyTier2Record`, `readMyTier2WithPassword`, `resolveTier1Qr`, `issueStaffTier2Challenge`, `readStudentTier2`.
- `createStudentRegistration` (`functions/src/registration/create_student_registration.ts`) and `revokeMyTier2Device` (`functions/src/medical/revoke_my_tier2_device.ts`).

### New Master Admin Callables (`functions/src/staff/staff_student_management.ts`)
All six callables require `resqmeRuntimeOptions` and verified `requireMasterAdmin` (`role === 'admin'`, `isMasterAdmin === true`, `active === true`, `mustChangePassword !== true`, `emailVerified === true`), strictly scoped to `admin.schoolId`:

1. `getPortalDashboardStats` — Returns `{schoolId, rosterAvailable, importedRosterCount, registeredStudentsCount, verifiedStudentsCount, disabledStudentsCount, authorizedPersonnelCount}`.
2. `listSchoolStudents` — Queries `studentProfiles` where `schoolId == admin.schoolId`; supports `search` (case-insensitive name substring or exact 12-digit LRN), `statusFilter` (`'all' | 'registered' | 'verified' | 'disabled'`), `gradeFilter` (including `'Unassigned Grade'`), alphabetical sort (`fullName`, tie-breaker `uid`), and bounded pagination (`limit <= 25`, `cursor`). Returns **only `maskedLrn` (`XXXX••••XXXX`)** — never full 12-digit LRNs and never `studentMedicalRecords`.
3. `getSchoolStudentDetails` — Reads `studentProfiles/{studentUid}`, `studentGuardianAuthorizations/{studentUid}`, and `studentQrCredentials/{studentUid}` (never `studentMedicalRecords`, never raw QR `payload`, and **only `maskedLrn`**). Returns sanitized administrative fields required by Task 5.
4. `verifySchoolStudentAccount` — Transactional manual verification (`studentUid`, `requestId`):
   - Rejects cross-school, unassigned, disabled, self, or `schoolVerificationOutcome === 'conflict'` profiles.
   - Enforces school-scoped LRN uniqueness via `studentLrnLocks/${schoolId}_${lrn}` (`status: 'active'`, `uid`) and checks `schoolRosterClaims` (when HMAC key is configured) so an LRN claimed by another UID cannot be approved.
   - Updates `studentProfiles/{studentUid}` (`schoolApprovalStatus: 'approved'`, `schoolVerificationMethod: 'manual_admin'`, `schoolVerificationOutcome: 'verified'`, `schoolApprovedBy`, `schoolApprovedAt`), records `schoolApprovals/{requestId}` + `staffManagementAudits`, and only activates a `'pending'` QR credential + lookup if `evaluateQrEligibility` returns `true`.
5. `setStudentAccountStatus` — Requires `requireRecentAuth` (`<= 120s`), `studentUid`, `action: 'disable' | 'enable'`. Updates `accountDisabled` & `accountStatus` on `studentProfiles/{studentUid}`, revokes active student `tier2Devices/{studentUid}` on `'disable'`, updates Firebase Auth `disabled` flag + `revokeRefreshTokens` on `'disable'`, writes `staffManagementAudits`, and **never** alters `'revoked'` `studentQrCredentials/{studentUid}` on `'enable'`.
6. `listSchoolRoster` — Queries `schoolRosterClaims` where `schoolId == admin.schoolId`, joins `claimedByUid` against `studentProfiles` (`'not_registered' | 'registered' | 'verified'`), normalizes missing `gradeLevel` to `'Unassigned Grade'`, returns **only `maskedLrn` (`XXXX••••XXXX`)**, and supports search, grade filtering, alphabetical sort, and bounded pagination (`limit <= 25`, `cursor`).
7. `issueAdminLrnRevealChallenge` & `revealStudentLrn` — **2-Layer Step-Up LRN Protection**:
   - **Layer 1 (Default Redaction + Session/Tenant Isolation):** Standard endpoints strip raw LRNs on the server and return only the first 4 and last 4 digits (`XXXX••••XXXX`) to an active, email-verified Master Admin within `admin.schoolId`.
   - **Layer 2 (Live Step-Up Proof + Immutable Audit + Ephemeral Auto-Hide):** Revealing the full 12-digit LRN requires a fresh second proof — **either** recent Master Admin password reauthentication (`auth_time <= 60s`) **or** an attested hardware biometric ECDSA signature over a single-use 60-second challenge (`resqme:admin-lrn-reveal:v1`), rate-limited and recorded in `staffManagementAudits` (`action: 'reveal_student_lrn'`). On Android, the Portal enables `FLAG_SECURE` while unmasked and auto-hides after 30 seconds or when backgrounded.

---

## 4. Approved Phase 3 SF1 Roster Import Specification (Documentation Only)

Phase 2.3 establishes the `Student Roster` screen and server read contract (`listSchoolRoster` over `schoolRosterClaims`). The actual spreadsheet importer is deferred to **Phase 3** and must conform to the following approved specification:

### 4.1 Supported File Formats & Source Structure
- Accept official DepEd **School Form 1 (SF1 — School Register)** workbooks in both legacy `.xls` (BIFF8) and modern `.xlsx` (OpenXML) formats.
- Reject password-protected, macro-enabled (`.xlsm`), malformed, or oversized workbooks with clear row/sheet diagnostics before any write occurs.

### 4.2 Required & Extracted SF1 Columns
| SF1 Field | Validation & Normalization Rules | Storage Target (`schoolRosterClaims/{hmacId}`) |
| :--- | :--- | :--- |
| **LRN** | Exact 12-digit numeric string (`/^\d{12}$/`), **preserving leading zeros**; never coerce to floating-point/integer numbers | `rosterLookupId(lrn, hmacKey)` document ID + administrative `lrn` display field |
| **Name** | DepEd SF1 format (`Last Name, First Name, Middle Name` / `Extension`); normalized via NFKC + whitespace collapse for matching while preserving formatted display name | `normalizedName` (for `evaluateRosterClaim`) + `displayName` / `sf1Name` |
| **Sex** | Normalized (`M` / `F` or `Male` / `Female`) | `sex` |
| **Birth Date** | Validated calendar date (`YYYY-MM-DD` canonical ISO date, parsed safely from Excel serial or `MM/DD/YYYY`) | `birthDate` |
| **Grade Level** | Extracted from SF1 header metadata or row column (e.g., `Grade 7`–`Grade 12`); defaults to `'Unassigned Grade'` only if absent | `gradeLevel` |
| **Father's Name** | Optional text (`Last, First, Middle`) sanitized and bounded | `parentMetadata.fatherName` (admin/guardian verification reference only) |
| **Mother's Maiden Name** | Optional text (`Last, First, Middle`) sanitized and bounded | `parentMetadata.motherMaidenName` |
| **Guardian Name & Relationship** | Optional text sanitized and bounded | `parentMetadata.guardianName`, `parentMetadata.guardianRelationship` |
| **Parent / Guardian Contact Number** | Normalized PH contact format (`09XXXXXXXXX` / `+639XXXXXXXXX`) when present | `parentMetadata.contactNumber` |

### 4.3 Security & Claim Preservation Rules
1. **HMAC Roster Claim Compatibility:** Every imported student row must compute `docId = rosterLookupId(lrn, RESQME_SCHOOL_ROSTER_HMAC_KEY)` in `schoolRosterClaims/{docId}` scoped to `admin.schoolId`, preserving automatic registration verification (`evaluateRosterClaim`) alongside manual Master Admin verification (`verifySchoolStudentAccount`).
2. **No Duplicate Student Profile Collection:** SF1 imports populate `schoolRosterClaims` and `schoolRosterImports` audit metadata only — they must **never** create synthetic `studentProfiles` or `studentMedicalRecords` for unregistered students.
3. **Pre-Commit Validation & Preview:**
   - Parse and validate rows into a dry-run preview summarizing: total rows, valid new records, controlled updates to existing roster entries, invalid rows (with exact row number & reason), and intra-file or cross-school duplicate LRNs.
   - Require explicit Master Admin confirmation before committing an import batch.
4. **Controlled Updates & Claim Safety:**
   - Re-importing an existing LRN within the same `schoolId` updates roster metadata (`gradeLevel`, `displayName`, `sex`, `birthDate`, `parentMetadata`) **without** clearing an existing `claimedByUid` or resetting an already-approved `studentProfiles/{claimedByUid}`.
   - If an imported LRN conflicts with an active claim in a *different* school or a mismatched student identity, flag the row as a `conflict` in the preview and skip overwriting until resolved.
5. **Immutable Import History:** Record each committed SF1 batch in `schoolRosterImports/{importId}` (`schoolId`, `actorUid`, `fileName`, `fileSha256`, `createdCount`, `updatedCount`, `skippedConflictCount`, `importedAt`) without storing raw uploaded spreadsheet binaries in Firestore.
