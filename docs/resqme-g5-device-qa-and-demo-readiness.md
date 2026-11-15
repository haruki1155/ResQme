# ResQMe G5 — Physical-device QA and school demonstration readiness

> The original QA matrix and counts below describe the initial G5 APK. The hotline follow-up at the end records the subsequent implementation and device verification; G5-001 is resolved on that newer APK. Other G5 findings are unchanged.

Date: 2026-11-09, Asia/Shanghai. **Final readiness verdict: NOT READY.**

The public/local subset is usable, but the complete requested school demonstration is not ready: hotlines are an advertised placeholder; Profile omits the student's name and pending status; and source wiring routes successful registration into the out-of-scope medical flow. Two complete rehearsals were not achieved. No application fixes were made.

## Executive summary and evidence limits

- Physical device: TECNO CN5, Android 16 / API 36, arm64, authorized USB serial ending `3235`, 1080×2364. `/data` initially had approximately 167 GiB free. One physical Android device was connected.
- Package: `com.example.resqme`, version `1.0.0` / code `1`, debuggable. Existing APK initially matched the local artifact; a fresh supported build established current test provenance.
- Source baseline: `47fd30e567c16b19b7fbb91f410c23c19f8a912b`, **dirty worktree**. HEAD alone does not identify the compiled application. Existing unrelated edits were preserved.
- Build/install: `flutter build apk --debug --no-pub --dart-define=RESQME_BACKEND=staging`, then `adb install -r`. Build passed; in-place install succeeded without uninstall/data reset. Installed SHA-256 independently matched the built artifact: `ada15f0e29c774a22b0acd89257329530534ede7ea8fe43f92d3f5b23b3f5a8b`.
- Backend selection: hosted `resqme-943ee`, Functions `us-central1`, debug-only staging selection. Emulator routing requires the separate explicit emulator mode. No release/profile build was used.
- Scenario ledger: **73 cases — 52 PASS, 6 FAIL, 15 BLOCKED**. FAIL counts include repeated demo confirmations, not distinct defects. BLOCKED includes unexecuted/inconclusive coverage. PASS applies only to the listed action, not every possible state of that feature. One malformed-QR result is explicitly operator-reported.
- Additional local evidence: **24/24 focused Flutter tests passed** for QR parser/scanner/modal, app navigation, first-aid, and DRRM. These are not physical-device results. G4's 29/29 hosted checks remain historical and are not counted here.
- Accounts: a consolidated G5 scope for up to two fictional accounts and exact Tier 1 cleanup was explicitly approved during this session. Exactly two were provisioned; **both users and all six exact document paths are verified absent**. Temporary credentials/UID record removed. No real student data used.
- No Functions deployment, Firebase configuration/API/IAM/Rules/App Check/billing change, application-source/dependency change, Git commit/push, actual emergency call, or medical-record test was performed.

Method: requested Superpowers using-superpowers, systematic-debugging, and verification-before-completion procedures; search-first route/dependency review; ADB device metadata, UI hierarchy, public-screen screenshots, operator-assisted physical QR positioning/connectivity, bounded local tests. No Windows UI automation was required. Private QR pixels were examined only in memory for rendering differences; no private QR image or token is included in evidence. Guidance content was checked for access/readability, **not clinically validated**.

## Implemented feature inventory

| Feature | Implemented | Device testability / observed state | Dependency |
|---|---|---|---|
| Splash | Yes | Cold launches observed; transient splash duration not isolated | Local preferences |
| Terms & Privacy | Yes | Existing consent persists; first-consent screen UNVERIFIED without resetting data | Local preferences |
| Scanner entry / guest entry | Yes | Tested, public without sign-in | Local |
| Public dashboard | Yes | Tested; long header/cards require scroll | Local |
| First-aid library, search/category, 10 topics | Yes | All topics opened/scrolled; category filter and empty search tested; offline sample tested | Bundled local text |
| First-aid instructional images | Placeholder | Visible reserved-image area | Local, missing reviewed assets |
| Emergency hotline directory / dialer | No functional directory | Placeholder; no numbers or calling controls | Requires approved regional contacts; not supplied |
| DRRM library, search, 10 hazards | Yes, with image placeholders | All hazards expanded; offline Earthquake content tested; device search not completed | Local |
| Public QR camera scanner | Yes | Format recognition/repeat/offline tested; several camera conditions remain blocked | Camera + bundled ML Kit |
| Public QR result | Format-only MVP | Explicitly UNVERIFIED; no student identity lookup | Local parser/modal, no network lookup |
| Student sign-in / logout | Yes | Two accounts tested; offline error and restored-network sign-in tested | Firebase Auth + own-profile Function |
| Registration form | Yes | Required-field validation tested; successful device submission intentionally blocked by medical route | Auth + createStudentRegistration |
| Registration privacy acknowledgment | Yes in source | Not reached by device success path in this QA scope | Local dialog + registration acknowledgment write |
| Pending status / refresh / submitted-details panel | Component exists | Main hosted account route bypasses the status screen; details/refresh not exercised | getMyStudentProfile |
| My Profile minimal name/status | Not satisfied by current route | Profile opens My unverified QR instead; reproduced for two accounts | Auth + getMyStudentProfile |
| My unverified QR | Yes | Both accounts rendered different QR patterns; persisted session reopened QR | ensureMyTier1Qr + local QR rendering |
| Tier 2 access boundary | Yes, static only | Tested; explicitly says no protected profile/biometrics | Local |

The medical-screen implementation exists but is outside this QA scope. It was inspected only far enough to identify and avoid the automatic successful-registration path. No medical document was read/written during the tests.

## Functional QA matrix

| Test ID | Feature/action | Expected | Actual | Result | Evidence |
|---|---|---|---|---|---|
| ENV-01 | Physical device | One authorized Android device | TECNO CN5, Android 16/API 36, arm64; authorized USB device | PASS | adb devices -l; flutter devices |
| ENV-02 | APK/source identity | Known debug APK installed in place | Fresh staging debug build and in-place install; installed SHA-256 matches built APK | PASS | Build/install output and on-device sha256sum |
| ENV-03 | Backend selection | Hosted staging; no unintended emulator | RESQME_BACKEND=staging; source pins resqme-943ee and us-central1 | PASS | Exact build command; main.dart; BackendSelection |
| C1-01 | Cold launch | No blank startup/crash | Cold activity starts succeeded; entry rendered | PASS | ADB cold launches: 4.232s, 3.244s, 2.795s; debug observations |
| C1-02 | Existing consent | Accepted consent persists | Process recreation returned to entry without a consent loop | PASS | Cold-reopen UI hierarchy |
| C1-03 | First-time Terms/Privacy | Consent gating and acceptance work | Existing consent retained; first-consent path not reset or exercised | BLOCKED | No data-clear permission; source/widget coverage only |
| C1-04 | Public back navigation | Return from resources without reset | First-aid/DRRM/boundary back and result-to-dashboard worked | PASS | Repeated public route observations |
| C2-01 | Guest dashboard | Public help accessible without Auth | Guest entry opened all advertised destination routes | PASS | dashboard-bottom.png; route observations |
| C2-02 | Portrait layout | Readable destination controls | No clipping observed on reviewed public screens; resources require scrolling | PASS | Public screenshots; bounded current-process overflow check |
| C3-01 | First aid: Asthma | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-02 | First aid: Anemia | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-03 | First aid: Nosebleed | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-04 | First aid: Hyperventilation | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-05 | First aid: Moving an injured person | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-06 | First aid: Basic life support (BLS) / CPR | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-07 | First aid: Choking (blocked airway) | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-08 | First aid: Bleeding and wound care | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-09 | First aid: Burns | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-10 | First aid: Fractures, sprains, dislocations & seizures | Topic opens and can scroll | Detail opened; one scroll performed; no complete clinical/content audit | PASS | Physical-device topic navigation; library-results.json |
| C3-11 | First-aid category filter | Only matching topics shown | Bleeding & wounds showed Nosebleed and Bleeding and wound care | PASS | Device UI hierarchy |
| C3-12 | First-aid empty search | Explain no matches and recovery | No-match query removed topics with no explanatory result message; reproduced twice | FAIL | empty-search.png; source filtered list |
| C3-13 | First aid offline | Local guidance remains available | Asthma instructions rendered with airplane mode on and no default network | PASS | Offline hierarchy and Android network metadata |
| C4-01 | Emergency hotlines | Approved numbers and useful hotline UI | Placeholder only; no directory or call control; reproduced twice | FAIL | hotlines.png; app_routes wiring |
| C4-02 | Safe dialer handoff | Stop before any actual call | No call control exists; no emergency call attempted | BLOCKED | Depends on missing approved directory |
| C5-01 | DRRM: Drought | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-02 | DRRM: Landslides and mudslides | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-03 | DRRM: Tsunami | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-04 | DRRM: Severe thunderstorm | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-05 | DRRM: Flood | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-06 | DRRM: Extreme heatwaves | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-07 | DRRM: Earthquake | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-08 | DRRM: Tropical cyclone | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-09 | DRRM: Fire | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-10 | DRRM: Transportation accidents | Hazard opens/expands | Expansion succeeded; image slots are placeholders | PASS | Physical-device expansion; drrm-results.json |
| C5-11 | DRRM offline | Local guidance remains available | Earthquake expanded; before/during/after text visible offline | PASS | Airplane mode=1; active default network=none; UI hierarchy |
| C5-12 | DRRM search/empty state | Filter and explain no matches | Search present; device typing/empty-state scenario not completed | BLOCKED | Existing local widget test passed; no device claim |
| C6-01 | Empty sign-in validation | Useful required-field feedback | Enter a valid email / Enter your password shown | PASS | empty-signin.png |
| C6-02 | Offline sign-in | Bounded useful network error | Connection unavailable. Please retry. shown; sign-in control re-enabled | PASS | Offline sign-in hierarchy |
| C6-03 | Connectivity recovery | Sign in after network restored | First fictional account signed in and rendered My unverified QR | PASS | Device hierarchy; exact account setup record, subsequently removed |
| C6-04 | Account switching | Second account gets independent account UI | Logout followed by second account sign-in; QR image region changed | PASS | Sanitized UI and non-reversible QR-region comparison; no raw screenshot retained |
| C6-05 | Logout | Account-specific UI clears | Logout returned to public entry, with no QR displayed | PASS | Device hierarchy after each logout |
| C6-06 | Session process recreation | Existing sign-in survives restart | After app force-stop/cold launch, Sign In opened QR without credential re-entry | PASS | Cold launch + persisted-session hierarchy; not ordinary Android eviction |
| C6-07 | Registration required fields | Reject blank submission locally | Email/password feedback shown; no registration request submitted | PASS | registration-empty-errors.png; UI hierarchy |
| C6-08 | Successful registration on device | Stay within authorized Tier 1 | Not submitted: source routes successful registration into medical screen and medical read | BLOCKED | resqme_app.dart:47-61; PilotAccountScreen.initState; medical loadMine |
| C6-09 | Privacy dialog / submitted-details panel | Acknowledgment and allowed details observable | Not reached in successful device registration due scope boundary | BLOCKED | Not substituted with historical G4 or backend setup results |
| C6-10 | Pending status / refresh | Status and refresh visible after sign-in | Pending account goes directly to QR; no status/refresh UI | FAIL | Both synthetic accounts; app ignores onRefresh callback in pendingBuilder |
| C7-01 | My Profile minimal identity | Show own student name and status | Profile route shows only My unverified QR; neither fictional name nor pending status shown | FAIL | Two account observations; app and PilotAccountScreen wiring |
| C7-02 | Profile unavailable/retry | Recover from failed own-profile retrieval | Dedicated failure state not induced under controlled device conditions | BLOCKED | Do not infer from historical backend tests |
| C8-01 | Camera grant | Preview starts after permission | Camera preview and actual fixture detection worked | PASS | Android permission granted=true; operator assistance + result hierarchy |
| C8-02 | Camera denial | Clear denial state and recovery | Permission prompt actions could not be correlated with resulting state; camera remained granted | BLOCKED | Automated and manual attempts inconclusive; not a PASS or app defect |
| C8-03 | Permanent denial | Explain Settings recovery without loop | Permanent denial not established | BLOCKED | No claim from source errorBuilder alone |
| C8-04 | Supported QR format | Recognize only format, not identity | RESQME QR FORMAT RECOGNIZED; UNVERIFIED — TEST PILOT ONLY | PASS | Operator positioned fictional fixture; independently captured UI hierarchy |
| C8-05 | Malformed QR | Safe invalid response; no raw payload | Operator reported safe invalid/unrecognized result after supplied malformed fixture | PASS | Operator-reported only; result not independently captured |
| C8-06 | Unrelated QR | Safe invalid response | Fixture prepared; physical trial not completed | BLOCKED | Parser test is separate local evidence |
| C8-07 | Damaged/obscured QR | Safe non-detection or rejection | Physical condition not exercised | BLOCKED | No simulated result counted |
| C8-08 | Repeated scan | One result at a time; Scan Again works | Same fixture recognized again after camera moved away/back; one modal observed | PASS | Operator confirmation and repeated-result hierarchy |
| C8-09 | Scanner background/resume | No duplicate result/crash | Existing result sheet survived Home/resume without duplicate navigation | PASS | Modal-preservation check only; not all live-preview lifecycle cases |
| C8-10 | Rapid camera movement | No frozen preview/crash | Physical stress condition not exercised | BLOCKED | No evidence |
| C8-11 | Low light | Safe behavior in low light | Physical lighting condition not exercised | BLOCKED | No evidence |
| C8-12 | Portrait scanner | Usable portrait scanner controls | Fixture scanning and result actions worked in portrait | PASS | Device dimensions and observed controls |
| C8-13 | Offline decoding | Decode without connectivity | Fictional fixture recognized with airplane mode on and default network none | PASS | Operator confirmation + independent Android/UI evidence |
| C8-14 | Scanner exit | Return to public dashboard | Back to Dashboard result action and app-bar Back worked | PASS | Device hierarchy; isolated system-back ambiguity not graded as defect |
| C9-01 | Public QR privacy | No student/medical/private token display | Only format/unverified explanations and safe navigation shown | PASS | Result hierarchy and parser/modal implementation; not an identity lookup |
| C9-02 | Tier 2 boundary | No biometrics or protected profile loading | Static restricted-information boundary displayed | PASS | tier2-boundary.png; boundary implementation |
| C9-03 | My QR | Own unverified QR rendered | Both account QR pages rendered black/white QR patterns without load error | PASS | In-memory pixel-region checks; no private QR image saved |
| C9-04 | My QR account separation | Avoid stale account QR | Rendered QR region differed between accounts; logout removed QR UI | PASS | In-memory region hashes; no claim of decoding or equal payload after restart |
| C10-01 | Slow network / timeout | Useful timeout and recovery | Offline error tested; controlled slow-network/request-timeout scenario not completed | BLOCKED | No global network throttling/configuration change |
| C10-02 | Rotation | Supported orientation behaves safely | Portrait verified; rotation not exercised | BLOCKED | Existing device orientation settings preserved |
| C10-03 | Rapid repeated button taps | Prevent duplicate requests/navigation | Controlled rapid-tap scenario not completed | BLOCKED | No claim based only on source busy flags |
| C10-04 | Crash/overflow smoke | No failure during observed actions | No fatal/unhandled/overflow markers in bounded current-process log sample | PASS | Sanitized log counts; not exhaustive all-session crash proof |
| E-01 | Initial demo walk-through | Complete requested sequence | Public sequence reached missing hotline directory; not complete | FAIL | Initial device observations; no full duration recorded |
| E-02 | Confirmation rehearsal | Second complete sequence without reset | Entry → dashboard → first aid → hotline reproduced same blocker; not complete | FAIL | rehearsal-confirmation.json; 16.67s includes automation overhead |
| CLEAN-01 | Synthetic cleanup | Delete only proven test resources | 2 Auth users + 6 exact document paths verified absent; private session file removed | PASS | account-cleanup.json |

## Prioritized defects and minimal remediation

Common environment for all findings: TECNO CN5 / Android 16; the exact debug staging APK/hash and dirty Git baseline above. No P0 was observed in the tested paths; this is not a complete security or crash audit.

### G5-001 — P1: Hotline card promises a feature that does not exist

- Steps: guest entry → dashboard → scroll → Emergency hotlines. Expected: approved public numbers and a safe, understandable dialer/confirmation route. Actual: “An approved public hotline directory will be added when its regional contacts are supplied”; no numbers/controls.
- Reproducibility: 2/2 observed visits, including the confirmation rehearsal. Evidence: [hotline screenshot](qa/g5-2026-11-09/hotlines.png), `lib/app/resqme_app.dart:97`, dashboard subtitle “One-tap access to emergency services.”
- Cause: verified route intentionally uses `Tier1PendingScreen`; this is incomplete functionality, not a backend outage.
- Minimal remedy: obtain approved regional data before implementing the existing directory/dialer slot; meanwhile accurately label it unavailable and exclude it from any claimed live calling demo. Do not invent numbers or place test calls.
- Demo impact: stops the requested hotline demonstration and undermines the dashboard promise.

### G5-002 — P1: Profile omits own name, pending status, and refresh

- Steps: sign in as an approved pending fictional student → Profile/account route; repeat with the other fictional account. Expected: own name, pending status, permitted QR, and an understandable refresh route. Actual: “My unverified QR,” warning text, QR, dashboard/scan/logout controls; no student name/status/refresh.
- Reproducibility: both synthetic accounts, plus persisted-session re-entry. Evidence: sanitized UI observation and source dependency path. `resqme_app.dart:47-61` supplies a custom `pendingBuilder`; it receives `onRefresh` but does not forward/use it. `StudentAccessGate:155-171` uses that builder instead of `RegistrationPendingScreen`; `PilotAccountScreen:35` selects QR for ordinary sign-in. This is verified routing, not a missing backend field.
- Minimal remedy: reuse the existing profile/status model and pending screen/callbacks in the Tier 1 account landing. Render only approved minimal identity/status alongside the QR route. Keep the submitted-details panel contract separate; do not expand public/profile exposure.
- Demo impact: presenter cannot show the named student/pending status or demonstrate status refresh as requested.

### G5-003 — P1 source-confirmed scope blocker: Successful registration automatically enters medical onboarding

- Steps in source: successful registration → `onRegistered()` sets `registrationCompleted=true` → custom pending builder passes `openMedical: registered` → `PilotAccountScreen.initState` selects medical → medical screen starts `loadMine()`.
- Expected: a safe Tier 1 pending/QR continuation under the approved three-Function scope. Actual implementation: medical-screen initialization and a medical read would occur. Reproducibility: deterministic source path; **successful device submission was deliberately not executed**, so no runtime failure is claimed.
- Evidence: `student_access_gate.dart:86,155-164`; `resqme_app.dart:53,61`; `pilot_account_screen.dart:35`; `synthetic_medical_screen.dart` initialization and `SyntheticMedicalRepository.loadMine`.
- Minimal remedy: keep Tier 1 successful registration on the existing pending/status/QR path. Do not initialize medical onboarding automatically in this scope. No medical implementation or backend deployment is needed for this routing correction.
- Demo impact: a new-student registration demonstration cannot currently be completed within the stated Tier 1 boundary. Test accounts were therefore set up through the approved Auth + registration callable solely to exercise safe device sign-in/QR flows; this is **not device registration acceptance**.

### G5-004 — P2: Empty first-aid search has no explanation

- Steps: open First-aid instructions → optionally choose Bleeding & wounds → enter `no-match-g5`. Expected: clear no-results feedback and a way to reset the query/filter. Actual: topic area becomes blank; no explanation. Reproduced twice (filtered and unfiltered).
- Evidence: [empty-search screenshot](qa/g5-2026-11-09/empty-search.png); filtered list renders only `for (final guide in guides)` with no empty branch.
- Minimal remedy: add a short no-results message and clear/reset control using current search/filter state. No new dependency or redesign.
- Demo impact: a typo can look like a broken library; presenter should use a known category/topic until fixed.

### G5-005 — P2: Large visual placeholders obscure useful guidance and advertise incompleteness

- Steps: open a first-aid guide or expand DRRM guidance. Expected: relevant readable guidance promptly. Actual: large “Instruction image / Reserved for a reviewed visual guide” or “Future action-plan image” areas before text.
- Reproducibility: first-aid sample and DRRM expansions. Evidence: [Asthma](qa/g5-2026-11-09/asthma.png), source placeholder strings; DRRM source.
- Minimal remedy: collapse/shrink the placeholder until reviewed artwork exists. Do not invent/change medical instructions or commission new material during QA.
- Demo impact: extra scrolling and obvious unfinished sections; no claim that the text itself was medically reviewed.

### G5-006 — P3: Debug/test ribbons overlap

- Steps: open entry on this debug build. Actual: top-right debug and TEST MODE banners overlap visually. Evidence: [entry screenshot](qa/g5-2026-11-09/startup.png).
- Minimal remedy: retain one clear staging indicator and suppress only the redundant Flutter debug ribbon in a separately approved presentation change. Preserve debug staging routing.
- Demo impact: minor visual distraction, not a functional/security failure.

## Usability review

Scores are 1–5 judgments grounded in the observed screens, not user-study statistics. Profile/QR scores rely on sanitized device hierarchy/text and the rendering check, because private QR screenshots were not retained. First-consent usability is UNVERIFIED.

| Screen | Clarity | Navigation | Readability | Feedback/recovery | Demo readiness | Observed reason for lower scores |
|---|---:|---:|---:|---:|---:|---|
| Scanner/guest entry | 5 | 5 | 5 | 4 | 4 | Clear public-first choices; overlapping debug ribbons |
| Dashboard | 3 | 3 | 4 | 3 | 2 | Restricted Tier 2 card leads the list; large header pushes public help/profile below fold; hotline promise inaccurate |
| First-aid library | 4 | 4 | 4 | 2 | 3 | Useful category filter; no empty-search explanation |
| First-aid detail | 4 | 4 | 4 | 3 | 3 | Readable text; large reserved image space; only bounded scrolling inspected |
| Hotline placeholder | 2 | 4 | 4 | 2 | 1 | Admits missing data only after navigation; no actual feature |
| DRRM | 4 | 4 | 4 | 3 | 3 | Clear headings and expandable content; future-image slots |
| Sign-in | 4 | 4 | 4 | 4 | 3 | Useful offline message; copy promises pending status that destination omits |
| Registration form | 3 | 3 | 4 | 3 | 1 | Long optional-contact form; success path crosses scope boundary |
| My Profile destination | 1 | 3 | 4 | 2 | 1 | Name/status/refresh absent; only QR landing is supplied |
| My QR | 4 | 4 | 4 | 3 | 3 | Strong unverified/privacy wording; requires network for fresh loading |
| Public QR result | 5 | 5 | 4 | 5 | 4 | Clear format-only warning and recovery controls; not verified identity |
| Tier 2 boundary | 5 | 4 | 4 | 4 | 4 | Clearly explains restriction without requesting biometrics/data |

As a first-time student, the public entry explains the purpose and next steps well. Emergency resources are discoverable, but dashboard hierarchy and the missing hotline feature weaken confidence. Error recovery is good for offline sign-in and repeat scanning, weak for an empty search, and unverified for camera denial/permanent denial. Loading did resolve on tested Auth/QR paths, but slow-network/timeout cases are not comprehensively verified. No wholesale redesign is recommended.

## Rehearsal evidence, measurements, and demonstration risks

- Initial public walk-through and a subsequent timed confirmation both encountered the hotline placeholder. **No two consecutive complete 8–12-minute rehearsals passed.** The confirmation covered entry → dashboard → first aid → hotlines and stopped at that blocker. It took 16.67 seconds including ADB/UI dump overhead, not a presentation duration.
- Android `am start -W` reported cold activity launch times of 4.232s, 3.244s, and 2.795s on observed launches (another permission-test launch was 3.813s). These are debug activity timings, not release performance or precise time-to-content/dashboard.
- Confirmation automation spans: guest/dashboard 5.22s, first-aid open 5.69s, hotline open 5.06s, each including UI hierarchy capture. These are **not isolated render/network latency measurements**. DRRM/open-screen latency, QR detection latency, and total full-demo duration were not reliably isolated. Do not infer performance regressions from these values.
- Network response timings were confounded by connectivity restoration and host transport failures. No invented timing thresholds or measurements are provided.
- No crash/overflow marker appeared in the bounded current-process log sample. This does not prove no past/intermittent crash across all processes.
- Highest live risks: absent hotline directory; registration route into medical scope; no named/pending profile; camera denial coverage incomplete; reliance on staging network for account/profile/QR; uncertain low-light/damaged-code behavior. Debug/test overlays and image placeholders are visibly unfinished.
- Offline decoding is verified. It does **not** imply a school enrollment/identity check, student-record retrieval, or an offline network lookup. The public scanner is intentionally local-only and must be presented that way.

## Recommended remediation order

1. **Must fix before claiming the complete school demo:** keep successful registration within Tier 1; expose the existing minimal own-profile/pending-status/refresh UI; resolve the hotline directory using approved regional contacts or formally narrow the demonstration scope and remove the unsupported one-tap claim. Recheck these paths on this exact device/build afterward.
2. **Should fix before the demo:** empty-search feedback; reduce placeholder space; complete camera denial/permanent-denial and remaining physical scanning tests; use reliable known network conditions and rehearsed fictional QR fixtures.
3. **Can improve after the demo:** redundant debug ribbon and other small visual polish; reviewed guidance artwork when supplied. No dependency/framework migration is warranted by this QA evidence.

Any fixes require a separate implementation task. After targeted fixes, run focused existing tests, rebuild debug staging in place, then complete successful device registration, profile/status/refresh, and two consecutive rehearsals without reinstall/reset. Preserve the established three-Function/Tier 1 boundary.

## Proposed 10-minute demo flow — conditional, not yet a passed rehearsal

| Time | Presenter action / expected behavior | Prerequisite / safe fallback |
|---|---|---|
| 0:00–1:00 | Launch; explain public emergency support and test-only status; Continue as Guest | Installed staging debug APK; existing consent. Do not reset data live. |
| 1:00–2:30 | Open first aid; choose a known topic; show readable local instructions | Works offline. Do not claim clinical validation or improvise medical advice. |
| 2:30–3:30 | Show DRRM Earthquake guidance and return | Works offline; explain image placeholders honestly until corrected. |
| 3:30–4:15 | Demonstrate approved hotline directory/dialer **only after G5-001 is resolved**; stop before calling | Currently a placeholder: state unavailable and skip. Never dial real emergency services. |
| 4:15–6:00 | Open scanner; scan a pre-rendered fictional fixture; explain format-recognized/UNVERIFIED result; Scan Again/return | Camera permission prechecked; second display/paper fixture ready. If scan fails, show previously reviewed public result wording and continue public resources—do not claim a live scan succeeded. |
| 6:00–8:15 | Sign in using a separately approved active demo account; show minimal name/status and own QR **after G5-002 is fixed** | Stable internet and an approved retained demo-account scope. G5 accounts were deleted; none remains for the school demo. No private QR screenshot as fallback. If network fails, keep the public/offline demo and explicitly defer account features. |
| 8:15–9:00 | Explain Tier 1/Tier 2 boundary using the static restricted screen | No medical record, biometrics, real student data, or verification claim. |
| 9:00–10:00 | Logout, confirm public entry/dashboard, recap offline versus network-dependent features | End with no account QR visible. Allow a small buffer; no repeated reinstall/restart attempts. |

## Synthetic resources, cleanup, and final device state

Two fictional students were provisioned through Firebase Auth and `createStudentRegistration` under the new explicit G5 approval. One was age 17 (`pending_guardian`), one age 19 (`pending_review`). Device sign-in triggered each own QR. This setup supported account QA and is not successful device-registration evidence.

For each alias `S1` and `S2`, the only permitted/created document paths were:

- `studentProfiles/{S}/acknowledgments/tier1-registration-v1`
- `studentProfiles/{S}`
- `studentQrCredentials/{S}`

All six paths were proven absent before creation. Exact UID/email ownership was checked before deletion. Cleanup removed only those resources, in acknowledgment/profile/QR order before the exact Auth user; final GET/lookup verified **six document paths and two Auth users absent**. Host DNS/connection/TLS failures interrupted early cleanup, and one partial document deletion was detected safely during recovery. A local QA-helper exception-handler naming collision was corrected; no application/configuration change resulted. After the operator confirmed stable computer connectivity, bounded recovery completed. No further account creation or replacement account occurred. Credentials and the exact UID/path session file were deleted after final verification. Sanitized outcome: [account-cleanup.json](qa/g5-2026-11-09/account-cleanup.json).

The app was signed out before hosted cleanup and returned to the public dashboard at the end. Camera permission is granted; denial/permanent-denial states remain unverified. The operator restored normal connectivity after the offline test. No uninstall or data clearing occurred; app-specific camera permission was revoked during QA attempts and ultimately left granted. No unrelated data, device configuration, or Firebase configuration was intentionally changed.

**Final verdict: NOT READY** for the complete requested school demonstration. The tested public/offline subset and account/QR sign-in smoke paths work, but known P1 product/scope gaps and incomplete physical coverage prevent a READY claim. This verdict does not overturn historical G4 backend acceptance.

## Hotline follow-up — implementation and device verification, 2026-11-09

The owner supplied the Urdaneta City/national contact directory and explicitly selected **confirmation → prefilled Phone dialer**, leaving the Phone app's Call button as the final action. This is the approved behavior; the app does not place a call automatically.

- Replaced the hotline placeholder with the supplied six categories, eight agencies, and all 12 telephone numbers. Numbers are reproduced from the owner-provided directory; independent currency/ownership verification was not claimed.
- Every number opens a confirmation showing the agency, selected number, Cancel, and Open Phone. Cancel/dismiss do not launch the dialer. Repeated taps are guarded. Failure to open a Phone app gives a manual-dial recovery message.
- The selected number is normalized only by removing spaces before creating the `tel:` URI. The existing `url_launcher` dependency opens the external Phone app. No new dependency or direct-call permission was added.
- NDRRMC displays “Ask for extension 100 after your call connects” in the directory and confirmation; no extension tones are sent automatically.
- TDD: new tests initially failed because the screen did not exist. After implementation, **9/9 focused widget/navigation tests passed**: complete number list, confirmation/cancel/repeated-tap guard, selected dialer URI, false/throwing launcher recovery, extension handling, and existing public routes. Targeted Flutter analysis: no issues found.
- Debug staging build passed with `RESQME_BACKEND=staging`; installation on TECNO CN5 / Android 16 succeeded in place without data clearing. Installed APK SHA-256 matched the built APK: `6edebee6c0fd951c03bcfd7f3e202badf48494de78d06f832071f91370597dc5`.
- Physical device: directory rendered; tapping 911 showed confirmation; Cancel stayed in ResQMe. Confirming CHO opened `com.sh.smart.caller` with `0755686114` independently observed in its UI. **No Call button was pressed and no actual call was attempted.** Returned safely to ResQMe. No Phone-app screenshot/contact history was retained.
- Evidence: [directory](qa/g5-hotlines-2026-11-09/directory.png), [confirmation](qa/g5-hotlines-2026-11-09/confirmation.png), [sanitized verification](qa/g5-hotlines-2026-11-09/verification.json).

**G5-001 hotline placeholder blocker: resolved on this follow-up APK.** Historical counts/rehearsal failures are not rewritten as passes. Profile/status/refresh and the registration-to-medical routing findings still require separate work; no full G5 readiness or completed rehearsal is claimed. No Firebase configuration, deployment, account creation, dependency change, commit, or push occurred in this hotline follow-up.

### Hotline mockup styling follow-up

Applied the phone-screen design from `docs/mockups/ResQme Mockup_page-0006.jpg`: centered white header with circular back control, dark emergency panel, red Call 911 action, muted directory label, rounded white cards, pale phone-icon badges, bold agency titles, and aligned red telephone actions. All 12 owner-supplied numbers and full agency names in confirmation dialogs are preserved. Multi-number cards adapt their height; narrow screens and enlarged text use a stacked layout. No reference-image sample number replaced the approved directory.

Validation: 12/12 focused hotline/navigation tests passed, including the emergency action's confirmation, compact agency labels, all supplied numbers, and a 320px layout at 1.8x text scale. Targeted analysis found no issues. Debug staging build/install passed in place; the installed artifact hash matched `e421a134a6c3b02cfe5418ac5506d1654c918259de6cf962a4ebbcd693aca300`. The updated screen was visually reviewed on TECNO CN5 / Android 16, then the new red Call 911 action was opened and cancelled on device. No call was attempted. Existing confirmed-Phone handoff logic is unchanged.

Evidence: [updated screen](qa/g5-hotlines-2026-11-09/mockup-aligned-screen.png), [hero confirmation](qa/g5-hotlines-2026-11-09/hero-confirmation.png), [verification record](qa/g5-hotlines-2026-11-09/mockup-ui-verification.json). This UI-only change does not close the remaining Profile/registration G5 findings.

## First-aid mockup styling follow-up

Applied `docs/mockups/ResQme Mockup_page-0005.jpg` to the first-aid library: centered white header, immediate-care heading, rounded search input and red search action (search icon instead of camera), guide count, rounded expandable guide cards, pale condition icons, shaded introductory guidance, and numbered instruction presentation. The first guide starts expanded to match the reference's hierarchy. Existing full-guide navigation is retained through Open full guide. Category filtering is available from a compact filter menu.

The original 10-guide data and full-guide implementation were checked against the pre-change source and are unchanged. Clinical text, symptoms, and warning/avoid advice from the mockup were not substituted for existing content. No medical advice was invented. The empty-results panel now explains a no-match query and can clear both search and category filters.

Validation: 8/8 focused first-aid/navigation tests passed, including search/reset, category filtering, enlarged text at 320px, and complete-guide navigation. Targeted analysis: no issues. Debug staging build and in-place installation passed. Installed APK matched `9c194f88d5f3e8f966668a5e688b5cb3a6e4eb62984a3506d89974c0f6d7b87f`. The screen was visually reviewed on TECNO CN5 / Android 16; the search button returned Nosebleed, a no-match query showed the recovery panel, and Clear search & filters restored all 10 guides. No account, Firebase, dependency, medical-data, commit, or push operation occurred. G5-004 empty-search feedback is resolved on this APK; remaining account/registration G5 blockers are not addressed.

Evidence: [updated first-aid screen](qa/g5-first-aid-2026-11-09/mockup-aligned-screen.png), [empty-search recovery](qa/g5-first-aid-2026-11-09/empty-search.png), [verification](qa/g5-first-aid-2026-11-09/verification.json).

## DRRM grid and action-plan mockup follow-up

Applied `ResQme Mockup_page-0007.jpg` to the DRRM directory and `ResQme Mockup_page-0008.jpg` to hazard selection. The directory has a centered white header, red preparedness label, prominent heading, rounded two-column shield cards and responsive single-column fallback for small/enlarged-text layouts. Existing search is retained through Search hazards, including no-results recovery. All ten existing hazards remain; the eight corresponding reference hazards appear first, with Drought and Transportation retained afterward.

Selecting a card opens a dimmed/blurred modal with a dark action-plan header, full hazard name, numbered original guidance sections, Close and I understand actions. Both actions dismiss only the modal; they create no consent record, account, or backend write. The original Before/During/After or transportation paragraphs are preserved rather than replaced with the mockup's shorter sample instructions. The ten-hazard guidance map was checked against the original source and is unchanged. The former image placeholder is not used in the new action plan.

Validation: 8/8 focused DRRM/public-navigation tests passed, covering all ten selections, selected guidance, both dismissal actions, search, empty-search reset, and a 320x568 layout at 1.8x text scale. Targeted analysis: no issues. Debug staging build and in-place installation passed; installed APK matched `c3644c06c5e5d63af86f319902f3c77a51d3ddd1a70c6cb316df32858d888232`. The grid and Earthquake modal were visually reviewed on TECNO CN5 / Android 16; both dismissal actions restored the grid. A floating notification overlay was dismissed before saving clean previews. No Firebase, account, dependency, commit, or push operation occurred. Remaining registration/profile G5 blockers are unchanged.

Evidence: [hazard grid](qa/g5-drrm-2026-11-09/hazard-grid.png), [action plan](qa/g5-drrm-2026-11-09/action-plan.png), [verification](qa/g5-drrm-2026-11-09/verification.json).

## App name, launcher logo, and debug-ribbon follow-up

Set the Android launcher label, Flutter application title, and public entry title to ResQme. Removed only Flutter's DEBUG ribbon via `debugShowCheckedModeBanner: false`; the staging TEST MODE indicator remains. Generated Android launcher PNGs at 48/72/96/144/192px from the supplied `assets/App logo/resqme_logo.png`, preserving the original asset and application ID. No dependency or Firebase configuration changed.

Validation: 8 existing app/navigation tests passed; targeted analysis found no issues. Debug staging build and in-place device installation passed. APK metadata reports application label ResQme and the five launcher-density resources. The installed artifact matched `578930b2eb3c59d54d2a11da55b783f1c65b6b3606853a789c50400adc501b6e`; the TECNO entry screen was visually reviewed, showing ResQme and TEST MODE without the DEBUG overlay. G5-006 overlapping ribbons is resolved.

Evidence: [entry screen](qa/g5-branding-2026-11-09/entry-screen.png), [launcher icon](qa/g5-branding-2026-11-09/launcher-icon.png), [verification](qa/g5-branding-2026-11-09/verification.json).

## Splash mockup and supplied logo follow-up

Applied `ResQme Mockup_page-0001.jpg` to the Flutter splash: red field, clipped subtle rings, centered white logo badge, RESQME / QR ID wordmark, emergency-identity tagline and three loading dots. Replaced the sample logo with the owner-supplied ResQme artwork. A 512px, 93,351-byte display copy is bundled; the original 10MB source PNG is untouched. Decode size is bounded for the small displayed logo. Existing consent-based routing and startup timing logic are unchanged; no artificial minimum display time was introduced.

Validation: 7/7 startup/navigation tests passed, including held-consent routing to both Terms and Entry; targeted analysis found no issues. The loading-state layout was visually reviewed using a Flutter-rendered preview with a controlled pending consent lookup; this is not a timed device screenshot. Debug staging build and in-place installation passed; installed APK matched `cccc7a3aaf2f427c1f886c5a57380efd41bb9ef4e722de2ce194c3737e52de8d`. Device cold start reached the public entry using existing accepted consent. The packaged asset size/path were independently checked. No Firebase, dependency, account, commit, or push operation occurred.

Evidence: [rendered loading-state preview](qa/g5-splash-2026-11-09/rendered-loading-preview.png), [verification](qa/g5-splash-2026-11-09/verification.json).


## 2026-11-10 ? Scanner-first entry UI

Owner selected UI-only scope: preserve current authentication and unverified QR behavior. The entry now follows the dark scanner mockup with a framed camera placeholder, Enable Camera, Go to Dashboard as Guest, and Register. There is no entry Sign In button; dashboard Profile retains existing account access. Opening the entry does not start the camera. Enable Camera opens the existing scanner. Consent routing, QR parsing, backend permissions, and Tier 2 access are unchanged.

Validation: 27 focused widget/navigation tests passed, including narrow-screen/enlarged-text layout, consent routing, scanner-to-dashboard, account preservation, registration routing, and Profile/logout coverage. Analysis reported no issues. The first staging debug build was installed successfully and the entry was visually inspected with all three actions visible. A follow-up corrects system status-icon contrast. Subsequent physical navigation checks were not completed because ResQMe was no longer inspectable through the device connection; automated results are not physical acceptance. No synthetic accounts or hosted records were created.

The final staging debug APK, including the status-icon contrast correction, built successfully and installed with `adb install -r` (Success). App data was preserved. Physical navigation acceptance remains pending.


## 2026-11-10 ? Live scanner inside entry

Owner requested the entry itself work as the scanner. Enable Camera now mounts the existing QR scanner inside the square viewfinder without pushing a scanner route; Disable Camera removes it. Guest/Register dispose the embedded camera before navigation, and returning leaves it disabled. The standalone scanner remains available to existing dashboard/account routes. Camera permission/error feedback and retry render within the entry frame. Existing lifecycle, offline parser, duplicate-result guard, unverified modal, and Scan Again handling are reused. No QR authentication or Tier 2 lookup was introduced.

Validation: 35 focused navigation, scanner, modal, and parser tests passed. Tests verify same-screen activation/deactivation, disposal before Guest navigation, and camera remaining disabled on return. No hosted accounts, records, API settings, Rules, IAM, or dependencies changed.

Analysis found no issues; the staging debug APK built and installed successfully with app data preserved. Physical preview verification remains pending: the UIAutomator snapshot failed through ADB after launch, so no camera-on-device pass is claimed.
