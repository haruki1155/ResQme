# ResQMe Tier 1 Delivery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the mockup-aligned, secure Tier 1 ResQMe pilot without implementing or exposing Tier 2 medical information.

**Architecture:** Keep Flutter's existing Navigator and feature-first structure. Public content is bundled for offline use; authentication, QR credentials, lifecycle actions, roles, and audit events are enforced by TypeScript callable Functions and deny-by-default Firestore Rules in the local Emulator Suite.

**Tech Stack:** Flutter/Dart, Material 3, Firebase Auth/Firestore/Functions, Emulator Suite, TypeScript, `mobile_scanner`, `qr_flutter`, `printing`, and `url_launcher` only where each planned slice requires them.

**Spec:** `docs/superpowers/specs/2026-10-28-tier-1-product-design.md`

## Global Constraints

- Use the mockups in `docs/mockups` as the Tier 1 visual reference; mockups 09-14 are excluded.
- Work only in this local project using standard Git branches; do not create worktrees or duplicate the project.
- Commit every completed milestone; never delete, push, merge, deploy, or modify billing without approval.
- Use only `resqme-943ee`, synthetic data, and local Firebase emulators.
- Never store medical information, private contacts, or raw QR tokens in QR codes, public responses, client logs, or audit metadata.
- Public scans open a neutral verified-ID Tier 1 Home Lobby only; they reveal no student identity or school.
- Guardian consent is enrollment consent, not authentication and not Tier 2 authorization.
- Tier 2 routes display only a restricted-access boundary; no biometric, medical, or protected-data implementation is allowed.
- A normal `tel:` action is permitted only for approved public hotlines, never as protected-contact calling.

## Review Focus

- A declined camera permission, malformed QR, unknown QR, locked QR, expired QR, and offline resolver must fail closed and retain public help.
- The Tier 2 tile must never invoke local authentication, Firestore reads, Functions, or display mockup sample data.
- A self-registering account must remain pending until the configured synthetic guardian-approval flow completes.
- Only authorized admins can recover/reactivate or replace a locked credential; the client must not grant itself an admin role.
- Direct Firestore client access to QR credentials, contacts, roles, and audit events must be denied even for authenticated users.

### Task 1: Mockup-aligned public navigation shell

**Files:** Modify `lib/app/*`, `lib/features/welcome/*`, `lib/features/emergency/*`; create `lib/features/medical_boundary/*`; modify/add associated widget tests.

**Interfaces:** Add route constants for scanner, first aid, hotlines, DRRM, and medical boundary. `EmergencyDashboardScreen` produces the Home Lobby with `verifiedStatus` and public action callbacks.

- [ ] Write widget tests for the mockup-aligned Home Lobby, every public route, back navigation, and the Tier 2 boundary's absence of medical content.
- [ ] Run the focused tests and verify they fail because routes/screens do not exist.
- [ ] Implement the red/navy/rounded-card visual system from mockups 01, 02, and 04; make public cards navigable and the Tier 2 tile an explicit unavailable boundary.
- [ ] Run `flutter analyze` and focused widget tests; verify they pass.
- [ ] Commit: `feat: align public shell with Tier 1 mockups`.

### Task 2: Offline first aid, hotlines, and DRRM

**Files:** Create `assets/tier1_content/*.json`, `lib/features/public_support/*`, and tests; modify `pubspec.yaml` only if `url_launcher` is added.

**Interfaces:** `PublicContentRepository.load() -> Future<PublicContent>` reads versioned bundled content. Screens provide `FirstAidLibraryScreen`, `FirstAidGuideScreen`, `HotlineDirectoryScreen`, `DrrmLibraryScreen`, and `EmergencyActionPlanSheet`.

- [ ] Add failing parser/widget tests for bundled content, offline rendering, guide/action-plan navigation, and public-call URI construction.
- [ ] Add a small, clearly synthetic/review-pending content fixture with source, reviewer, locale, version, and review date metadata; do not claim operational approval.
- [ ] Implement mockup 05-08 layouts, searchable/expandable first-aid guidance, DRRM action sheets, and public-hotline-only dialing.
- [ ] Run `flutter analyze` and public-support tests; verify all pass.
- [ ] Commit: `feat: add offline public emergency guidance`.

### Task 3: Synthetic account enrollment and trusted roles

**Files:** Create `lib/features/student/*`, `functions/src/auth/*`, `functions/test/auth/*`; modify `firestore.rules`, Functions exports, and Rules tests.

**Interfaces:** `registerSyntheticStudent`, `submitGuardianConsent`, and `getMyEnrollment` callable contracts return nonmedical enrollment state. `Role` is trusted server state only.

- [ ] Write failing Functions and Emulator Rules tests for unauthenticated calls, invalid fields, self-assigned roles, pending enrollment, and owner isolation.
- [ ] Implement synthetic-only registration and pending guardian-consent state; provision the sole test admin through an emulator fixture, never client input.
- [ ] Add enrollment/profile UI and state tests; do not create any Tier 2 entitlement.
- [ ] Run Functions build/tests, Rules tests, Flutter tests under emulators; verify all pass.
- [ ] Commit: `feat: add synthetic enrollment and trusted roles`.

### Task 4: Server-issued QR credential, scanner, and safe result

**Files:** Create `lib/features/qr/*`, `functions/src/qr/*`, Functions/Rules/widget tests; modify Android camera permission and `pubspec.yaml` for scanner/QR/printing dependencies.

**Interfaces:** `issueMyCredential()`, `resolvePublicCredential(token)`, and `renderCredentialQr(url)`; resolver output is `PublicCredentialStatus` only, without identity fields.

- [ ] Write failing tests for opaque-token format, public status-only response, rate-limit/error behavior, invalid/locked/expired/unknown/offline UI, and camera denial.
- [ ] Implement server-generated random credential tokens, server-side digest storage, status resolver, My QR display/print rendering, and mockup 03 scanner.
- [ ] Make a successful scan replace the scanner with the verified-status Home Lobby; retain public-help actions for every failure state.
- [ ] Run Flutter, Functions, Rules, and Emulator tests; verify all pass.
- [ ] Commit: `feat: add secure QR issuance and public verification`.

### Task 5: Lost ID lifecycle and minimal admin QR management

**Files:** Create `lib/features/admin/*`, lifecycle UI/tests, `functions/src/qr_lifecycle/*`, audit test fixtures; modify Rules and indexes only as required.

**Interfaces:** `reportLostCredential()`, `requestReplacement()`, `adminLookupCredential()`, `adminRecoverCredential()`, and `adminApproveReplacement()` return safe lifecycle state. `auditEvent()` is server-only.

- [ ] Write failing transaction and Rules tests for lock, recover, replacement, admin authorization, double submission, and forbidden direct audit/credential writes.
- [ ] Implement atomic server-side lifecycle transitions and sanitized immutable audit events; a lost account is deactivated, never deleted.
- [ ] Implement student lost-ID/replacement screens and minimal admin lookup/recover/approve screens with honest pending/success/error states.
- [ ] Run full Functions, Rules, Flutter, and emulator suites; verify all pass.
- [ ] Commit: `feat: add audited QR lifecycle management`.

### Task 6: Protected-contact interface, Emergency Medical Alert boundary, and acceptance

**Files:** Create `lib/features/contact_calling/*`, boundary tests, and `docs/tier1/acceptance.md`; modify the Tier 2 boundary and README.

**Interfaces:** `ProtectedContactCallProvider.requestCall()` has an unavailable local implementation; `EmergencyMedicalAlertBoundary` exposes only public-help actions.

- [ ] Write failing tests that prove protected calling cannot create a `tel:` URI, no provider call occurs in the unavailable implementation, and the medical boundary makes no data request.
- [ ] Implement the unavailable provider interface and mockup-inspired restricted sheet; link only public help and approved public hotlines.
- [ ] Run accessibility/text-scale tests, `flutter analyze`, full Flutter/Functions/Rules suites, emulator checks, and `flutter build apk --debug`.
- [ ] Record PASS/FAIL/BLOCKED evidence in the acceptance document; physical Android validation is BLOCKED until a device/emulator is available.
- [ ] Commit: `test: complete Tier 1 safety acceptance`.

## Self-review

- **Spec coverage:** Tasks 1-2 cover mockup-aligned public support; Tasks 3-5 cover enrollment, trusted QR issuance, verification, lifecycle, admin controls, and audits; Task 6 covers the unavailable contact interface, medical boundary, and final acceptance.
- **Step scan:** Every task starts with failing tests, implements named interfaces, verifies focused behavior, and commits independently.
- **Type consistency:** `PublicCredentialStatus` is the only public resolver DTO; lifecycle callables consume its credential reference rather than raw tokens; all protected actions remain server-owned.
- **Review focus:** Each listed failure mode is owned by Tasks 1, 3, 4, 5, or 6 respectively.
- **Proportion:** This is a delivery roadmap with six independently reviewable commits; external content/provider approvals remain gates rather than fabricated operational features.
