# ResQMe Tier 1 Functional Delivery Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan one milestone at a time. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a simple, working, emulator-only Tier 1 ResQMe pilot: public emergency guidance, safe QR verification, synthetic-student QR management, and minimal authorized administration.

**Spec:** `docs/superpowers/specs/2026-10-28-tier-1-product-design.md`

## What the supplied documents add

| Supplied document | Tier 1 use | Delivery treatment |
| --- | --- | --- |
| `FIRST-AID-INSTRUCTIONS.docx` | Offline first-aid topics and steps | Convert to concise, versioned local content after a named reviewer approves its wording and emergency advice. |
| `DRRM-GUIDELINES.docx` | Offline disaster-preparedness topics and before/during/after actions | Convert to versioned local content, preserving the source attribution and review date. |
| `BASIC-PROFILE.docx` | Reference only | Excluded. It is explicitly a Tier 2 profile and contains health, private-contact, biometric, and authorized-access data. No fields or sample values from it enter Tier 1. |

## Safety decisions already fixed

- Build and test only against the local Firebase Emulator Suite and `resqme-943ee`; do not deploy.
- Use synthetic accounts and data only.
- Public scan results show a neutral credential status and open the Tier 1 Home Lobby. They never show a name, school, student identifier, contact, or medical detail.
- A QR contains only an opaque, server-issued credential URL/token. It contains no personal or medical information.
- Tier 2 remains a restricted-information screen only. It does not use biometrics, fetch profiles, or display medical data.
- Public hotlines may use the device dialer. Private emergency contacts must remain unavailable until a separately approved provider/policy exists.
- A lost QR is locked/deactivated, not deleted. Authorized administrators may recover it or approve a replacement, with an audit record.

## Lean delivery sequence

### Task 1: Complete the public app shell

**Outcome:** A user can accept Terms, reach the Home Lobby, open every public Tier 1 destination, return safely, and see a clear Tier 2 restricted boundary.

- [ ] Finish mockup-aligned Splash, Terms, Home Lobby, and bottom navigation.
- [ ] Add real routes for scanner, first aid, hotlines, DRRM, profile entry, and Tier 2 boundary.
- [ ] Make every service card actionable; do not leave decorative cards that appear functional.
- [ ] Add widget tests for Terms gating, routes, back navigation, and the absence of medical content in the Tier 2 boundary.
- [ ] Run `flutter analyze` and focused Flutter tests.
- [ ] Commit: `feat: complete Tier 1 public navigation`.

### Task 2: Ship offline public guidance

**Outcome:** First aid and DRRM work with no network connection, and public hotline calling is clear and honest.

- [ ] Transform the approved portions of the two supplied guidance documents into small bundled content files with title, steps, source, locale, version, review date, and reviewer.
- [ ] Create First Aid library/detail screens using mockup 05 and DRRM library/action-plan screens using mockups 07-08.
- [ ] Create the public hotline directory using an approved list; a tap opens only a public hotline in the device dialer.
- [ ] Include a prominent emergency disclaimer and an “call emergency services” action where the approved content requires it.
- [ ] Test offline rendering, content navigation, error handling, and dialer URI creation.
- [ ] Run `flutter analyze` and public-guidance tests.
- [ ] Commit: `feat: add offline Tier 1 guidance`.

### Task 3: Add synthetic enrollment and My QR

**Outcome:** A test student can create a nonmedical Tier 1 profile, complete the approved consent flow, and view a server-issued QR after approval.

- [ ] Add Firebase Auth emulator sign-up/sign-in for synthetic students only.
- [ ] Collect only the approved Tier 1 profile and guardian-consent fields; do not collect health data, private contacts, or Tier 2 fields.
- [ ] Create a pending/approved enrollment state, with the guardian-consent policy clearly explained as enrollment consent rather than two-factor or Tier 2 access.
- [ ] Have a callable Cloud Function issue an opaque credential only for an approved student.
- [ ] Add My QR display and print/share rendering. The QR never embeds profile data.
- [ ] Test unauthorized calls, invalid fields, owner isolation, pending enrollment, and QR issuance with Auth, Functions, Rules, and Flutter tests under emulators.
- [ ] Commit: `feat: add synthetic enrollment and My QR`.

### Task 4: Add public QR scan and verification

**Outcome:** Anyone can scan a ResQMe QR and receive only a safe status before entering the Tier 1 Home Lobby.

- [ ] Add camera permission, scanner UI, manual test-token entry for emulator/widget testing, and clear permission/offline states.
- [ ] Resolve QR credentials through a rate-limited callable Function that checks a stored token digest and credential status.
- [ ] Support only: active/verified, locked, expired, unknown, invalid, and offline outcomes. Every non-active outcome fails closed and preserves access to public guidance.
- [ ] Do not return or log raw tokens, profile data, contacts, or medical information.
- [ ] Test camera denial, malformed codes, every credential state, safe response shape, and scan-to-lobby navigation.
- [ ] Commit: `feat: add safe public QR verification`.

### Task 5: Add lost-ID handling and minimal admin controls

**Outcome:** Students can lock their lost QR; a trusted admin can recover or replace it while every action is recorded safely.

- [ ] Add student “Report lost ID” and replacement-request screens with confirmed lifecycle states.
- [ ] Add an emulator-fixture admin role that cannot be assigned from the client.
- [ ] Add minimal admin lookup, lock, recover/reactivate, and replacement-approval screens.
- [ ] Perform all lifecycle changes in trusted Cloud Functions; direct client reads/writes to credentials, roles, and audit events stay denied.
- [ ] Record sanitized audit events: actor, action, target reference, timestamp, and no token/phone/medical data.
- [ ] Test role checks, duplicate actions, lifecycle transitions, audit writes, and Firestore Rules denials.
- [ ] Commit: `feat: add audited QR recovery controls`.

### Task 6: Close Tier 1 safely

**Outcome:** The app has an honest Tier 2 boundary, an honest unavailable protected-contact feature, and complete pilot evidence.

- [ ] Implement the Tier 2 / Emergency Medical Alert boundary using the restricted mockup treatment. It may link to public help only.
- [ ] Implement a protected-contact provider interface with an explicit unavailable state; do not use `tel:` for private contacts and do not integrate a provider.
- [ ] Confirm no Tier 2 data, biometrics, or mock profile data is present in the app, public responses, logs, or tests.
- [ ] Run Flutter analysis/tests, Functions tests, Firestore Rules tests, emulator checks, and Android debug build.
- [ ] Write a short acceptance record with PASS/FAIL/BLOCKED evidence. Device validation remains blocked until an Android device/emulator is available.
- [ ] Commit: `test: complete Tier 1 pilot acceptance`.

## What is still needed before each milestone can be called operational

| Needed from you / project owner | Needed before | Why |
| --- | --- | --- |
| Named content reviewer, content source, locale, and review date for each first-aid/DRRM item | Milestone 2 | Draft emergency-health content must not be presented as medically approved. Confirm the duplicated electrical-injury section and the emergency number wording. |
| Public hotline list: label, number, region, source, owner, and review date | Milestone 2 | The app must not guess or publish unverified emergency numbers. |
| Exact nonmedical enrollment fields, guardian-consent text, who approves it, and data-retention rule | Milestone 3 | Defines the safe profile contract without importing Tier 2 data. |
| Admin bootstrap method and the synthetic administrator account/role list | Milestone 5 | Client-side role creation is prohibited. |
| QR URL/domain, expiry period, print/share rule, and replacement approval rule | Milestones 3-5 | Determines credential format and lifecycle behavior. |
| A future protected-contact provider, consent, privacy, cost, and abuse policy | Not needed for Tier 1 completion | Without this, the feature stays visibly unavailable; no private calls are simulated. |

## Working rhythm

Implement one milestone at a time in this existing local repository. Each milestone follows the same short loop: add focused failing tests, implement the smallest complete slice, run its focused checks, commit only its files, then continue. Do not push, merge, deploy, or change remote Firebase/Vercel settings.

## Completion definition

Tier 1 is complete when a synthetic user and public responder can use all Tier 1 routes end-to-end in emulators; QR operations and admin actions are server-authorized and audited; public/offline guidance is approved and available; and Tier 2 remains inaccessible and data-free.
