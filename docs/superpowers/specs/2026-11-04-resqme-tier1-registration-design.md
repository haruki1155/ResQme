# ResQMe Tier 1 — Student Registration and Privacy Acknowledgment

**Design status:** Approved by project owner on 2026-11-05 for synthetic-data Tier 1 development; school privacy-officer review is still required before processing real student data  
**Date:** 2026-11-04  
**Platform:** Existing Flutter Android app (phones and tablets), Firebase staging  
**Milestone:** Registration foundation only — **not** clinic import, approval workflow, QR issuance, or Tier 2

## 1. Intent and decisions

Finish a small, understandable Tier 1 student-registration foundation now, without waiting for the school roster's Excel/PDF format or complete school/guardian-verification requirements. Registration fields and their storage are designed to evolve without modifying Firebase Auth accounts or medical-data structures.

Confirmed by the project owner:

- Students include **minors and adults**.
- The registration form must contain **Personal Information** and **Emergency Contact Information** from the supplied BASIC-PROFILE sample, excluding system-managed fields.
- Do **not** ask for Student ID, `studentIdClaimed`, or LRN during registration. LRN is an **optional, initially blank backend attribute** that may be supplied later by the school's Excel import after trusted identity matching.
- Academic, Medical, Physician, and Tier 2 Security/Access sections from the sample are excluded from this registration screen.
- A clear privacy acknowledgment dialog, including an initially unchecked checkbox and a description of processing, is required before submission.
- A student's privacy checkbox **is not** parent/guardian authorization.
- Email verification, guardian authorization verification, school review decisions, and account matching to the future roster are **deferred** until actual school requirements become available.
- A future bulk school-data import is expected to prepare student records automatically; it does not belong to this milestone.
- Flutter on Android phones and tablets remains the app platform. No new web portal is required.

### Approaches considered

| Approach | Trade-off | Decision |
|---|---|---|
| Implement email, guardian and school verification now | Complete workflow but assumptions about school requirements and guardian identity would be unreliable | Rejected for this milestone |
| Use a pretend or self-attested guardian approval checkbox | Easy UI but incorrectly signals that guardian authorization occurred | Rejected; unsafe |
| **Accept registration with explicitly pending review/consent states; defer verification engines** | Fast, testable foundation while sensitive features remain unavailable | **Chosen for this design** |

## 2. Scope

### In scope

1. Student sign-in, create-account and basic profile registration screens, matching the existing ResQMe visual theme.
2. Required-field validation and password confirmation.
3. A privacy/registration acknowledgment dialog with clear data-use disclosure and a link to the full notice.
4. Firebase email/password authentication **without an email-verification step yet**.
5. A server-controlled, minimal student profile and durable record of the student's acknowledgment.
6. A pending-registration screen and controlled navigation for signed-in but unapproved users.
7. Clear loading, duplicate email, invalid form, offline, failed submission, and retry states.
8. Emulator rules and tests proving that unapproved users cannot make themselves approved or access sensitive operations.

### Explicitly out of scope

- Excel/PDF import, OCR, field mapping, roster matching, and clinic staff import UI.
- Sending email verification, guardian email invitations, signed forms, guardian identity checks, or school-admin approval.
- Automatic Firebase Auth user creation from imported school records.
- QR creation, replacement, unlocking, ownership assignment, or access to Tier 2 information.
- Medical conditions, allergies, blood type, medication, medical history, physician information, biometrics, or fingerprints. **Basic emergency-contact details are now in scope**, subject to the privacy rules below.
- User-entered Student ID, LRN, grade/strand/section, or school-selection controls.
- Nurse UI, master-admin creation, mobile/web admin workflows, and production deployment.

## 3. Screens and user experience

### Student entry point

- Existing public emergency dashboard remains accessible without signing in.
- **Student Account** opens **Sign in**, with **Create account** and **Forgot password** actions.
- Forgot password uses the established email/password recovery capability when enabled; it is **not** a verification or account-approval substitute.

### Registration form (one scrollable mobile screen)

| Field | Required | Validation and purpose |
|---|---|---|
| Full name | Yes | Trim whitespace; 2–120 characters; use name as entered, do not force separate first/middle/last names |
| Age (years) | Yes | Self-declared whole-number age; the backend derives whether the registration is under 18; not verified identity evidence |
| Gender | Optional | Simple list with **Prefer not to say**; avoid inferring medical information or access rights |
| Personal contact number | Optional | Validate format without forcing country-specific visual formatting; restricted private data |
| Parent/guardian full name | Optional now | Contact information only; not proof of legal guardianship or consent |
| Relationship | Optional now | Parent, guardian, or Other; does not establish authorization |
| Parent/guardian contact number | Optional now | Private emergency-contact number; no contact or authorization messages sent in this milestone |
| Secondary emergency-contact name | Optional | If entered, validate as a name; do not demand a second contact |
| Secondary emergency-contact number | Optional | If either secondary name/number is supplied, ask for the matching field before saving |
| Email | Yes | Login and recovery email; not considered verified in this milestone |
| Password | Yes | Propose minimum 8 characters; never store in profile data |
| Confirm password | Yes | Must match; never persist separately |

**Form layout:** One vertically scrollable phone screen with clear **Personal information**, **Emergency contacts (optional)**, and **Account credentials** groups. Emergency-contact inputs may be in an expandable section on narrow phones, but remain reachable on the registration screen. Tablets may show groups in two columns while preserving one logical form and submit action.

**Not registration inputs:** LRN, Student ID, School/grade/strand/section, Account Type, Access Level, Account Status, and Tier 2 settings. These are absent, deferred, or server-managed. The pilot `schoolId` is assigned from trusted app/backend configuration, not a student text field.

**Future LRN:** `lrn` remains optional/null, with no registration input, validation, or client write. A later reviewed Excel import may fill it after securely linking a roster record to an account. Do not match or overwrite using a name or telephone number alone.

Fields are defined in a versioned profile model (`schemaVersion: 1`) and optional fields are read defensively. Emergency-contact information is private and must not appear in public QR results.

### Privacy acknowledgment dialog

Open when the student taps **Create account**, **before** a Firebase Auth account or profile is created. The checkbox defaults to unchecked on every new attempt.

**Title:** Data Privacy & Registration Authorization

**Body:**

> To create your ResQMe student account, we will process your full name, age and email address. You may also provide your gender, personal contact number, and parent/guardian or secondary emergency-contact details. These details will be stored in your private basic profile for registration and future authorized school enrollment and emergency-contact procedures. Your password is handled by our authentication service and is not stored in your student profile. Contact numbers and registration details are not displayed in public QR results. No medical information is collected or made available by this acknowledgment.

**Checkbox:**

> I have read and understood the ResQMe Privacy Notice and agree to the processing of my registration information for the purposes described above.

Actions: **Review Privacy Notice**, **Decline**, **Agree & Create Account** (disabled until checked). The notice must be available in full; show the active `noticeVersion`. Decline cancels submission without creating an account. A checkbox click alone never records guardian approval.

For a student whose self-reported age is **under 18**, show a separate explanatory line:

> Your enrollment will remain pending until the school confirms the required parent or guardian authorization. This checkbox does not provide that authorization.

This UI text is a design draft requiring review by the participating school's privacy officer before any real student data is used. A suitable processing basis and guardian-authorization requirements must be confirmed rather than inferred from this checkbox alone.

### Confirmation / pending screen

- **Adults:** "Registration received — pending school review." Explain that registration does not yet confirm student status.
- **Minors:** "Registration received — guardian authorization pending." Explain that guardian verification and school review are not active in this milestone.
- Show **Return to public dashboard**, **View registration status**, and **Sign out**.
- Do **not** offer **My QR**, Tier 2, or an enabled **Approve** button.
- A signed-in pending user may revisit their own nonmedical submission and sign out; public emergency resources still work.

## 4. Functional flow and state boundaries

1. The user opens Create account and enters minimal information.
2. Client validation catches ordinary mistakes, and the submission opens the privacy dialog.
3. Only a checked acknowledgment followed by the final confirmation proceeds to Firebase Auth email/password creation.
4. A protected registration operation records the profile, immutable acknowledgment metadata, and an initial **pending** state.
5. The user sees the appropriate pending screen. No email ownership, school affiliation, guardian relationship, or roster match is represented as verified.
6. On later sign-ins, the application reads the server-controlled profile state and routes pending users to the status screen.

**Current server states:**

| State | Meaning | Who may set it now |
|---|---|---|
| `pending_review` | Adult applicant's identity/school registration not verified | Registration backend only |
| `pending_guardian` | Minor's guardian enrollment authorization not verified | Registration backend only |
| `approved` | Reserved for future verified school workflow | **Nobody in this milestone** |
| `rejected`, `deactivated` | Reserved for future account management | **Nobody in this milestone** |

`draft` is local, unsaved form state, not an approved server identity. A future workflow may introduce more internal states without granting access to existing pending accounts. The backend derives the pending state from the **self-reported age at registration**; the entered age is not verified, and incorrect age declarations must never enable QR or restricted access.

**Fail-closed rule:** Registration status and account sign-in are not proof of school enrollment. Pending accounts can use public features and view their own registration status only. QR eligibility, school-level reads, guardian verification flags, and restricted functionality remain disabled.

## 5. Proposed minimal data model

Use Firebase Auth for login credentials and an independent Firestore document for nonmedical profile attributes. Path names are provisional and should be aligned to the existing repository during the later implementation plan.

```json
studentProfiles/{uid}: {
  "schemaVersion": 1,
  "fullName": "Synthetic Student",
  "schoolId": "pilot-school-id",
  "emailNormalized": "synthetic@example.test",
  "ageYearsAtRegistration": 17,
  "ageCategoryAtRegistration": "under18 | adult",
  "gender": null,
  "personalContactNumber": null,
  "emergencyContacts": {
    "primary": {
      "fullName": null,
      "relationship": null,
      "phoneNumber": null
    },
    "secondary": {
      "fullName": null,
      "phoneNumber": null
    }
  },
  "lrn": null,
  "status": "pending_guardian | pending_review",
  "createdAt": "server timestamp",
  "updatedAt": "server timestamp"
}

studentProfiles/{uid}/acknowledgments/{recordId}: {
  "type": "tier1_registration_privacy",
  "noticeVersion": "tier1-registration-v1",
  "affirmativeAction": true,
  "recordedAt": "server timestamp",
  "actorUid": "auth UID"
}
```

- Firebase Auth owns UID, password hash and the email authentication state. **Never** write a password or confirmation password to Firestore, logs, analytics, or crash reports.
- The student may read only their own profile and acknowledgment. The student cannot set `status`, `lrn`, guardian verification flags, `schoolId`, or change an acknowledgment record. Contact information is visible only to the account owner and future specifically authorized school personnel under a reviewed access policy; it is never public.
- Server trust boundary: a callable/controlled backend should create the initial profile with server timestamps and pending state. Firebase Auth creation and profile creation are not atomic; implement idempotent reconciliation by UID and a restricted incomplete-profile state if either step fails. Never route a missing-profile account to approved features.
- Use a configured pilot `schoolId`, not a free-text string that grants tenant permissions.
- The privacy record is evidence that this account clicked the acknowledgment, **not** proof of guardian identity or lawful guardian authorization. Listing a guardian and phone number is also **not** guardian approval.
- No public unauthenticated read of this document or the student's email, age, gender, LRN, or contact numbers. If the school has not reviewed a lawful purpose and retention for emergency-contact data, run only with **synthetic** profiles.

## 6. Future bulk-import boundary (not implemented now)

The project owner expects the school's whole-student Excel/PDF dataset to be uploaded later. The safe meaning of "automatically register" at that stage is **pre-provision a separate, unclaimed school-roster record**, not silently create a functioning email/password login for each imported row.

- Imported records remain in a restricted `schoolRoster`/equivalent collection, distinct from `studentProfiles/{uid}` and Firebase Auth.
- A future verified account-claim workflow will link a human-created Auth account to the correct roster record only after school-defined checks succeed.
- Only **after** that verified match, an authorized backend can fill the initially blank `lrn` field and any other specifically approved nonmedical profile fields. Never overwrite student-supplied nonblank data silently; handle conflicts explicitly.
- An unverified email string, checkbox, contact number, name match, or unclaimed LRN is insufficient to claim records or mint QR credentials.
- Academic information stays outside the initial registration form; future **medical** and physician information must remain in separately authorized Tier 2 data stores, never copied into the public Tier 1 profile.
- No automatic `approved` status or QR from an import; approval authority will be specified later.
- Future form/roster label mapping, duplicates, correction workflows, imports, retention and recovery policies remain a separate design milestone.

If the school later expressly requires backend-created login accounts, that is a distinct security design needing an approved delivery and account-claim method before implementation.

## 7. Errors, privacy and security

| Condition | Expected behavior |
|---|---|
| Invalid/empty field or password mismatch | Inline error, preserve safe entries; password not logged |
| Malformed personal/guardian phone number | Field-level correction; do not confuse a provided phone number with guardian authorization |
| User declines notice | Close dialog, retain form in memory only; create no account |
| Email already registered | Generic actionable sign-in/reset option; do not reveal other profile data |
| No network | Show retry; do not claim account creation succeeded |
| Auth succeeded but profile creation failed | Keep account restricted, show recovery/retry; backend idempotently reconciles without elevating status |
| Repeated submit/taps | Disable during request, backend idempotent by UID; no duplicate profile or acknowledgment on retry |
| Missing or malformed server profile | Public functionality only; safe error, no privilege escalation |
| Under-18 registration | Record `pending_guardian`, do not capture or assert guardian permission |
| Imported LRN is not yet linked | Leave `lrn` null; never suggest that an email/name/phone match is sufficient to attach another student's school data |

Secure the full feature with Firestore Rules and server-side authorization, not hidden UI alone. Test with synthetic records only until the school's privacy/retention policy and approval process have been reviewed. Existing public-first-aid/hotline/DRRM behavior must remain available offline where already supported.

## 8. Acceptance checks for the later implementation plan

1. Student can open the form on a phone and tablet; smaller screens scroll and the keyboard does not cover the action buttons.
2. Required name, age, email, and password fields validate; optional gender, personal number and emergency contacts can be completed. No Student ID or LRN input is shown. The schema remains extendable without auth migration.
3. Consent checkbox is initially unchecked; declining creates no account; continuing creates exactly one versioned acknowledgment.
4. Adult registration records `pending_review`; minor registration records `pending_guardian`; neither receives `approved` or QR access.
5. Firebase email/password sign-in works for a pending account without claiming email verification has occurred.
6. Pending users can read their own private basic profile and contact information but cannot read any other student's emergency contacts or a roster/clinic record.
7. Client tampering cannot set `approved`, inject guardian approval, access admin routes, or mint a QR; emulator rules tests cover these cases.
8. Offline, duplicate email, partial failure, and retry behavior are tested; failed submissions never look approved.
9. Existing anonymous emergency dashboard and resources continue functioning.
10. A future import cannot assign an LRN or merge student data into an unverified account without a separately approved secure matching workflow.

## 9. Open inputs and boundaries before real-data rollout

- School/clinic confirmation of tenant identifier, imported LRN format, roster mapping, and records retention. No student identifier is collected at registration.
- School/privacy-officer review of why emergency-contact names and numbers are collected, who may use them, how corrections/deletion work, and when they are removed.
- Legal/privacy review of the complete notice and the appropriate basis for processing minors' data before live enrollment.
- Requirements for guardian authorization evidence, school verification, roster linking, account recovery and approval authority.
- Decision whether future imported data creates only unclaimed records (**recommended**) or requires a separately secured account-provisioning process.
- Approved format and retention period for eventual real and synthetic data.

These deferred inputs **do not block designing or implementing the limited registration UI and pending-state security boundary with synthetic test accounts**. They **do** block claiming verified enrollment, automatically approving QR, or processing real minors without school review.

## 10. Next step

**Owner-approved design for synthetic-data implementation.** Follow the separate Superpowers implementation plan with test-first tasks, staged validation, and no release/deployment without explicit permission. The old clinic-import design remains paused. Approval of this design is not school privacy-officer clearance for real student data.
