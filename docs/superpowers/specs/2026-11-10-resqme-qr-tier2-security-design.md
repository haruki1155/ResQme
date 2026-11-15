# ResQMe QR Tier 1 and Biometric Tier 2 Security Design

Status: Approved by owner on 2026-11-10 for local implementation; hosted rollout remains separately gated.

## Goal

Allow an active, school-approved ResQMe QR to start a Tier 1 session. Keep Tier 1 limited to public emergency resources. Require owner authentication and fresh biometric-backed authorization, or the existing account password fallback, before Tier 2 data is released.

## Current implementation

- Registration creates a pending school-review profile with no assigned school. No real school assignment or reviewer provisioning source exists, so hosted approval remains unavailable.
- `completeMyMedicalRecord` requires conditions and allergies answers, a primary emergency contact, and a self-report confirmation. It is separate from synthetic QA records.
- `approveStudentQr` and `revokeStudentQr` derive reviewer scope from a server-managed record and write an audit event. QR activation requires an approved profile and complete production medical record.
- `ensureMyTier1Qr` creates/reuses a random opaque active credential only after both gates pass. A SHA-256 lookup supports `resolveTier1Qr`, which returns only `{active}`. Replacement atomically deactivates the previous lookup.
- Tier 2 callables enroll one device key per account, issue 60-second single-use challenges, verify signatures, and return only the medical allowlist. Password fallback requires `auth_time` within 120 seconds and is limited to five reads per ten minutes.
- Android uses an auth-per-use EC signing key in Android Keystore and the platform BiometricPrompt. Other platforms fail closed to password access.
- The current G4 runtime custom role has Firestore database/entity get and entity create permissions. New state transitions also need `datastore.entities.update`; no IAM change is authorized.
- Firestore and Storage Rules remain deny-all. All data access must use authenticated trusted callables with strict owner checks.

## Proposed access model

### QR and Tier 1

Treat the QR as a bearer credential. Scanning an active QR may start only a restricted Tier 1 experience containing public emergency resources. A copied QR can therefore start the same public experience; it must never reveal the owner's name, registration profile, medical record, contacts, QR payload, or account controls.

The scan service accepts the raw opaque payload over TLS, hashes it server-side, and resolves it through a hash lookup. It returns only a generic active/not-active result. It never returns UID or distinguishes unknown, revoked, incomplete, or unapproved accounts. The client must not call owner-profile, QR-owner, medical, registration-mutation, or other account callables using this Tier 1 context.

Prefer an app-level Tier 1 access context over signing the scanner into the owner's Firebase Auth UID. If a Firebase custom token is used, it must carry a restricted Tier 1 claim and every callable must explicitly reject that claim unless the endpoint is intentionally public. Current callables do not implement this distinction. A successful animation may appear only after the server confirms the QR is active; label the result `QR accepted — Tier 1`, not `Identity verified` or `Signed in`.

QR references remain high-entropy and contain no personal or medical data. Add explicit activation, revocation, and replacement states. Use a hash-indexed lookup rather than a client-supplied UID. Define a migration path for existing unverified v1 credentials before activating any of them.

### Approval and registration

Proposed activation requires all of the following server-controlled states:

- Registration submitted.
- Required medical form completed and acknowledged as self-reported.
- School enrollment approved by an authorized school reviewer.
- QR credential activated by the trusted approval transition.

Keep registration, school approval, medical completion, QR activation, and identity-verification status separate. The owner selected school approval only; no guardian approval is required. The current repository has no school reviewer role, school assignment flow, or approval audit. School reviewers must be explicitly provisioned through a trusted administrative process, and approval evidence must be audit logged. Do not mark self-reported health information as clinically verified or school approval as legal identity verification.

### Medical form proposal from existing fields

- **Owner approved:** Require an explicit conditions answer and an explicit allergies answer. Permit `unknown` and `none_known`. Require details only for `listed`.
- **Owner approved:** Require at least one primary emergency contact with name, relationship, and valid phone before QR activation; keep the secondary contact optional. The current model supports these values, although the existing form does not require them.
- Require a self-report confirmation and use non-test wording. School approval is the only enrollment approval requirement selected by the owner.
- Do not add new field categories without owner approval. Confirm that these fields are sufficient for the client's intended Tier 2 use before treating the form as complete.

### Tier 2 authentication

Do not rely on a device biometric prompt alone: it proves that someone enrolled on the current device authenticated, not that the person is the QR owner. After the account is school-approved, require the owner to authenticate with the existing Firebase account password and enroll an account-bound device signing key protected by an auth-per-use biometric. Store only the public key and device status on the server; keep the private key in platform secure hardware. One active biometric device key is supported per account; enrolling a new device replaces the prior key.

For every Tier 2 request, the server issues a short-lived, single-use challenge bound to authenticated UID, device key, operation, and expiry. The enrolled key signs that challenge after biometric authentication. The server verifies the signature, consumes the challenge, verifies approval/revocation state, and only then returns the owner's permitted fields. Clear Tier 2 state on logout, account switch, app background, and grant expiry. Never fetch medical records before authorization.

**Owner approved:** If the user cannot use the enrolled biometric, use the existing Firebase account password as the safety-password fallback: reauthenticate the same account and require a fresh server-recognized authentication time before issuing a short-lived Tier 2 grant. Do not introduce a second locally stored password. Rate-limit failures and provide no fallback to a different account. On a new device, QR access remains Tier 1; Tier 2 requires password reauthentication, account-bound key enrollment, and school approval.

An OS biometric accepts any biometric enrolled on that device. Shared-device users must be told this. Enrollment changes invalidate or disable the key and require password reauthentication plus re-enrollment. No biometric image/template is collected.

## Backend and permission implications

- Add a public QR-status endpoint with generic responses, request validation, abuse controls, App Check posture review, and no profile/medical reads returned to the client.
- Add authenticated approval and credential lifecycle operations with server-side role checks; no client-settable approval fields.
- Keep production medical completion separate from synthetic QA. Tier 2 returns only conditions, allergies, and the primary emergency contact after verification.
- Add Tier 2 challenge issue/consume and medical retrieval endpoints. Derive UID only from verified Firebase Auth context and require fresh proof on every sensitive operation.
- Review every existing callable so a Tier 1 grant cannot reach profile, QR-owner, medical, or mutation operations.
- The existing runtime role is insufficient for the state transitions. The new code requires `datastore.entities.update`; remaining operations use the current get/create permissions. No custom token is used. Do not grant roles, enable APIs, or deploy without separate scoped approval.

## Owner decisions received

- A QR alone may start Tier 1 because that experience contains only public resources. The proposal therefore treats the scan as a restricted Tier 1 access context, not a Firebase owner-authenticated session.
- Active QR issuance must wait for school approval only; no guardian approval is required.
- A safety password is required when biometric access is enrolled or unavailable. This proposal recommends reusing the existing Firebase account password instead of adding a second password store.
- Review existing medical fields for requiredness; do not invent new health categories.

## Implementation prerequisites to resolve within the approved design

- Establish a trusted source for assigning each account to a real school and provisioning that school's reviewers. Registration now leaves school affiliation unassigned, and activation denies unassigned profiles. Define the trusted roster or enrollment assignment process before any hosted account can be approved.
- Confirm the exact Tier 2 data presentation from the existing conditions, allergies, and emergency-contact fields during implementation review; do not add field categories.
- Review the platform biometric key implementation and derive exact permissions before any hosted rollout. No API/IAM grant is authorized by this design.
- Run the Auth/Firestore/Functions emulator integration suite and physical-device biometric checks before acceptance. Emulator startup was stopped when Firebase CLI created a user-profile credential file, contrary to the existing no-ADC-recreation instruction.

## Out of scope until separately authorized

Hosted deployment, API/IAM/App Check changes, real medical data, account provisioning, approval-role provisioning, migration or activation of existing QR credentials, and release to production.

## Local implementation checkpoint — 2026-11-10

Implemented locally: required production medical completion; server-scoped school approval and revocation; high-entropy active QR issuance, hash-only resolution, and replacement; Tier 1-only scan results; owner-authenticated Tier 2 reads through Android biometric Keystore signatures or fresh Firebase password reauthentication; a five-read/ten-minute password-read limit; and required-medical/school-pending UI states. Registration leaves school assignment unconfirmed so the placeholder school cannot approve real accounts.

Verification: Functions build and 80 focused tests passed; 34 focused Flutter tests passed; scoped Flutter analysis reported no issues; Android `:app:compileDebugKotlin` succeeded. Public QR resolution is bounded by an in-memory per-instance IP window and a four-instance cap; this is a best-effort abuse limit, not a globally coordinated quota. The emulator integration suite and physical-device biometric acceptance have not run.

Emulator startup was stopped after Firebase CLI logged that it was writing a user-profile application-default credential file. This conflicts with the earlier instruction not to recreate ADC credentials. The file was not inspected or removed because its prior state is unknown. No hosted service, account, record, API, IAM binding, App Check setting, or Rules document was modified.

Rollout remains blocked until a trusted school assignment/reviewer provisioning process exists and the runtime role receives a separately authorized `datastore.entities.update` permission. Run emulator integration only after resolving the credential-file concern; perform physical Android biometrics, cancellation, lockout, key invalidation, and password fallback acceptance before any rollout.
