# G2-A hosted inventory adapter design

Status: **Approved for implementation planning on 2026-11-07**, subject to the clarifications incorporated below. Owner selected existing user ADC credentials. Prepare a separate implementation plan and wait for its approval before implementing locally. Code implementation, credential setup/inspection and hosted requests remain unauthorized.

## 1. Goal and boundaries

Prepare a small, separately invoked hosted adapter for the inventory engine completed at `7533550`. Reuse its allowlists, pagination, limits, scalar validation, classification and sanitized reports. Do not rebuild the engine or add an admin UI, Cloud Function, database or Firebase project.

The emulator CLI remains local-only and continues rejecting hosted targets. Local adapter implementation/testing uses mocked credentials/HTTP/filesystem and synthetic emulator fixtures only. Future hosted execution requires separate exact-artifact authorization. No deployment, API enablement, IAM/billing changes, Auth enumeration/account creation, QA grants, database writes, G2-B remediation or G3/G4 work is included.

G1 captured baseline: project `resqme-943ee`, number `519076598217`, database `(default)`, location `nam5`; release `projects/resqme-943ee/releases/cloud.firestore`; ruleset `projects/resqme-943ee/rulesets/aa4be7e8-ce25-44d1-afd8-c10654658bab`. Approved deny-all source SHA256: `7bff2de50c73415a3b12a6783f42ff621b1b04803ffc4e2634e6ba68e5d655f9`. These are expected values, not a fresh verification.

## 2. Minimal architecture and compatibility

Add a hosted credential/preflight/entry-point boundary and an authenticated read-only transport alongside the existing tools. Shared inventory logic remains the sole implementation of collection limits, pagination, reporting and classification. Hosted authentication must never be imported by the local entry point or initialized during module import.

Two small compatibility edits are necessary:

- Existing `documentPrefix`, `validName` and private-path extraction are fixed to `demo-resqme`. Add an explicit validated document namespace to shared path handling/inventory invocation, defaulting to the existing demo namespace. Only the separate hosted boundary may supply the fixed staging namespace after authorization and preflight. No arbitrary project/database strings.
- Extract reusable request-body construction and response decoding from the existing local transport. Both transports use the same exact projections, pagination/order and response validation. Keep the local transport's literal loopback endpoint, `localConfig` checks and emulator owner marker intact. Hosted requests must never use that marker or fall back to the emulator.

No changes to deployed callables, Flutter functionality, permanent Rules or G1 containment artifacts. Existing tests remain regression gates. Declare `google-auth-library` as a direct tool dependency during the future implementation rather than depending on an undeclared transitive module. Version `11.3.1` is already installed transitively; the implementation plan will pin the reviewed compatible version and preserve lockfile reproducibility. No new authentication framework or CLI-internal API is needed.

## 3. Operator identity: existing user ADC only

Use an explicitly supplied, owner-approved absolute path to an existing user ADC file. Do not invoke broad ADC discovery, metadata-server fallback, gcloud/Firebase CLI account selection or automatic sign-in. Only `authorized_user` credentials are supported in this first adapter. Reject service-account keys, impersonated/external credentials and unknown credential types before token requests.

Read credentials in memory through Google's auth library. Do not rewrite the ADC file, persist tokens, switch accounts or alter granted permissions. Normal token refresh using the existing refresh token is permitted only during separately approved hosted execution; missing/revoked/insufficient credentials stop the run. No credential setup is performed automatically.

Obtain an access token and verify **that exact token** using Google's token-info API through the library's `getTokenInfo` operation. Require a nonempty stable subject (`sub`, or the documented stable `user_id` when `sub` is absent), verified email and nonexpired token. Compare both subject and email with owner-approved expected values. Neither the ADC filename nor any CLI account listing establishes identity. If claims are absent, ambiguous or incompatible, stop; do not relax checks or request broader consent automatically.

Owner clarification: missing required identity claims must fail closed. No automatic scope expansion, credential replacement, alternate authentication flow or weakened identity verification is permitted. If both stable-subject claims exist and disagree, reject the identity rather than choosing one. Any prerequisite correction requires a separately authorized operator action outside this adapter.

Use the verified token for all preflight and inventory requests. Before starting, require enough remaining token lifetime for the remaining execution budget plus 60 seconds. Do not silently refresh or change principal mid-run; token expiry or rejection aborts safely. Token-info/refresh failures produce safe error codes; no exception objects, HTTP authorization headers, credential JSON or tokens enter console/evidence output.

Future approval must include the expected email and stable subject. If these are not already established, a separately authorized identity-only validation is required before approving document inventory. It must not enumerate Firebase Auth users or read Firestore documents. No such validation occurs during local implementation.

## 4. Execution approval and preflight

Use one strict, externally approved execution manifest outside Git. It binds:

- Full compiled-tool/shared-engine artifact hashes, dependency-lock hash and reviewed Node runtime version.
- Exact staging project/number/database/location; expected operator email/subject; approved existing ADC path and its local file hash (never file contents).
- G1 release/ruleset/source hash; exact ordered collection/field allowlists; inventory limits.
- Resolved private evidence destination, OS access policy, retention deadline/duration, disposal method and responsible operator.
- A unique run ID, validity window and external owner-approval reference.

Canonical serialization determines the manifest SHA256. No document inventory may occur merely because this file exists. After an explicit owner go for that exact digest, the named operator must interactively enter `APPROVE READ-ONLY INVENTORY <manifest-sha256>` and provide the approval reference. No `--yes`, unattended fallback or agent-created approval receipt. A reused run ID/output directory is rejected using exclusive creation.

This confirmation is an accidental-execution safeguard and an operator attestation, **not cryptographic proof of the owner's identity**. The actual owner approval remains an external recorded authorization; the adapter cannot issue approval to itself. IAM remains the enforcement boundary against a malicious privileged operator. A forged local configuration is not owner approval.

Order of execution:

1. Locally validate manifest schema, exact artifact/ADC hashes, validity window, target, endpoint allowlist, evidence policy and access restrictions. Obtain the explicit operator confirmation. No network operations before these checks pass.
2. Load only the approved user ADC, obtain/verify the token principal and lifetime, then use the same token for subsequent operations.
3. Read project metadata and database metadata; verify exact project ID/number, `(default)`, Firestore Native and `nam5`. Do not infer a target from credentials, environment variables or CLI defaults.
4. Retrieve the active Firestore Rules release, referenced ruleset and source. Require the exact approved release/ruleset, one source file matching the approved deny-all artifact byte-for-byte and its hash, with no additional source files. A changed release, even another deny-all release, requires renewed approval; do not deploy Rules to fix it.
5. Only after all checks pass, invoke the shared inventory engine with the fixed staging namespace and authenticated projected-read transport.
6. Recheck the G1 release at the end. If it differs or cannot be verified, mark the run INCOMPLETE and prohibit any clearance conclusion. This check cannot prove that no concurrent administrative change occurred; record that limitation.
7. Finalize private evidence and the sanitized report, record actual run times and completeness, and stop. Inventory completion never closes G2.

Only fixed HTTPS Google endpoints are permitted: OAuth token refresh/token-info, Firebase project metadata, Firestore database/projected-query metadata and Firebase Rules metadata. Reject custom endpoints, URL overrides, redirects and emulator environment configuration on the hosted entry point. No API-enablement or IAM calls; permission/API errors stop rather than remediate.

## 5. Restricted reads and bounded execution

Reuse these field projections unchanged:

| Scope | Fields |
| --- | --- |
| `studentProfiles/{uid}` | `schemaVersion`, `status` |
| `qaTesters/{uid}` | `enabled`, `syntheticOnly` |
| `studentQrCredentials/{uid}` | `verificationStatus` |
| `studentMedicalRecords/{uid}` | `schemaVersion`, `syntheticOnly`, `medicalStatus`, `guardianAuthorizationStatus`, `revision` |
| Approved acknowledgment/request groups | Reference and document metadata only; explicit `__name__` projection |
| Unknown root collections | Collection identifiers only |

Never retrieve full documents and redact afterward. Unknown nested collections are not recursively discovered. Validate collection-group result prefixes and reject unexpected paths before accepting records. No names, emails, ages, contacts, medical details, LRN, QR payloads, request digests or credentials are requested as inventory data. Operator identity metadata is separate from student inventory and kept private.

Preserve maxima: page 100, scoped query 500 documents, total 2,000 documents, 100 collection identifiers, request 30 seconds and total run 10 minutes. Allow lower limits only, bound into approval. Include authentication and remote preflight in the overall deadline; pass the remaining lower budget into the shared engine. No automatic retries that expand read budgets or bypass deadlines. Empty, malformed, streamed-error, timeout, permission-error, pagination or cap outcomes retain existing fail-closed semantics. Multi-query coverage is not atomic.

The transport exposes only collection-ID listing and projected queries. REST POST operations for those read APIs and OAuth authentication are allowed; document mutations, bulk exports, Auth enumeration and callable invocation are not. Mock request inspection must verify exact endpoints, methods, bodies and authorization-header handling.

Owner clarification: these are **adapter-enforced read-only restrictions**, not a statement that the credential principal has read-only IAM permissions. The operator may possess broader privileges. This adapter does not change, reduce or certify those permissions; G1 client Rules do not constrain privileged server requests. Reports must describe adapter behavior separately from any independently verified IAM permission evidence and must never infer IAM least privilege from successful projected reads.

Historical classifications remain TRUSTED, UNTRUSTED or UNRESOLVED under the existing independent-evidence contract. This adapter supplies no provenance evidence from document fields, so historical inventory records default to UNRESOLVED. Preserve `clearance:NOT_GRANTED`, `g2Complete:false` and no-remediation reporting regardless of scan status.

## 6. Private evidence handling

The final directory, authorized readers, retention period/deadline and disposal procedure are **not chosen by this design**. They are mandatory owner decisions before hosted execution, bound into the approved manifest. Do not substitute the local runner's synthetic `%TEMP%` defaults.

Require an approved local, absolute, resolved directory outside all Git worktrees; reject symlinks/junction redirection and unexpected existing run files. On the user's Windows environment, verify directory ownership and effective allow-list ACLs against approved OS SIDs before network access; broad read access is a stop condition. File mode 0600 alone is not evidence of Windows isolation. Do not silently change ACLs. The approved policy must identify whether SYSTEM or other administrative principals may have access. Unsupported storage/security verification fails closed.

Owner clarification: support only the current Windows workstation's local NTFS evidence-directory case using read-only Windows path/ACL inspection. Do not build a general ACL-management or cross-platform permission framework. Reject unsupported platforms, network/cloud-backed destinations, reparse-point paths, unresolved ownership, unapproved access entries or ambiguous ACL semantics. Do not grant, remove, repair or normalize permissions automatically; report a safe failure and require an operator-prepared directory under a separately approved access policy.

Use separate files for projected private metadata, private UID/path-to-alias mappings and sanitized summaries. Include private preflight/approval metadata without credentials. Shareable output contains aliases, aggregate counts, safe reason codes and coverage limitations, never raw UIDs/paths, field values, token data or the credential file contents. Do not print private filesystem paths or principal claims in shareable console output; record them only in restricted evidence.

Verify destination writability and required access controls before reads; use exclusive writes and preserve partial-run evidence with INCOMPLETE/FAILED status on failure. Do not persist malformed/unexpected projected values. If safe evidence writing fails, stop requests and emit only a safe failure code; do not redirect to a public directory or stdout. Retention/disposal is recorded as operator policy, not falsely claimed as automated deletion. No automatic historical or evidence deletion is included.

## 7. Local acceptance and review gates

Before local implementation, obtain design approval, then a separately approved implementation plan. The plan must include failing tests for:

- Missing/mismatched approval, hashes, project/database, validity window and replayed run IDs; no requests before authorization.
- User ADC type restrictions; token-principal mismatch/missing claims/expiry; no credentials in logs and no account switching or credential-file writes.
- G1 release/source mismatch, metadata failures and an end-of-run baseline change preventing a clean result.
- Exact projections, reference-only behavior, strict group prefixes, caps, cancellation, deadlines and false-empty response regressions using fake hosted HTTP.
- Namespace compatibility without weakening local endpoint guards; original inventory/Functions regressions and synthetic emulator projection tests.
- Evidence outside Git, ACL/redirect/path mismatch, unsafe storage permissions, partial failures, safe output and retention-policy requirements using mocked filesystem/ACL operations.
- Import-time side-effect freedom and no hosted network access anywhere in tests. A hosted-capable module must never be instantiated against live endpoints during this milestone.

Existing Google auth library behavior was inspected locally for design feasibility; no token or ADC file was read. No new dependency is installed at this stage. Node 24 local testing remains permitted; the Functions Node 22 target is unchanged.

After implementation/validation, report exact committed artifact hashes and remaining hosted policy decisions. Stop before any actual ADC token request, remote preflight or document inventory. G2-A adapter completion is not G2-A hosted execution, G2-B remediation, overall G2 closure or authorization to start G3/G4.

## Owner decisions still required before hosted execution

1. Exact expected Google principal email/stable subject and approved existing user ADC file; permission for identity-only verification if needed.
2. Exact reviewed executable/dependency/runtime and approved execution-manifest digest.
3. Exact private directory, authorized OS identities/ACL policy, retention deadline and disposal responsibility/method.
4. Run ID/validity window and explicit authorization of the listed projections and limits against the staging target/G1 baseline.

These missing values block execution, not design review or later mocked local implementation. Do not invent or silently approve them.
