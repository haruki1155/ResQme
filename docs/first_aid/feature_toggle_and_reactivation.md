# ResQMe First Aid Expansion — Feature Toggle & Reactivation Guide

## 1. Centralized Feature Flag Configuration

| Property | Value |
|---|---|
| **File Path** | `lib/core/config/first_aid_feature_flags.dart` |
| **Class & Constant** | `FirstAidFeatureFlags.enableExpandedFirstAid` |
| **Default Value** | `false` |
| **Control Scope** | Compile-time developer constant (`static const bool`); not user-configurable and requires zero backend or Firebase Remote Config services. |

```dart
abstract final class FirstAidFeatureFlags {
  static const bool enableExpandedFirstAid = false;
}
```

---

## 2. Routing Behavior (`OFF` vs. `ON`)

### When `enableExpandedFirstAid == false` (Default — Feature OFF)
- **Home Interface**: `FirstAidLibraryScreen` renders the restored Original First Aid Instruction experience (`IMMEDIATE CARE GUIDE` / `What do you need help with?`) with category filtering, title search, expandable cards, `FirstAidDetailScreen` (`Open full guide`), and prominent `Call 911` + `Emergency hotlines` controls.
- **Original Content Safety Filtering**: Loads the 8 safety-eligible original guides (`eligibleOriginalFirstAidGuides` in `lib/features/public_support/data/original_first_aid_guides.dart`) while withholding 2 legacy guides (`Asthma` and `Moving an injured person`) that contain unprescribed medication dosing or unguarded trauma-movement instructions pending clinical review.
- **Expanded Content Isolation**: All 66 expanded IFRC 2025 procedures and the Learning Library are hidden from browsing, search, categories, related topics, and direct screen navigation (`FirstAidQuickInstructionScreen`, `FirstAidLearningLibraryScreen`, and `FirstAidArticleScreen` render a restricted guard view if pushed directly).
- **Offline & Unauthenticated Access**: Preserved across cold-start Terms, Scanner Entry, and Guest Dashboard.

### When `enableExpandedFirstAid == true` (Feature ON)
- **Release Gate Preserved**: `FirstAidFeatureFlags.enableExpandedFirstAid` does **not** bypass `FirstAidReleasePolicy` (`lib/features/public_support/domain/first_aid_release_policy.dart`).
- **Public Release Builds (`--release`)**: Only procedures in `assets/data/first_aid_library.json` whose `review` block has `clinicalApproval == "approved"`, a non-empty `reviewer`, and a non-empty `approvedAt` date are eligible for display across Quick Instructions, English + Filipino search, Learning Library articles, related topics, and direct navigation.
- **Zero-Approved Safe Fallback**: If `enableExpandedFirstAid == true` in a public release build where `0` expanded procedures have clinical approval, `FirstAidLibraryScreen` automatically falls back to the eligible original First Aid guides and emergency calling controls rather than rendering an empty library.
- **Clinical Review Draft / Staging Debug Builds (`--debug`)**: Displays `sourceVerification == "verified"` IFRC 2025 procedures with the `Clinical review pending` banner for internal clinical inspection.

---

## 3. Prerequisites Before Enabling for Public Release

1. **IFRC Content Reuse Clarification**: Confirm organizational permission/attribution compliance for adapting the *IFRC International First Aid, Resuscitation and Education Guidelines 2025*.
2. **Qualified Human Clinical Sign-Off**:
   - Have a licensed medical reviewer inspect each procedure in `assets/data/first_aid_library.json` against `docs/first_aid/clinical_review_matrix.md`.
   - Update each approved topic's `review` object in `assets/data/first_aid_library.json`:
     ```json
     "review": {
       "sourceVerification": "verified",
       "clinicalApproval": "approved",
       "reviewer": "<Full Name & Credentials>",
       "reviewerQualification": "<Specialty / License / Role>",
       "approvedAt": "YYYY-MM-DD"
     }
     ```
   - Never enter placeholder or AI-generated reviewer names.

---

## 4. How to Enable (Reactivate) the Expanded Feature

1. Record genuine clinical approvals in `assets/data/first_aid_library.json` (if targeting `--release`).
2. Edit `lib/core/config/first_aid_feature_flags.dart`:
   ```dart
   abstract final class FirstAidFeatureFlags {
     static const bool enableExpandedFirstAid = true;
   }
   ```
3. Run static analysis and the verification test suite from `resqme/`:
   ```powershell
   flutter analyze
   flutter test
   ```
4. Rebuild the Student staging APK:
   ```powershell
   flutter build apk --debug --flavor student --dart-define=RESQME_BACKEND=staging
   ```
5. Verify active version on device/test:
   - Confirm First Aid Home displays **`Act first. Learn more when needed.`**, **`Learning Library — Learn More`**, **`COMMON EMERGENCIES`**, and Filipino keyword search (e.g., `Nabulunan` -> Choking procedures).

---

## 5. How to Disable (Roll Back Safely)

1. Set `enableExpandedFirstAid` back to `false` in `lib/core/config/first_aid_feature_flags.dart`:
   ```dart
   abstract final class FirstAidFeatureFlags {
     static const bool enableExpandedFirstAid = false;
   }
   ```
2. Do **not** delete `assets/data/first_aid_library.json`, `lib/features/public_support/`, or `docs/first_aid/`.
3. Verify and rebuild from `resqme/`:
   ```powershell
   flutter analyze
   flutter test
   flutter build apk --debug --flavor student --dart-define=RESQME_BACKEND=staging
   ```
4. Confirm First Aid Home displays **`What do you need help with?`**, **`8 GUIDES`**, **`Call 911`**, and **`Emergency hotlines`**, with no `Learning Library` button or expanded IFRC procedures visible.
