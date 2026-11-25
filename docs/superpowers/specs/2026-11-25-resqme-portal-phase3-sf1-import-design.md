# ResQMe Portal — Phase 3: SF1 Student Roster Import Design Specification

Date: 2026-11-25  
Branch: `feat/resqme-admin-tier2-access`  
Baseline HEAD: `7fcef93`

---

## 1. Legacy `School-Forms-1.xls` Template Assessment

Inspected `School-Forms-1.xls` (`School Form 1 (SF1)`, `A1:AA80`, `270` merged ranges):
- **Metadata Rows (`R1..R6`):** `School ID`, `Division`, `District`, `School Name`, `School Year`, `Grade Level`, `Section`.
- **Header Rows (`R8..R9`):** Merged header labels (`LRN`, `NAME (Last Name, First Name, Middle Name)`, `Sex (M/F)`, `BIRTH DATE (mm/dd/ yyyy)`, `PARENTS` -> `Father's Name`, `Mother's Maiden Name`, `GUARDIAN (If not Parent)` -> `Name`, `Relation-ship`, `Contact Number of Parent or Guardian`).
- **Footer / Legend Rows (`R59+`):** `List and Code of Indicators under REMARKS`, `Prepared by`, `Certified Correct`, `REGISTERED` / `BoSY` / `EoSY` / `MALE` / `FEMALE` / `TOTAL`.

---

## 2. Excel Parsing (`functions/src/school/sf1_parser.ts`)

- Uses maintained `xlsx` package (`XLSX.read(..., {type: 'buffer', cellDates: true, raw: false})`), supporting both `.xls` and `.xlsx`.
- Enforces limits: max `2 MB` file size, max `2,500` total rows, max `500` student rows per import.
- Dynamically locates header & subheader rows (never hardcodes fixed column indices).
- Skips headings, blank rows, totals, legend, and signature footer rows.
- Extracts only the 12 approved fields: `lrn`, `lastName`, `firstName`, `middleName`, `sex`, `birthDate`, `gradeLevel`, `fatherName`, `motherMaidenName`, `guardianName`, `guardianRelationship`, `parentGuardianContact`.
- Preserves LRNs as exact 12-digit strings (`/^\d{12}$/`) and parses Excel serial/text dates strictly to `YYYY-MM-DD` (rejecting invalid/ambiguous dates).
- Derives `gradeLevel` from sheet metadata or explicit Master Admin confirmation (`confirmedGradeLevel`).

---

## 3. Server-Authoritative Preview & Commit (`functions/src/school/sf1_roster_import.ts`)

1. **`previewSchoolRosterImport`**
   - Master Admin-only, verified email, same `schoolId`, rate-limited.
   - Classifies every row as `new`, `unchanged`, `proposed_update`, `duplicate`, `conflict`, or `invalid`.
   - Checks intra-file duplicate LRNs, existing `schoolRosterClaims`, and existing `studentProfiles` claims.
   - Returns **masked LRNs only** (`XXXX••••XXXX`) and summary counts.
   - Persists short-lived `schoolRosterImportPreviews/{previewId}` (15-min TTL) bound to `schoolId`, `actorUid`, `fileSha256`, `confirmedGradeLevel`, and normalized rows.
2. **`commitSchoolRosterImport`**
   - Master Admin-only, `{ previewId, requestId }`.
   - Idempotent via `schoolRosterImports/{requestId}` and supports resumable chunked transactions (up to 100 students per Firestore transaction) for large imports without duplicate records.
   - Reuses `schoolRosterClaims/{rosterLookupId(lrn, key)}` and `schoolRosterCodes/{rosterCodeDigest(code, key)}`.
   - Generates a cryptographically random 20-char enrollment code per `new` student (never derived from LRN/name/birthDate), returning generated codes only in the commit response and storing only HMAC digests in Firestore.
   - Records import summary in `schoolRosterImports/{requestId}` and `staffManagementAudits` (no raw LRNs or enrollment secrets logged).
3. **`listSchoolRosterImports`**
   - Returns paginated import history for the Master Admin's school.

---

## 4. Student Roster UI & Native Excel Picker

- **Native Android Picker (`MainActivity.kt`):** `ACTION_OPEN_DOCUMENT` channel method `pickExcelFile` supporting `.xls` and `.xlsx` (zero third-party Flutter picker dependencies).
- **`StudentRosterScreen`:** Adds **Import Student Roster** button, Grade-level confirmation, Validation & Preview summary (with masked LRNs and conflict/invalid row review), Explicit Import Confirmation + progress feedback, Import History sheet/section, updated roster statistics, and Grade + Registration filters.
- **Automatic Verification Compatibility:** Student registration continues to match `schoolRosterClaims` + `schoolRosterCodes` via `evaluateRosterClaim`, inheriting `gradeLevel` without bypassing minor guardian authorization, medical completion, or QR eligibility.
