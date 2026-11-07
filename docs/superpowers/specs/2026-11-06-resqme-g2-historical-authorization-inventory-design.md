# G2 — Historical authorization inventory specification

Status: **DRAFT for owner review.** Inventory-first approach selected by the owner. This document does not authorize hosted reads, implementation of an inventory tool, or remote changes. G3 and G4 remain blocked.

## Goal and current state

Establish whether historical staging authorization state can safely participate in the implemented Registration → Optional Synthetic Medical Record → Unverified QR → Dashboard flow. Preserve historical records and propose only evidence-backed, separately approved remediation.

G1 published deny-all client Rules to `resqme-943ee`, project number `519076598217`, database `(default)`, location `nam5`. Verified release `projects/resqme-943ee/releases/cloud.firestore` points to ruleset `aa4be7e8-ce25-44d1-afd8-c10654658bab`, updated 2026-11-06T10:04:54.186101Z. This is captured evidence, not a new live check. G1 does not block Admin SDK access or establish document provenance.

Previous public-write Rules allowed arbitrary changes to authorization documents. A document's existence, claimed status, synthetic flag, actor UID or timestamp does not by itself prove trusted creation. No compromise is asserted.

## Authorization boundaries

Three separate approvals are required:

1. Approve this specification and local-only implementation/testing of an inventory tool.
2. Approve its reviewed artifact, exact identity, project/database, field projections, read limits and private evidence location before hosted metadata collection.
3. Approve any exact remediation actions after reviewing results. Inventory approval never authorizes writes.

No API enablement, Functions deployment/invocation, IAM/billing changes, Auth account enumeration/creation, QA grants, Rules change, record mutation, backup export of document contents, or production operations are included. If existing permissions are insufficient, stop; do not obtain new roles implicitly. Retain G1 deny-all throughout G2.

## Inventory scope and allowed fields

Use existing authorized operator credentials. Reconfirm project/database/identity and the exact G1 active release through metadata APIs before the inventory; stop if they differ. No broad Admin document reads followed by local redaction: server-side projections must exclude sensitive fields before retrieval. Firestore document IDs, references and creation/update metadata are themselves private evidence.

| Collection/path | Permitted projected fields |
| --- | --- |
| `studentProfiles/{uid}` | `schemaVersion`, `status` |
| `qaTesters/{uid}` | `enabled`, `syntheticOnly` |
| `studentQrCredentials/{uid}` | `verificationStatus` |
| `studentMedicalRecords/{uid}` | `schemaVersion`, `syntheticOnly`, `medicalStatus`, `guardianAuthorizationStatus`, `revision` |
| Profile and medical `acknowledgments` subcollections | Document references and creation/update metadata only; no content fields |
| Medical `requests` subcollections | Document references and creation/update metadata only; no digests or other content fields |
| Other root collections/subcollections | Collection identifiers only; no documents or field values |

Explicitly exclude names, emails, ages, phone numbers, contact relationships, LRN, medical conditions/allergies/details, passwords, QR payloads/references stored as fields, request digests and credentials. Never retrieve whole documents, even for a malformed-field investigation. Missing fields remain unknown; do not expand projections automatically. Reference-only queries must use a verified zero-field projection, not an omitted field mask that could return full contents.

Enumerate root collection identifiers and use collection-group queries for the scoped acknowledgment/request groups so subcollections under missing parent documents are not silently missed. Restrict accepted returned paths to the prefixes above; other paths receive no content projection and are reported only as out-of-scope identifiers. Do not recursively inspect unknown collections. If these query shapes require indexes or permissions not already available, stop rather than deploying indexes or expanding access.

For the first authorized pass: page size 100; maximum 500 documents per scoped query and 2,000 documents in total; maximum 100 discovered collection identifiers; ten-minute overall time limit and 30-second request timeout. Use deterministic document-reference ordering and read-only pagination. Record start/end times and limitations; a multi-query pass is not an atomic database snapshot. Hitting a cap, timeout or pagination error marks the inventory incomplete, blocks clearance and requires separately approved continuation. Do not infer emptiness or completion from a failed request.

## Evidence, classification and reporting

Store raw projected metadata and the ID-to-alias mapping only in an operator-approved private directory outside Git. Do not print raw UIDs/paths in chat or commit them. The shareable report uses aliases such as `account-001`, aggregate counts, field-presence/type summaries and classifications. No medical field contents are collected. On unexpected sensitive contents or oversized/non-scalar values in projected fields, stop processing, suppress values from output and report the field/path alias only; do not expand inspection.

Classify each authority-bearing profile/QA/QR record:

- **Trusted:** independently corroborated authorized server/operator creation and relevant subsequent changes. Document fields alone are insufficient. Any audit-log review requires its own scoped authorization and must not expose payload contents.
- **Untrusted:** independent evidence of unauthorized origin/change or invalid authority. Do not label a merely unusual record as compromised.
- **Unresolved:** evidence absent, incomplete or conflicting. This is the default for historical authority.

Medical completion flags, acknowledgments and request receipts may affect retries or UI but never establish school approval, guardian authorization or trusted QA entitlement. Flag unexpected status values or enabled QA entries as review items, not automatic approval or automatic revocation. Cross-collection references may be compared privately by UID; orphaned or conflicting state remains unresolved without opening content.

If no scoped records exist and all queries complete, record a verified empty scoped baseline at the inventory time. Unknown collections still require a separate compatibility decision; scoped emptiness is not proof the entire project is empty or historically uncompromised.

## Remediation proposal and G2 exit criteria

Inventory performs no remediation. For every unresolved/untrusted authority record, propose an exact path/action privately, its reason, preservation method, dependencies and expected app impact. Options may include approved QA revocation, isolation of historical state or a bounded server-controlled cutover; none is selected or executed automatically. Do not reset the database, delete accounts, rewrite evidence or silently mint replacement QR references.

Fresh post-G1 synthetic UIDs are preferred for later testing, but creating them is a later authorization and does not neutralize old enabled QA records or forged profiles. Do not deploy callables while they can consume unresolved historical authority. If inventory cannot support safe remediation within the existing schema, return a separate minimal design proposal; do not introduce a namespace or architecture change during inventory.

G2 is complete only when:

- All approved inventory queries completed within declared limits, with evidence and limitations recorded.
- Historical authority is independently trusted or an exact approved remediation has been executed and verified under a separate authorization.
- No unresolved historical state can grant QA saving, satisfy a trusted-profile prerequisite, restore a forged QR credential, or influence retries after release.
- Unrelated collection/consumer compatibility and the later owner-readable Rules transition have an explicit owner decision.
- The owner accepts the G2 closure report. A proposed cleanup or successful metadata scan alone does not close G2.

G3/G4 remain blocked until these conditions are met. G2 completion does not itself authorize API enablement or application deployment.

## Local validation required before any hosted run

Test against `demo-resqme` and loopback emulators using synthetic fixtures only:

- Reject staging/production targets in tests; require explicit staging execution approval in the future runner; no silent endpoint fallback.
- Confirm each query uses only its exact allowlisted projection and performs no writes; reference-only queries do not retrieve sentinel name/contact/medical/QR fields.
- Cover empty state, missing parents with subcollections, missing/malformed fields, forged status/QA flags, cross-collection conflicts, unknown collections, page boundaries, caps, timeouts and partial failures.
- Capture request shapes with a fake transport so accidental whole-document reads, Auth enumeration, callable invocation and mutation methods fail tests.
- Verify sanitized reports contain no raw identifiers, forbidden fields or credentials. Confirm classification defaults to unresolved without independent evidence.
- Verify G1 metadata mismatch aborts before document inventory and no test can mark G2 complete from proposed rather than verified remediation.

Preserve the existing checkout, permanent Rules, four in-progress UI files and untracked owner documents. Do not commit or change the deployed G1 policy as part of specification preparation.
