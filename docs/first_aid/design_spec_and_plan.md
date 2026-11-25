# ResQMe — IFRC 2025 First Aid Instruction Expansion: Assessment, Design Specification & Implementation Plan

## 1. Repository Baseline & Assessment (Phase A)

### Git & Workspace Baseline
- **Outer Workspace Repository** (`c:/Users/Mj/Desktop/Coding Projects/resqmE_1.0`): branch `main`, HEAD `643c0b9b58a1627dd2410a3ef85047741e8cd745`.
- **Application Repository** (`resqme/`): branch `feat/resqme-admin-tier2-access`, HEAD `39957a76573aeb6db44e6a653a6b96362aaf852d`.
- **Pre-existing Uncommitted Working-Tree Changes (Preserved Intact)**:
  - School reviewer & Tier 2 files (`lib/app/resqme_app.dart`, `lib/app/staff_qa_app.dart`, `lib/main_staff_qa.dart`, `lib/features/medical/widgets/account_dashboard_panel.dart`, `lib/features/qr/presentation/qr_scanner_screen.dart`, `lib/features/school/...`, `functions/...`, `docs/...`, `test/app/school_reviewer_navigation_test.dart`, `test/app/staff_qa_app_test.dart`, `test/features/school/school_review_screen_test.dart`).
  - All out-of-scope and uncommitted changes are strictly preserved.

### Existing Implementation Assessment
- **Entry Points & Public Navigation**:
  - `SplashScreen` (`lib/features/welcome/presentation/splash_screen.dart`) checks `ConsentRepository.hasAcceptedTerms()` and routes to `TermsPrivacyScreen` (`AppRoutes.terms`) or `ScannerEntryScreen` (`AppRoutes.entry`).
  - `ScannerEntryScreen` provides `Go to Dashboard as Guest` -> `EmergencyDashboardScreen` (`AppRoutes.dashboard`), which links to `AppRoutes.firstAid` (`FirstAidLibraryScreen`), `AppRoutes.hotlines` (`EmergencyHotlinesScreen`), and `AppRoutes.drrm` (`DrrmScreen`) without requiring authentication, student registration, QR scanning, or biometric unlock.
  - **Cold-Start Gap Identified**: On a brand-new cold install before Terms acceptance (`TermsPrivacyScreen`) or immediately on `ScannerEntryScreen`, reaching First Aid currently requires accepting terms and/or passing through the guest dashboard first (3+ taps). Adding non-intrusive public emergency shortcuts (`First-aid instructions`) on `ScannerEntryScreen` and `TermsPrivacyScreen` guarantees immediate cold-start access without exposing student/account routes or breaking existing consent/scanner tests.
- **Emergency Contact Functionality**:
  - `EmergencyHotlinesScreen` (`lib/features/public_support/presentation/emergency_hotlines_screen.dart`) already implements a verified Philippine directory led by **National Emergency Hotline `911`** and **Philippine Red Cross `143`**, plus Urdaneta City CDRRMO/EMS, PNP, BFP, CHO, UDH, and NDRRMC, with a confirmation-gated dialer handoff (`tel:911` — never places an automatic call). Reusable directly.
- **Theme & Visual Identity**:
  - `ResQMeTheme.light` (`lib/app/resqme_theme.dart`) uses Material 3 with ResQMe emergency red (`#E92B32` / `#E3222A`), crisp white cards, `#F1F3F7` / `#F5F6F8` light neutral surfaces, and dark ink (`#10131C`). Zero new external packages are required.
- **Existing First Aid Implementation & Medical Content Audit**:
  - `lib/features/public_support/presentation/first_aid_screens.dart` currently hardcodes 10 `FirstAidGuide` items in-memory with title-only `String.contains` search, no offline JSON asset, no Learning Library, no source citations, no clinical review metadata, and `<16 sp` (`14 sp`) body text.
  - **Medical Content Requiring Replacement / Separation**:
    1. *Asthma*: Uses regional 4x4x4 blue/grey puffer protocol rather than IFRC 2025 bronchodilator/spacer/action-plan guidance (pp. 245–249).
    2. *Anemia*: Not an IFRC 2025 First Aid topic (replaced by evidence-based IFRC 2025 topics: *Shock*, *Severe bleeding*, *Feeling faint*, *Breathing difficulties*).
    3. *Nosebleed*: Lists 10–15 min; must align with IFRC 2025 >=10 min continuous pinch and >20 min escalation threshold (pp. 354–356).
    4. *Hyperventilation*: Subsumed in IFRC 2025 under *Breathing difficulties* (pp. 232–237) and *Anxiety and panic* (pp. 515–521) with explicit warning against paper-bag rebreathing; retained via `searchKeywords`.
    5. *Moving an injured person*: Non-IFRC wheelchair/stretcher summary; properly addressed in IFRC 2025 under *Scene safety* (pp. 114–128: move only from immediate danger) and *Spinal injuries* (pp. 307–311); retained via `searchKeywords`.
    6. *Basic life support (BLS) / CPR*: Mixes adult compression-only CPR and AED, omits *Child CPR* and *Infant CPR*, and uses AHA phrasing; separated into *Adult and adolescent CPR*, *Child CPR*, *Infant CPR*, and *AED use* per IFRC 2025 (pp. 159–207).
    7. *Choking (blocked airway)*: Combines adult/child/infant and cites AHA; separated into *Adult choking*, *Child choking*, and *Infant choking* per IFRC 2025 (pp. 238–244).
    8. *Bleeding and wound care*: Recommends limb elevation and mixes minor/severe wounds; separated into *Severe bleeding* (direct pressure, haemostatic dressings, tourniquet 5–7 cm above limb wound), *Cuts and grazes*, *Amputation*, and *Chest and abdominal injuries* per IFRC 2025 (pp. 256–279).
    9. *Burns*: Updated to exact IFRC 2025 >=20 min cool running water, hypothermia precaution, loose cling-film/sterile dressing, chemical irrigation, and electrical power-off rules (pp. 288–298).
    10. *Fractures, sprains, dislocations & seizures*: Combines unrelated trauma and neurological emergencies and uses routine RICE compression; separated into *Fractures*, *Sprains*, *Strains*, and *Seizures* per IFRC 2025 (pp. 301–306, 396–400).

---

## 2. Canonical Medical Source Metadata (Phase B)

| Attribute | Verified Value |
|---|---|
| **Document Title** | *International first aid, resuscitation and education guidelines 2025* |
| **Organization** | International Federation of Red Cross and Red Crescent Societies (IFRC), coordinated by the IFRC Global First Aid Reference Centre (GFARC), Geneva |
| **Guideline Edition** | 2025 Edition |
| **Publication Date** | 2025 (© IFRC, Geneva, 2025) |
| **Official Source URL** | https://www.ifrc.org/document/ifrc-international-first-aid-resuscitation-and-education-guidelines-2025 |
| **Local PDF SHA-256** | `EED67BDFF38CA8A7628C7B01BE5BCD23796601E0D85BB021DC301EC3F9FF8F1F` |
| **Total Pages** | 594 pages |
| **Printed vs. PDF Page Numbering** | 1:1 alignment across pages 1–594 (First Aid clinical chapters span printed/PDF pages 113–522; note minor Topic Index vs. heading start offsets on Adult CPR [Index p. 158, heading p. 159] and Suspected Opioid Overdose [Index p. 207, heading p. 208], both recorded explicitly). |
| **Copyright & Adaptation** | Non-commercial educational/first-aid adaptation permitted with source acknowledgement (p. 2). All content in ResQMe is adapted into original, concise action-oriented instructions with page-level IFRC 2025 attribution; no verbatim chapter reproduction and no claim of IFRC endorsement or certification. |

---

## 3. Target Architecture & Implementation Plan

### Governing Design Principle
**"Act first. Learn more when needed."** — Deterministic, offline-first local asset architecture with zero runtime network, AI/ML, or Firebase dependencies.

### Single Canonical Content Schema (`assets/data/first_aid_library.json`)
- Registered in `pubspec.yaml` and loaded offline via `AssetBundle` with in-memory caching and graceful fallback on malformed/missing JSON.
- Each canonical `FirstAidTopic` record contains:
  - Identity & classification: `id`, `title`, `shortTitle`, `category`, `classification` (`critical_emergency`, `common_first_aid`, `learning_library`, `trained_responder_only`), `urgency`, `ageGroup`, `audience` (`lay_responder` vs `trained_responder`), `isCommonEmergency`, `requiresEmergencyCall`.
  - Search index fields: `searchKeywords` (English medical terms, everyday expressions, and Filipino/Tagalog synonyms such as `nabulunan`, `hika`, `paso`, `pilay`, `balinguyngoy`, `walang malay`, `kagat ng aso`, `nalunod`, `kombulsyon`, `lason`, `heat stroke`, `atake sa puso`).
  - **Layer 1 (`quickInstructions`)**: `immediateAction`, `recognitionSigns`, `steps` (3–7 concise action-verb steps where medically appropriate, preserving exact measurements/durations/positions), `conditionalActions`, `warnings`, `emergencyEscalation`.
  - **Layer 2 (`learnMore`)**: `overview`, `causes`, `riskFactors`, `detailedRecognition`, `prevention`, `preparation`, `explanations` (medical rationale), `additionalPrecautions`, `followUpCare`.
  - Traceability & Release Control: `relatedTopics`, `source` (`organization`, `edition`, `chapter`, `topicTitle`, `printedPages`, `pdfPages`, `url`), `contentVersion`, `review` (`sourceVerification`, `clinicalApproval: "pending"`, `reviewer: null`, `reviewerQualification: null`, `approvedAt: null`).

### Clinical Approval Filtering (`FirstAidReleasePolicy`)
- **Public Release Builds (`kReleaseMode == true`)**: Strictly exclude any topic where `review.clinicalApproval != 'approved'`. When unapproved topics are excluded, the UI safely explains that clinical review is pending and keeps `Call 911` and `Emergency Hotlines` immediately accessible.
- **Isolated Development / Staging / Clinical-Review Builds (`!kReleaseMode` or explicit non-release clinical review flag)**: Permit controlled inspection of `sourceVerification == 'verified'` draft content with a clear `PENDING CLINICAL REVIEW` indicator and non-endorsement attribution notice.

### Proposed File Changes
- `resqme/pubspec.yaml` — Register `assets/data/first_aid_library.json`.
- `resqme/assets/data/first_aid_library.json` — Complete canonical IFRC 2025 two-layer content library (66 procedures covering all 57 IFRC clinical chapters + age/condition/responder splits).
- `resqme/lib/features/public_support/domain/first_aid_models.dart` — Immutable models (`FirstAidTopic`, `QuickInstructions`, `LearnMoreArticle`, `ConditionalAction`, `SourceReference`, `ReviewMetadata`, `FirstAidLibraryBundle`).
- `resqme/lib/features/public_support/domain/first_aid_release_policy.dart` — Build-mode release gate (`publicRelease` vs `clinicalReviewDraft`).
- `resqme/lib/features/public_support/data/first_aid_repository.dart` — Offline `AssetBundle` loader, schema validator, malformed-JSON guard, and clinical-approval filter.
- `resqme/lib/features/public_support/domain/first_aid_search_engine.dart` — Deterministic local search ranking: exact title -> title word/prefix -> synonym/keyword exact -> keyword prefix/substring -> category/recognition match.
- `resqme/lib/features/public_support/presentation/emergency_call_helper.dart` — Shared confirmation-gated `Call 911` / `Emergency Hotlines` helper reusing verified PH numbers (`911`, `143`).
- `resqme/lib/features/public_support/presentation/first_aid_screens.dart` — Upgraded `FirstAidLibraryScreen` (First Aid Home), `FirstAidQuickInstructionScreen` (8-item emergency hierarchy, >=16 sp steps, >=48 dp targets), `FirstAidLearningLibraryScreen`, and `FirstAidArticleScreen` (bidirectional `Learn More` <-> `View First Aid Instructions` navigation preserving scroll/search state).
- `resqme/lib/features/welcome/presentation/scanner_entry_screen.dart` & `terms_privacy_screen.dart` — Minimal cold-start public `First-aid instructions` shortcut without altering consent persistence or student auth gates.
- `resqme/docs/first_aid/ifrc_2025_coverage_matrix.md` & `resqme/docs/first_aid/clinical_review_matrix.md` — Complete medical mapping, source-fidelity audit, and clinical review handoff ledger.
- `resqme/test/features/public_support/...` — Comprehensive TDD unit, content-integrity, search, accessibility, offline, and navigation widget tests.
