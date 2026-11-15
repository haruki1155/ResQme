# ResQMe School Verification — Integration and Device QA

**Test date:** 2026-11-10 (Asia/Shanghai)  
**Source revision:** `cd5d9f2a412e3bcb6aa501a5729824ea6685dc73` on branch `main`  
**Scope:** Local-only verification of the existing School Verification and Pending QR implementation. No source code changes were made for this QA run.

## 1. Environment

| Item | Observed |
|---|---|
| Flutter / Dart | Flutter 3.44.4; bundled Dart (exact standalone Dart version not collected). |
| Node / npm | Node v24.18.0 / npm 12.0.2 on PATH. The Functions package declares Node 22; fresh tests passed under Node 24, so Node 22 runtime coverage remains unverified in this run. |
| Firebase CLI | 15.34.1. Version query only; no deploy, emulator command, hosted read, or credential inspection was performed. |
| Android device | Connected TECNO CN5, Android 16 / API 36. Serial omitted. |
| Installed ResQMe package | `com.example.resqme`, version `1.0.0`, version code `1`, last update `2026-11-10 01:01` device time. Its source revision and Firebase target could not be established from read-only package metadata. No app launch, install, update, or data access was performed. |
| Checkout Firebase config | `firebase.json` identifies `demo-resqme` and loopback emulator ports 9099/8080/5001/4000 for emulators, while Flutter Firebase options and `google-services.json` identify hosted project `resqme-943ee`. |
| Emulator safety | No listeners were found on configured emulator ports. The required operator confirmation that the prior ADC-related emulator issue is resolved was unavailable. No ADC file was inspected, changed, or recreated. Emulator startup and seeding were not attempted. |
| Git / scope | Existing worktree changes were preserved. `firebase.json`, `firestore.rules`, and `storage.rules` have no changes in this worktree. No hosted configuration was queried or changed. |

## 2. Fresh verification matrix

| Test | Expected | Actual | Status | Evidence |
|---|---|---|---|---|
| Functions unit tests | Existing Functions contracts and security unit tests pass. | 90 passed, 0 failed. | PASS | Fresh `npm.cmd test` in `functions`; includes TypeScript build. Executed under Node 24.18.0. |
| Focused registration Flutter tests | Registration fields, validation, retry/state behavior pass. | 31 passed. | PASS | Fresh `flutter test test/features/registration`. |
| Focused QR Flutter tests | Pending QR and onboarding behavior pass. | 25 passed. | PASS | Fresh `flutter test test/features/qr`. |
| School reviewer Flutter tests | Reviewer UI gates candidate access/approval. | 1 passed. | PASS | Fresh `flutter test test/features/school`. |
| Flutter analysis | No analyzer errors or warnings. | No issues found. | PASS | Fresh `flutter analyze`. |
| Functions TypeScript build | Functions sources compile. | Exit code 0. | PASS | Fresh `npm.cmd run build` in `functions`. |
| Diff whitespace | No whitespace errors. | Passed; Git emitted line-ending conversion warnings for existing modified files. | PASS | Fresh `git diff --check`. |
| Auth/Firestore/Functions emulator integration | Five synthetic workflows and transactional race/retry checks pass. | Not executed; startup prerequisite not confirmed. | BLOCKED | `npm run test:integration` was not run. No emulator or seeder was started. |
| Firestore Rules emulator tests | Direct client access remains denied. | Not executed; emulator prerequisite not confirmed. | BLOCKED | `npm run test:rules` and `npm run test:rules:contained` were not run. |
| Physical-device workflow | Safe local build completes student/reviewer flows. | Device connected, but installed build source/environment is unknown and checkout config targets hosted staging. App was not launched or replaced. | BLOCKED | Read-only ADB hardware/package metadata only. |
| Hosted behavior/configuration | No hosted access is needed for this test. | No hosted operation occurred. | NOT RUN | No hosted account/document, API/IAM/Rules/App Check query or mutation. |

The fresh Functions count is not combined with historical totals. Unit tests exercise contracts and predicates; they do not prove emulator transactions or device behavior.

## 3. Five synthetic student results

All five fixture cases were **NOT RUN** in an emulator. No synthetic Auth accounts or Firestore records were created.

| Fixture | Registration | Roster result | School decision | Medical eligibility | QR | Tier 1 | Status / evidence |
|---|---|---|---|---|---|---|---|
| Student 1 | Not run | Not run | Not observed | Not observed | Not observed | Not observed | BLOCKED — emulator safety confirmation unavailable. |
| Student 2 | Not run | Not run | Not observed | Not observed | Not observed | Not observed | BLOCKED — emulator safety confirmation unavailable. |
| Student 3 | Not run | Not run | Not observed | Not observed | Not observed | Not observed | BLOCKED — emulator safety confirmation unavailable. |
| Student 4 | Not run | Not run | Manual review not run | Not observed | Not observed | Not observed | BLOCKED — emulator safety and trusted reviewer fixture/provisioning unavailable. No reviewer authority was created. |
| Student 5 | Not run | Duplicate/conflict case not run | Not observed | Not observed | Not observed | Not observed | BLOCKED — emulator safety confirmation unavailable. |

Synthetic resource accounting: **0 accounts, 0 profiles, 0 roster documents seeded, 0 reviewer records, 0 QR credentials** created in this QA run.

## 4. Security results

| Boundary | Unit/widget evidence | Integration/device evidence | Result |
|---|---|---|---|
| Client cannot supply school/reviewer/approval authority | Fresh Functions unit tests cover ignored/forged authority fields and reviewer request shape. | End-to-end requests not run. | PASS at unit-contract level; end-to-end NOT RUN. |
| Same-school reviewer and exact candidate projection | Fresh Functions tests cover the candidate projection and same-school approval contract; Flutter test gates candidate and approval behind reviewer sign-in. | No reviewer account or emulator approval performed. | PASS at unit/widget level; end-to-end BLOCKED. |
| LRN remains private; QR resolver is non-identifying | Fresh Functions unit tests cover profile allowlist, private LRN, opaque payload shape, and public result contract. | No transport capture or scanner request performed. | PASS at unit-contract level; transport/device NOT RUN. |
| Medical and guardian eligibility | Fresh unit tests cover independent medical eligibility and minor denial without independent guardian proof. | No hosted or emulator record was used. | PASS at predicate level; lifecycle integration NOT RUN. |
| Reuse/race/timeout behavior | Auth/Firestore transaction scenarios are present in the integration suite. | Integration suite not executed. | BLOCKED. |
| Direct Firestore writes denied | Rules files unchanged in the local worktree. | Rules emulator tests not executed; hosted Rules were not queried. | NOT VERIFIED in this QA run. |
| No hosted configuration changed | No hosted operation was issued; no local Rules/config changes are present in this change set. | Hosted state not queried. | PASS for actions performed; hosted state not freshly verified. |

No confirmed unauthorized approval, cross-account disclosure, or sensitive-data exposure was observed in the tests that ran. End-to-end security acceptance remains incomplete because those scenarios require the blocked emulator path.

## 5. Android UX findings

No app screens were exercised. The device is connected, but the installed package cannot be tied to this source revision or a safe local backend, and this checkout points Firebase options to staging. Replacing the installed app would require separate approval. Therefore registration, sign-in, pending QR, camera permission, scanning, account switching, public Tier 1 navigation, offline behavior, layout/text scaling, and latency are all **NOT RUN**. No visual or performance claims are made.

## 6. Test totals

| Area | Fresh result |
|---|---|
| Functions unit suite | 90 passed / 0 failed. |
| Flutter registration | 30 passed / 0 failed (count corrected 2026-11-10). |
| Flutter QR | 25 passed / 0 failed. |
| Flutter school reviewer | 1 passed / 0 failed. |
| Flutter analyzer | Passed; no issues. |
| Functions build | Passed. |
| Emulator integration | BLOCKED / not run. |
| Rules tests | BLOCKED / not run. |
| Android device tests | BLOCKED / not run. |

## 7. Outstanding requirements

1. Obtain explicit operator confirmation that the previous emulator credential issue is resolved; then recheck only the approved demo-project/loopback safety conditions before starting the existing emulator workflow. Do not inspect or recreate ADC as part of QA.
2. Run the authored integration and Rules suites with the five existing fictional fixtures; do not seed hosted staging.
3. Provision a real school roster only through an approved trusted import and secure the high-entropy `RESQME_SCHOOL_ROSTER_HMAC_KEY` before any real use.
4. Have the school authority provision and verify named reviewer accounts and school assignments; do not fabricate privileged identities.
5. Authorize the required Functions runtime `datastore.entities.update` permission separately before any hosted deployment/use.
6. Define and independently verify guardian authorization. Minor activation must remain blocked without it.
7. Review the privacy-notice version for LRN and enrollment-code processing.
8. Rebuild/revalidate the deployment artifact and obtain separate deployment authorization; this QA did not deploy.
9. For device QA, establish a safe local build/environment and obtain owner approval before replacing the installed package. Current installed package revision/environment is unknown.
10. Repeat required validation under the package’s Node 22 runtime; the available system runtime was Node 24.18.0.

## 8. Final demo readiness

**A. Tier 1 Public School Demo: UNVERIFIED.** Local focused tests pass, but no physical-device walkthrough or safe local backend acceptance was performed. Do not present the installed package as this source revision.

**B. School Verification and Protected QR Demo: NOT READY.** Emulator integration, Rules verification, reviewer authority, real roster/secret preparation, runtime permission, and minor guardian authorization remain unresolved. The five-student workflow and QR lifecycle have not been observed end to end.

Recommended demo order after blockers are cleared: public Tier 1 access → three roster-match registrations → manual-review registration and approval by an already authorized reviewer → adult medical completion and QR eligibility → pending/revoked/inactive QR scans → cross-school and privacy-denial checks. Minors must remain inactive unless an independently verified guardian process is implemented and authorized.

---

## 2026-11-10 — Blocker recovery and expanded QA checkpoint

### A — Workspace and implementation: PASS

Checkout remains `main`, HEAD `cd5d9f2a412e3bcb6aa501a5729824ea6685dc73`; the existing dirty worktree is preserved. No repository `AGENTS.md` was found. Required LRN validation, roster matching and five fictional fixtures, reviewer authorization, pending QR, medical completion, eligibility/revocation, and routes remain present. QA changes were limited to the HMAC environment-name fix and regression test, a guarded five-fixture integration test and script entry, this report, and ignored build output.

### B — APK identity and device: BLOCKED pending install approval

The connected device is TECNO CN5 / Android 16 (API 36). Installed package `com.example.resqme` is version `1.0.0`, code `1`; its source revision and Firebase target remain **unknown**. Read-only signing verification found the installed APK and new debug APK use the same certificate SHA-256 digest: `b312636b872567f3a0095819eef0a55d8135d8843e23998c166a09f17af0cf6f`. This supports an in-place update but does not prove the installed app's provenance.

A fresh debug APK was built, not installed or launched:

| Item | Value |
|---|---|
| Command | `flutter build apk --debug --dart-define=RESQME_BACKEND=emulator` |
| Path | `build/app/outputs/flutter-apk/app-debug.apk` |
| SHA-256 | `12AAD39A075AAD9B9078851BE99A351FFA4BD77F13804C05920052D2B40EF3EA` |
| Size | 213,413,010 bytes |
| Identity | `com.example.resqme`, version `1.0.0`, code `1` |
| Backend | Debug-only selection of `demo-resqme`, Functions region `us-central1`; emulator hosts are `127.0.0.1:9099`, `:8080`, and `:5001`. This build define does not select staging. |
| Phone forwarding | No `adb reverse` mappings existed. The repository's local-testing guide documents the required temporary port forwards. |

`adb install -r` would replace the binary and preserve app data; no app data was read, cleared, or changed. Installation is pending explicit owner approval. The app was not launched because the installed build is unverified and the emulator is stopped.

### C — Emulator credential incident: BLOCKED after recurrence

The sanitized design note says prior Firebase CLI emulator startup attempted to write a user-profile ADC file and that it was left untouched. The exact earlier command/session profile is not recorded in the available sanitized notes. The owner confirmed assessment of the prior incident, CLI session, ADC source and credential overrides, and approved reuse of the demo-project loopback workflow.

During the fresh `firebase.cmd emulators:exec --config firebase.integration.json --project demo-resqme --only auth,firestore,functions ...` run, Firebase CLI again logged that Functions Emulator startup was writing an application-default credential file and setting `GOOGLE_APPLICATION_CREDENTIALS`. I stopped the run immediately (exit 1). I did not inspect, copy, delete, move, or regenerate that file. Afterward no Firebase emulator process/listener remained, and the parent shell had no credential-file override. The output reached cleanup from an existing integration case, but no complete test summary or final per-resource audit was captured; no integration result from this run counts as passed.

The observed trigger is Functions Emulator credential setup. This is consistent with the log, but the newly created artifact's status/disposition must be assessed by the authorized operator. **Do not retry Functions Emulator startup until the new occurrence is assessed and a compliant workflow is explicitly confirmed.**

### D — Runtime and fresh checks

Only Node `24.18.0` / npm `12.0.2` are available; the prior project note says the portable Node 22 runtime was removed. No runtime was installed. Fresh checks under Node 24:

| Command | Result |
|---|---|
| `npm.cmd test` | PASS — build plus 90 tests, 0 failed. |
| `npm.cmd run build` | PASS — exit 0. |
| `flutter test --reporter compact test/features/registration test/features/qr test/features/school` | PASS — 56 tests, 0 failed. |
| `flutter analyze` | PASS — no issues. |
| `git diff --check` | PASS — exit 0; line-ending conversion warnings only. |
| Node 22 parity | BLOCKED — unavailable; not installed. |

The seeder regression first failed because it read `RESQME_ROSTER_HMAC_KEY` while registration and the integration test use `RESQME_SCHOOL_ROSTER_HMAC_KEY`. The seeder now uses the shared name; the fresh 90-test suite passed. The existing local-only synthetic test HMAC value was supplied only to that emulator process; no hosted secret or Google credential was generated.

### E — Five-fixture integration: BLOCKED

A guarded `school_roster_fixtures_integration.test.ts` now covers all five approved fictional cases, code consumption, manual review, conflict preservation, pending QR, adult activation after medical completion, minor non-activation, owner projection privacy, and exact test-owned cleanup. It compiles in the Functions build and is included in `test:integration`, but was not reached in the interrupted emulator run. Integration, Rules tests, and fixture seeding are unverified.

No hosted resources were touched. The interrupted local session may have created in-memory test records before shutdown; full cleanup verification was not captured. Emulator listeners are stopped, and the configured integration file has no import/export directory. Do not report cleanup as certified.

### F — Physical Android QA: BLOCKED

No app screens or device workflows were exercised. Public Tier 1 could be tested offline after approved installation; registration/reviewer/QR server tests require the blocked emulator. The repo documents `adb reverse` for phone loopback, but no forwarding was set up. No emergency calls were placed.

### G — Hosted prerequisites (read-only analysis)

- **Roster:** Trusted import source/operator, schema validation, duplicate-LRN review, secure code issuance/distribution, retention and privacy rules are absent. Local records use `schoolRosterClaims/{HMAC(LRN)}` and `schoolRosterCodes/{HMAC(code)}`; fixtures are not school evidence.
- **Reviewer:** `schoolReviewers/{uid}` requires active state and trusted school assignment. No real reviewer or provisioning process exists.
- **HMAC:** `RESQME_SCHOOL_ROSTER_HMAC_KEY` requires at least 32 UTF-8 bytes. Production secret provisioning and real school codes are absent; no hosted key was generated or uploaded.
- **Runtime IAM:** The approved custom role contains `datastore.databases.get`, `datastore.entities.get`, and `datastore.entities.create`, but lacks `datastore.entities.update`. Registration claim consumption, approval/revocation, medical completion and QR state transitions update existing documents. The minimal proposed delta is adding `datastore.entities.update` to `projects/resqme-943ee/roles/resqmeFunctionsRuntime` for `resqme-functions-runtime@resqme-943ee.iam.gserviceaccount.com`. At project scope this allows updates across Firestore documents to Admin SDK code; Rules do not narrow server IAM. This requires separate owner approval; do not substitute a broad role.
- **Guardian:** Eligibility reads `studentGuardianAuthorizations/{uid}`, but no independently verified guardian enrollment/consent workflow or trusted writer exists. Minors remain fail-closed.
- **Privacy:** The notice discloses LRN/code processing while retaining `tier1-registration-v1`; privacy/legal review and version decision remain.
- **Deployment:** No hosted state was queried or changed. Prior G4 Authorization A covered three Functions only; this code is newer. A new reviewed allowlist/artifact and deployment approval are required. Current school/Tier 1 source dependencies include registration/profile, reviewer candidate/approval/revocation, medical completion, and QR ensure/resolve/replace. Synthetic-only medical and Tier 2 exports must not be swept in. No candidate artifact or deployment was prepared.

### H — Updated readiness

| Checkpoint | Result | Evidence / next action |
|---|---|---|
| A — Workspace | PASS | Dirty tree preserved; scoped QA changes only. |
| B — APK provenance | BLOCKED | New APK identified; installed provenance unknown. Obtain approval before `adb install -r`. |
| C — Emulator recovery | BLOCKED | ADC write recurred; operator assessment needed before another Functions Emulator attempt. |
| D — Runtime tests | BLOCKED | Fresh local tests pass on Node 24; Node 22 parity unavailable. |
| E — Integration | BLOCKED | Interrupted; no integration, Rules, fixture, or complete cleanup result. |
| F — Android QA | BLOCKED | No install or launch; emulator recovery also required for server flows. |
| G — Hosted readiness | BLOCKED | Trusted roster/reviewer, secret, runtime IAM, guardian/privacy and new deployment approval remain. |

**Public Tier 1 demonstration: UNVERIFIED.** Unit/widget tests pass; no phone flow was observed.  
**Registration and school verification: NOT READY.** Five-student and reviewer integration were not run.  
**Protected QR activation: NOT READY.** Lifecycle integration was not run and minor guardian verification is absent.  
**Hosted deployment: NOT READY.** No new artifact/authorization; trusted-school prerequisites and runtime permission remain unresolved.

**Synthetic resource accounting:** no hosted resources. The five-row fixture test/seeder was not reached. Emulator test teardown/absence checks were not fully observed, so cleanup is not certified.

**Next approvals/actions:** (1) operator assessment of the newly recurring ADC artifact and explicit compliant emulator path; (2) owner approval before installing the identified APK over the existing package; (3) separate runtime IAM authorization; (4) trusted reviewer/roster, guardian and privacy decisions; (5) new deployment approval for a reviewed export set.

## 2026-11-10 — Approved Android install and public Tier 1 device checks

The owner approved updating the existing app install and offline/public Tier 1 checks. `adb install -r` succeeded for the verified debug APK (SHA-256 `12AAD39A075AAD9B9078851BE99A351FFA4BD77F13804C05920052D2B40EF3EA`); package and signer matched the installed app. No app data was cleared or uninstalled. The app was launched on TECNO CN5.

**Observed on device:** scanner-first entry; guest dashboard; First-aid instructions; Emergency Hotlines directory; DRRM instructions and the Earthquake action-plan dialog. Tier 2 opened only its restricted-information screen, explicitly stating that no protected profile is loaded. No phone number was tapped and no call was placed. No account, registration, school-review, QR-resolution, or hosted/server-backed operation was attempted.

For an offline spot check, airplane mode was enabled, confirmed by Android setting state `1`, and the guest dashboard was opened successfully. Airplane mode was then disabled and the setting returned to `0`; the device's previous connectivity state was restored. The public screen remained available. This confirms basic offline access to the dashboard; it does not establish every screen's complete offline behavior.

The earlier section F and readiness row H said no device screens were exercised, installation was pending, and the install needed approval. This dated result supersedes those statements. The prior evidence that server-backed QR and school-review flows were not run remains accurate.

**Emulator integration remains BLOCKED.** Firebase CLI again attempted an ADC-related profile write during Functions Emulator startup; execution was stopped immediately. The file was not inspected or removed, integration and Rules suites did not complete, and fixture cleanup is not certified. Continue to require operator assessment before another emulator attempt.

`git diff --check` passed after the test; only existing LF/CRLF conversion warnings were printed. No source change, hosted operation, commit, or push was made for this device check.

**Updated device readiness:** The authorized public Tier 1 flows above were observed on a physical device, including an offline guest-dashboard spot check. Therefore the earlier “Public Tier 1 demonstration: UNVERIFIED” line is superseded for those observed screens. Registration/school verification, active QR resolution, full offline coverage, and hosted readiness remain unverified or blocked as stated.
