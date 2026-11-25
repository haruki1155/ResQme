# ResQMe Portal — Phase 2.5: Activity Logs and Supervision Design Specification

Date: 2026-11-25  
Branch: `feat/resqme-admin-tier2-access`  
Baseline HEAD: `7fcef93`

---

## 1. Existing Audit Collections Reused (No Duplication)

1. **`staffManagementAudits`**
   - Written by: `master_admin_provisioning.ts`, `staff_account_management.ts`, `enroll_staff_tier2_device.ts`, `staff_student_management.ts`, `staff_qr_replacement.ts` (and `sf1_roster_import.ts` in Phase 3).
   - Fields: `schoolId`, `actorUid`, `actorRole`, `action`, `targetUid` (or `targetType`/`targetId`), `outcome`, `reason` / `method` / `credentialVersion`, `recordedAt` (or `createdAt`).
2. **`tier2AccessAudits`**
   - Written by: `read_student_tier2.ts` for both `allowed` and `denied` emergency Tier 2 medical scans.
   - Fields: `schoolId`, `actorUid`, `actorRole`, `targetUid`, `deviceId`, `purpose`, `outcome`, `reasonCode`, `recordedAt`.

Both collections are already protected by `firestore.rules` catch-all `allow read, write: if false;`, preventing any client read, modification, or deletion.

---

## 2. Backend Callable: `listSchoolActivityLogs`

- **Authorization:** Master Admin-only (`requireMasterAdmin`), `emailVerified === true`, `setupComplete === true`, active status. Authorized personnel and students are denied (`permission-denied`).
- **School Scoping:** Queries `staffManagementAudits` and `tier2AccessAudits` strictly scoped to `where('schoolId', '==', admin.schoolId)`.
- **Request Schema:**
  ```ts
  {
    category?: 'all' | 'security' | 'management' | 'tier2';
    outcome?: 'all' | 'allowed' | 'denied';
    actorUid?: string | null;
    search?: string;
    startDate?: string | null; // YYYY-MM-DD
    endDate?: string | null;   // YYYY-MM-DD
    limit?: number;            // 1..50, default 25
    cursor?: string | null;    // "<timestampMs>:<id>"
  }
  ```
- **Normalization & Redaction:**
  - Maps `action` / `sourceCollection` into `category` (`security`, `management`, `tier2`) and human-readable `actionLabel` + safe `summary`.
  - Normalizes `recordedAt` / `createdAt` to ISO timestamp and sorts newest-first.
  - **Strict redaction:** Never exposes raw LRNs, passwords, medical contents, QR payloads, biometric proofs, or private keys.

---

## 3. Portal UI: `ActivityLogsScreen`

- **Navigation:** Added as a compact **Activity Logs** quick-action card on `PortalDashboardScreen` for Master Admin only (no extra bottom-navigation tab; Authorized personnel never see it).
- **Capabilities:** Chronological newest-first list, category filter chips (`All`, `Security`, `Management`, `Tier 2 Access`), outcome filter (`All`, `Allowed`, `Denied`), date-range selection, search box, safe detail modal/card, and loading/empty/error/pagination states using the `#E92B32` / `#FFFFFF` / `#F1F3F7` Portal theme.
