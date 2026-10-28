# ResQMe Tier 1 Product and Flow Design

## Intent

Build the complete Android-first Tier 1 experience for a QR-based student
emergency support pilot, using only synthetic data and local Firebase
emulators. The UI follows the supplied mockups in `docs/mockups`, while the
user-approved scope and safety rules take precedence where they conflict.

Tier 1 provides public emergency help, safe QR status resolution, student QR
credential management, and minimal administrative control. Tier 2 medical
information is not implemented, stored, fetched, or displayed.

## Goals

- Preserve the supplied visual system: ResQMe red emergency header, dark
  navy urgent panels, rounded white cards, large action controls, and
  accessible contrast and text scaling.
- Make public help available without student sign-in: scan a QR, read
  reviewed first-aid/DRRM guidance offline, and view approved hotlines.
- Let an enrolled synthetic student view, print, lock, and replace an opaque,
  server-issued QR credential.
- Require trusted backend authorization, Firestore Rules, audit events, and
  emulator tests for all credential and admin actions.
- Keep medical data, private emergency-contact numbers, raw QR tokens, and
  real student records out of public responses, QR payloads, and logs.

## Non-goals

- Screens 09-14 from the supplied mockups: biometric verification and all
  medical, allergy, medication, and health-history views.
- A real telephony relay, until the provider, consent, billing, abuse, and
  privacy decisions are expressly approved.
- Production Firebase access, deployment, billing changes, real records, or
  unreviewed medical/DRRM/hotline content.
- Treating a `tel:` link as masked calling; it is allowed only for approved
  public hotline numbers.

## Visual reference map

| Mockup | Tier 1 use |
| --- | --- |
| 01 | Splash visual treatment |
| 02 | Terms & Privacy layout, with Tier 1-safe copy |
| 03 | Public QR scanner and camera-permission state |
| 04 | Tier 1 home dashboard and visual system |
| 05 | First-aid library and guide detail |
| 06 | Public emergency hotline directory |
| 07 | DRRM hazard library |
| 08 | DRRM emergency action-plan sheet |
| 09-14 | Explicitly excluded Tier 2 references; only a nonfunctional access boundary may borrow the restricted-access presentation |

Mockup 04's Tier 2 tile becomes a boundary sheet stating that protected
medical information is outside Tier 1. It never starts biometrics or loads a
profile. Mockup 02's Tier 2 wording is replaced with Tier 1 consent wording.

## Chosen navigation model

The approved public-first flow is:

```text
Splash -> Terms & Privacy -> Tier 1 Home
                              |- Scan QR -> camera permission -> scanner
                              |             -> safe public result / invalid / locked / offline
                              |- First Aid -> library -> guide detail
                              |- Emergency Hotlines -> approved directory -> public dialer
                              |- DRRM -> hazard library -> action-plan sheet
                              |- Tier 2 information -> restricted-access boundary only
                              `- Profile -> signed-out entry / enrolled student tools

Student tools -> enrollment -> My QR -> print/share rendering
                                      -> report lost ID -> lock -> replacement
Admin tools   -> authenticated admin QR lookup -> status/lock/replacement actions
```

Terms are accepted before normal app navigation. The public QR scanner remains
reachable from the Home dashboard without student enrollment or sign-in.
The first implementation of every public route includes back navigation and
safe loading, offline, permission-denied, invalid, and error states where
applicable.

## Approaches considered

1. **Public-first dashboard with scanner as a prominent action - chosen.** It
   matches the emergency-support objective, retains the mockup's Home visual
   hierarchy, and avoids making QR scanning mandatory for public guidance.
2. **Scanner-first onboarding.** It follows the mockup page numbering but
   incorrectly makes scanning a prerequisite for first aid, hotline, and DRRM
   help.
3. **Student-first QR dashboard.** It helps credential owners but weakens the
   public responder path and does not fit the supplied Tier 1 service cards.

## Feature slices and trust boundaries

### Public support

First aid and DRRM content is bundled, versioned, and usable offline. It is
limited to approved general guidance and prominently directs life-threatening
cases to approved emergency services. The hotline directory is static,
approved content with source, reviewer, locale, version, and review date.
Public calls may open the platform dialer only for those public numbers.

### QR scanning and safe resolution

The scanner accepts only the expected ResQMe HTTPS credential format. A QR
contains one opaque, server-issued credential token, never student or medical
data. The client submits it to a rate-limited callable resolver. The resolver
checks the credential digest and status and opens the Tier 1 Home Lobby with
a neutral verified-ID status only. It does not return a student name, school,
identifier, contact, or medical detail. Malformed, expired, revoked, locked,
unknown, and offline cases fail closed while preserving public-help navigation.

### Student enrollment and My QR

Firebase Authentication identifies the self-registering synthetic student.
Enrollment collects approved Tier 1 identity and parent/guardian-consent
fields, then holds the profile pending trusted approval before issuing a
credential. Guardian consent is enrollment authorization, not a second factor
and never enables Tier 2. My QR renders the returned opaque HTTPS URL for
display and print. A student can report a lost ID, which locks the active
credential; a replacement invalidates the prior credential atomically. The UI
never claims success until the server confirms the state transition.

### Admin QR management

An administrator's role is provisioned only by trusted infrastructure; a
client cannot set its own role. The minimal admin view supports QR lookup and
authorized lock, recovery/reactivation, and replacement decisions. Every
privileged operation checks role and tenant/school scope in Cloud Functions
and writes a sanitized audit event. Account deletion is not a recovery path;
deactivation preserves audit history and allows an authorized recovery after
the issue is resolved. Direct client access to credentials, contacts, roles,
and audit records is denied by Firestore Rules.

### Protected emergency-contact calling

Tier 1 exposes an interface and a clearly unavailable state only. It does not
use `tel:` for a private emergency contact. A real relay is deferred until an
approved provider and policy exist; its implementation is a later, separately
approved slice.

### Emergency Medical Alert boundary

The Tier 2 tile and any emergency-alert entry use the mockup's restricted
sheet styling to explain the boundary. The sheet can offer public guidance and
hotlines but must not authenticate biometrics, call a medical endpoint, or
load any medical data.

## Architecture

Keep Flutter's built-in Navigator and the existing feature-first structure.
Add narrow repositories/services only for a feature that needs persistence or
a backend call. Use Firebase Auth, Firestore, and callable Functions only
through emulator-aware services in debug builds. Cloud Functions in TypeScript
own authorization, credential issuance/resolution, lifecycle mutations,
sanitized audit writing, and future provider integration. Firestore Rules
remain deny-by-default and allow only narrowly defined own-profile and
published-content reads after the associated contracts and tests exist.

Suggested feature folders are `public_support`, `qr`, `student`, `admin`, and
`medical_boundary`; shared DTOs remain nonmedical and avoid raw tokens in
diagnostics. No state-management or routing framework is introduced unless a
concrete flow proves the existing approach inadequate.

## Data and authorization model

- `publicContent`: reviewed, versioned, nonmedical first-aid, DRRM, and public
  hotline entries; only published entries are readable.
- `students`: synthetic Tier 1 profile and enrollment status; owners can read
  only their safe profile fields; all sensitive mutations use Functions.
- `qrCredentials`: credential digest, owner reference, status, issue/expiry
  timestamps, and replacement linkage; never client-readable.
- `auditEvents`: actor, action, target reference, timestamp, and safe metadata;
  never client-readable.
- `emergencyContacts`: server-only and excluded until a protected relay is
  approved.

All Functions validate authentication, role, request shape, credential state,
and tenant/school ownership. They do not log raw credential tokens, phone
numbers, or medical information.

## Delivery order

1. Apply the approved mockup design to the existing splash, Terms, and public
   Tier 1 Home, then make the four existing public cards navigable.
2. Add reviewed bundled first-aid, hotline, and DRRM content with offline,
   accessibility, and error-state tests. Calling remains public-hotline only.
3. Add authenticated synthetic enrollment, server-issued QR generation,
   display, verification, and print rendering with emulator-backed Functions
   and Rules tests.
4. Add lost-ID locking/replacement and minimal admin QR management with
   transactional lifecycle checks and audit tests.
5. Add the explicit Tier 2 / Emergency Medical Alert boundary and the
   protected-contact provider interface with no real relay.
6. Run the integrated Tier 1 security, accessibility, emulator, Android, and
   regression validation. Do not declare any blocked external service live.

Each slice is committed before the next one. Work occurs in this one local
project directory on standard branches only; no worktrees, duplicate clones,
automatic branch deletion, push, merge, or deployment are permitted.

## External gates

The following must be approved before their associated functionality is
presented as operational: reviewed first-aid and DRRM content; hotline
directory ownership, locale, source, and review date; student identity and
consent policy; trusted admin bootstrap; QR domain/print policy; and any
private-call provider. Until then, use fixtures and honest unavailable states.

## Acceptance criteria

- Public users can reach scan, first aid, hotlines, and DRRM from the mockup-
  aligned Tier 1 Home without Tier 2 access.
- All QR creation, resolution, lifecycle, and admin mutations are authorized
  server-side, auditable, test-covered, and emulator-only in development.
- QR/public responses/logs contain no medical data, private contacts, or raw
  credential tokens.
- Invalid, locked, expired, unknown, and offline QR states fail closed but
  preserve public help.
- The Tier 2 boundary never fetches, displays, or simulates medical data.
- Flutter analysis/tests, Functions tests, Firestore Rules tests, emulator
  checks, and Android debug validation pass for each applicable slice.
