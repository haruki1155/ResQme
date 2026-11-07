# ResQMe — Hosted Staging Onboarding, Synthetic Medical Record, and Unverified QR

**Design status:** **Approved by the project owner on 2026-11-06** for synthetic-only implementation planning. The approval does not authorize processing real medical data or deploying to hosted Firebase without a separate go/no-go.

**Date:** 2026-11-06  
**Platform:** Existing Flutter Android app (phones and tablets); Firebase project `resqme-943ee` in its debug/staging configuration.  
**Related approved baseline:** `docs/superpowers/specs/2026-11-04-resqme-tier1-registration-design.md` and the already committed registration Tasks 1–6, including Task 2.5.  
**Goal:** Demonstrate a working hosted-staging onboarding experience without waiting for school roster, guardian verification, QR verification, or Tier 2 role implementation.

## 1. Decision and proposed approach

The owner wants an operational flow: **Register → Optional medical-information step → Unverified QR → Dashboard**. Login/logout/reset and persistent state must work through hosted staging, with public emergency resources remaining accessible as a guest.

| Approach | Trade-off | Decision |
|---|---|---|
| Keep medical entry deferred, QR later | Smallest change, but does not demonstrate the owner's requested flow | Not selected |
| **Store private synthetic medical entries in staging; issue an unverified QR** | Functional end-to-end demonstration, with explicit restrictions on data, access and QR meaning | **Selected and owner-approved for planning** |
| Accept real minor/adult medical information immediately | Requires an approved lawful basis, privacy/retention controls and appropriately verified authorization; beyond current scope | Not authorized |

This is an **additive change** to the older registration spec. It changes the earlier “no QR for pending accounts” rule **only for a non-authorizing, unverified Tier 1 account QR**. All other rules against verified-student claims, Tier 2 access, medical disclosure and self-approval remain in force.

## 2. User journey and navigation

1. Anyone may open **Splash → Terms/Privacy → Public Emergency Dashboard** with **no account**. Public first aid, hotlines and DRRM remain accessible. QR never unlocks these existing public features.
2. **Student Account → Register:** use existing basic personal fields, account credentials, validators and approved `tier1-registration-v1` acknowledgment. Firebase Auth creates login; the existing trusted callable creates a pending profile. Under 18 → `pending_guardian`; 18+ → `pending_review`. Neither state represents school/guardian verification.
3. **Medical Information (Optional):** a clearly labeled *synthetic test mode* screen offers **Complete now** and **Skip for now**. It does not block registration or the public dashboard.
4. **If completed:** user chooses known/none-known/unknown status for conditions and allergies and optionally supplies details and a private emergency contact. User reads a synthetic-use and accuracy disclaimer, checks the required acknowledgment(s), then saves through an authenticated, trusted backend operation. The medical record remains **self-reported, synthetic, unverified and private**.
5. **QR display:** a trusted idempotent backend operation issues one opaque **Unverified Tier 1** QR to the signed-in pending account. The app displays the QR and its unverified label, then offers **Go to Dashboard**. A previously issued QR is reused across retries and later sign-ins.
6. **Signed-in Dashboard:** a dismissible **Finish Medical Record** card/dialog appears only if that account has not saved the optional test record. Tapping it opens the same screen. Skipping or dismissing does not restrict Tier 1 access. A saved record changes the action to **View/Update Medical Record**.
7. **Subsequent login:** Auth session and server state restore pending account, unverified QR, and medical reminder/completion. Sign-out returns to public access. Failed reads never imply verified identity or medical completion.

### Important flow independence

- Medical data and medical acknowledgment **are not prerequisites** for account creation, QR issuance, or anonymous public features.
- A QR is **not** an authentication token. Possession of the QR does not sign the holder in, claim enrollment, or authorize private data access.
- After a partial registration failure, recover the existing Auth account/profile using the prior safe retry path; never create duplicate accounts or QRs.
- The public QR scanner, verification results, lock/replacement workflow and admin management remain **separate future milestones**.

## 3. Medical screen: exact pilot contract

| Input / state | Required? | Behavior |
|---|---|---|
| Medical condition status | User chooses `unknown`, `none_known` or `listed` when saving | Blank is not silently interpreted as “no condition”; details editable only for `listed` |
| Medical conditions details | Required only when `listed` is chosen | Trim and bound length; no file attachments or diagnoses inferred by the app |
| Allergy status | User chooses `unknown`, `none_known` or `listed` when saving | Avoid treating “not entered” as “no known allergies” |
| Allergy details | Required only when `listed` is chosen | Trim and bound length; no clinical verification claim |
| Emergency contact name, relationship, phone | Optional | Prefer the *existing private emergency-contact fields* as the canonical copy. Prefill and update through one authorized path; do not create competing duplicates in QR/public documents |
| Test-data acknowledgment | **Required to save** | Confirms that the entry is fictional demonstration data; never treat as legal authorization |
| Minor-specific acknowledgment | **Required to save synthetic data under 18** | Clearly states that guardian authorization is **not verified** and real minors' health data must not be entered |
| Guardian verification email | **Not operational** | Do not send email, collect unneeded address, or suggest success. If a placeholder is shown, disable it and label “Coming later.” |

**Definition of completion:** `completed_synthetic` means the tester deliberately submitted the status selections and acknowledgment. It **does not** mean a clinician validated any condition, a guardian consented, or the record is usable in an emergency.

**Suggested screen notice — must be reviewed as UI copy:**

> **TEST MODE — Synthetic information only.** This version of ResQMe saves fictional medical information to our staging database for testing. Do not enter any real person's conditions, allergies, name, or phone number. In a future real-use version, you must enter only conditions and allergies you actually know you have and keep the information accurate. Entries in this pilot are self-reported, have not been checked by a health professional, and are not sent to the clinic or emergency responders. You can skip this step and return later.

Required tester checkbox:

> I confirm that the information I am submitting is fictional test data, not a real person's medical information.

Additional under-18 checkbox:

> I understand that guardian authorization is not verified in this pilot. Checking this box does not provide or establish my parent or guardian's consent for real medical-data processing.

**Do not** label either checkbox `guardianConsentGranted`, `guardianVerified`, or a completed parental authorization. If staging needs an audit marker, store a versioned `synthetic-medical-v1` acknowledgment, actor UID and server timestamp, with separate `guardianAuthorizationStatus: not_verified` controlled by the server.

## 4. Dashboard reminder behavior

- For a **signed-in** user with `medicalStatus: not_started` or `incomplete`, show a non-blocking **Finish Medical Record** card, optionally with a dismissible first-session dialog. Provide **Finish now** and **Later**.
- Do not interrupt guest users, the QR scanner, first aid, hotline calling, or other emergency actions with reminders.
- Avoid a popup on every route rebuild. A dismissed reminder can be snoozed locally for the session; no medical details belong in reminder logs or notifications.
- When the private save is acknowledged by the backend, stop showing the incomplete reminder and offer a way to **View/Update** or clear the synthetic entry.
- On offline/unknown backend status, show a neutral retry path; do not claim either completed or missing medical data without a trusted result.

## 5. Trusted backend and data boundary

The executing agent must inspect the actual registration schema, Firestore Rules, Functions runtime and repository first. Suggested logical records (adapt names to the repository):

| Record | Trusted writes | Reads | Contents |
|---|---|---|---|
| `studentProfiles/{uid}` | Existing registration callable; a narrow trusted contact-update path | Owner only | Pending status, basic registration and canonical private emergency contacts; no medical conditions |
| `studentMedicalRecords/{uid}` | New authenticated `saveMySyntheticMedicalRecord` callable | Owner only (or via owner-authenticated read callable) | Versioned condition/allergy status/details, `syntheticOnly:true`, `completed_synthetic`, server timestamps; no Tier 2 staff exposure |
| `studentMedicalRecords/{uid}/acknowledgments/{version}` or equivalent | Trusted callable only | Owner only | `synthetic-medical-v1`, checkbox event, actor UID, server timestamp; guardian authorization remains not verified |
| `studentQrCredentials/{uid}` (logical) | Trusted `ensureMyTier1Qr` callable only | Owner-authenticated path only | Opaque random QR reference, `verificationStatus:unverified`, server timestamp, no personal/medical fields |

**Medical save contract:** derive UID from Firebase Auth, validate allowed fields and lengths server-side, reject unknown client-controlled status/role/guardianVerified/UID/LRN fields, use a bounded idempotent/update-safe operation, and do not write sensitive content to logs/analytics/crash reports. If emergency contacts are updated, update the existing canonical private contact data in one properly authorized operation; do not silently overwrite a concurrent change.

**QR contract:** require an authenticated account with a server-created pending profile; mint a cryptographically unpredictable, versioned opaque reference once, transactionally/idempotently; return the same reference on repeated requests and sign-ins. Never place UID, name, LRN, email, allergies, medical conditions or contact numbers in the QR payload. Do not make the QR a bearer authorization token. The initial screen clearly says **UNVERIFIED — not proof of school enrollment**. Public verification and a real URL/domain policy are deferred.

**Firestore/Function security:** direct client writes to status, QR ownership, and medical acknowledgments remain denied; owner-only private reads; unauthenticated/cross-user reads denied. Remember Admin SDK calls bypass Firestore client Rules, so trusted callables must authenticate and authorize explicitly. Documented reference: https://firebase.google.com/docs/firestore/security/rules-conditions .

**Synthetic-only safety:** permit medical saving only in the intended staging debug/test mode and to a **trusted server-configured QA UID allowlist (or an existing equivalent test entitlement)**; the client must not grant itself tester status. The testing procedure is: register a synthetic account, have the authorized tester administrator allowlist that UID, then complete medical entry; the optional medical step can always be skipped while awaiting eligibility. If not allowlisted, show `Test record saving is not enabled for this account` without blocking QR/dashboard. Do not automatically grant a newly registered, unverified account tester status. Show clear in-app demo labeling and restrict APK distribution. Do not treat a checkbox as proof that an arbitrary user entered fictional data. Before any broader testing involving real people, the school must approve purpose, lawful basis, role access, retention/deletion, and minor guardian authorization. Philippine health information is sensitive personal information: https://privacy.gov.ph/data-privacy-act/ .

## 6. Error handling and acceptance tests

| Condition | Required behavior/test |
|---|---|
| Skip medical | Registration continues, unverified QR appears, dashboard accessible; no medical record written |
| Save synthetic medical data | Private owner-only record persists across logout/login; correct status and acknowledgment metadata |
| No checkbox / minor checkbox absent | Save blocked with understandable inline text; no medical write |
| Under 18 | `pending_guardian` unchanged; guardian authorization status remains `not_verified` despite checkbox |
| Adult | `pending_review` unchanged; no guardian-only checkbox required |
| Offline save or callable fails | Explicit retry or skip; never silently mark complete; no duplicate account or QR |
| Repeated QR requests / two sessions | Exactly one stable unverified QR, no mutation of enrollment status |
| Anonymous or another UID | Cannot read/write medical records, contacts, acknowledgments or QR ownership |
| Malicious payload | Client-provided `approved`, `guardianVerified`, `role`, `uid`, `lrn` cannot elevate privileges or change ownership |
| Guest dashboard | Public first aid, hotlines and DRRM remain accessible without registration or medical fields |
| QR scan by unrelated party | Not an identity or authorization grant; no private/public medical response introduced |
| Restart / sign out | Medical reminder and QR reflect trusted per-account state without leaking to guest |

Minimum validation: Flutter validator/widget/repository/access-gate tests; Functions unit and callable integration tests; Firestore Emulator Rules denial/owner tests; `flutter analyze`, `flutter test`, Functions build/tests, debug APK, and synthetic Android phone/tablet staging smoke checks. An unavailable device is **pending**, never a passing test.

## 7. Limits, deployment and deferred decisions

- **Not in this milestone:** real personal/medical records, QR public verification, verified-student claims, medical responder access, school approval, real guardian/email verification, nurse/master-admin UI, roster import, QR locking/replacement/expiry, or Tier 2 permissions.
- **Staging only:** `resqme-943ee`. Inspect the current debug-only Firebase initialization; use explicit project selection and never silently fall back from emulator to hosted resources. No release/production initialization changes.
- **No real-data rollout:** tester-provided real data is not authorized merely because Firebase can store it. School/privacy-officer clearance and a reviewable retention/deletion process are prerequisites for processing real records.
- **Before hosted deploy:** verify prior backend metadata omissions and reported concurrent-session mutation race, run focused tests, list exact affected Functions/Rules and request a deployment go/no-go. Keep user edits, `docs/mockups/`, commits and unrelated Firebase resources untouched.
- **Implementation next step:** follow the separate Superpowers implementation plan with test-first tasks and scoped commits in the existing checkout (no extra worktrees unless explicitly requested). Plan review and remote staging deployment remain separate gates.

## 8. Approved owner decisions

The owner approved this synthetic-only direction on 2026-11-06, subject to the implementation and deployment boundaries above:

1. Medical entries are **fictional test data only** on hosted staging; no real students' health information.
2. Both minor and adult pending accounts may save private **synthetic** entries; minors' guardian checkbox is a demo acknowledgment, never verified consent.
3. Medical completion is optional; skipped users still receive the same unverified QR and public-dashboard access.
4. The QR is an opaque, non-authorizing identifier with no public verification or Tier 2 access yet.
5. Guardian email verification remains disabled; no success or approval is simulated.

**Implementation authority and hosted deployment are separate from this design review.**
