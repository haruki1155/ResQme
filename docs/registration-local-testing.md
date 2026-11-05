# Registration local testing and acceptance

Use synthetic accounts only. No deployment, real-data import, QR issuance, guardian verification or school approval is implemented.

## Local configuration

The debug app uses a named `resqme-local` Firebase app with project `demo-resqme`. Auth, Firestore and Functions connect to `127.0.0.1` on ports 9099, 8080 and 5001. Automatic Android host mapping is disabled. Private profile reads require a server response; disk persistence is disabled. Release/profile builds retain public features without initializing this registration service.

Before starting services, inspect port ownership. Reuse a compatible running session; never stop an unidentified listener. Build Functions before starting the suite:

```powershell
npm.cmd --prefix functions run build
$env:CI = 'true' # Suppress the Firebase CLI public update/MOTD lookup.
firebase.cmd emulators:start --config firebase.integration.json --project demo-resqme --only auth,firestore,functions
```

Wait for the callable `createStudentRegistration` to initialize; an open port alone is insufficient. In another terminal:

```powershell
$env:GCLOUD_PROJECT = 'demo-resqme'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:5001'
npm.cmd --prefix functions run test:integration
npm.cmd --prefix functions run test:rules
```

The integration command deliberately does not build watched output. After source changes, rebuild once and wait for discovery before testing again. Preserve startup/test logs; stop only the suite you started.

## Android connection

Attach a debug phone/tablet or Android emulator, select its serial explicitly, then forward loopback ports:

```powershell
adb -s <serial> reverse tcp:9099 tcp:9099
adb -s <serial> reverse tcp:8080 tcp:8080
adb -s <serial> reverse tcp:5001 tcp:5001
flutter run -d <serial>
```

The debug-only network security policy permits HTTP only to loopback. These forwards do not start Firebase emulators. If any service is unavailable, keep the account restricted and use the public dashboard.

## Synthetic acceptance checklist

- Public Splash → Terms → dashboard, first aid, DRRM and current hotline destination remain reachable without signing in. The hotline directory remains the existing unavailable placeholder.
- Student Account opens sign-in and Create account. Validate required fields, optional contacts and secondary contact pairing.
- Checkbox starts unchecked; closing or declining creates no Auth user/profile. Review shows the complete supplied disclosure and notice version. Under-18 wording explicitly separates acknowledgment from guardian authorization.
- Register synthetic ages 17 and 18: guardian pending and school-review pending respectively. Neither receives QR or Tier 2 access.
- Simulate callable failure after Auth creation; retain restricted state, retry the form with the same authenticated account, confirm no duplicate Auth user or acknowledgment.
- Test repeated taps, incorrect credentials, password reset, sign-out, offline/reconnect, refresh and background/resume. Review submitted details is owner-only and initially collapsed; sign-out removes details.
- Inspect narrow phone, tablet, enlarged text and keyboard visibility. Record actual native screenshots and results before device acceptance is marked passed.

## Remaining release/design gates

Node 24.18.0 is used for local tests; Node 22 deployment parity is unverified. No device was attached during implementation, so native phone/tablet and Flutter-to-emulator acceptance remain pending. School privacy/retention review is required before real data. Proposed backend `emailNormalized`, `ageCategoryAtRegistration`, `updatedAt` and additional acknowledgment metadata remain outside the bounded contact-field reconciliation; existing acknowledgment uses a versioned document ID and server timestamp.

QR Phase Q0 requires owner decisions on trusted approval authority, exact public response fields, opaque identifier/token format, expiry/rotation, lost-ID lock/replacement/reactivation policy, print/save/share policy, staff tenant roles and step-up authentication, audit retention, and scanner offline/permission states. Design approval does not authorize issuance or Tier 2 work.
