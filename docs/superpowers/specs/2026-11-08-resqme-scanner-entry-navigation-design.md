# ResQMe scanner-entry navigation design

Date: 2026-11-08
Status: Owner approved on 2026-11-08; implemented locally.

## Flow

Splash checks saved Terms acceptance. Unaccepted users see Terms & Privacy; successful persistence opens Scanner Entry. Previously accepted users open Scanner Entry directly.

Scanner Entry is a small screen with four actions: Scan QR, Continue as Guest, Register, and Sign In. It does not automatically request camera permission.

- Scan QR opens the existing offline camera scanner. A recognized format remains explicitly UNVERIFIED; its dashboard action navigates to Public Dashboard, rather than merely popping to Scanner Entry. Invalid results allow retry or guest dashboard access. Scanning never signs in, switches accounts, or reads student data.
- Continue as Guest opens Public Dashboard without Firebase availability.
- Register opens the existing registration form directly. Successful registration proceeds through the existing optional synthetic medical step (Save or Skip) to My QR, then Public Dashboard. QA restrictions and pending statuses remain unchanged.
- Sign In opens the existing email/password form. Successful sign-in opens My QR directly for an existing pending profile, including accounts without a previously issued QR. Authentication-created/profile-incomplete recovery remains available; failed or unknown profiles stay restricted.

The dashboard Profile navigation opens My QR for the authenticated pending user. Guests receive Sign In with Register available. Tier 1 My QR shows the unverified QR, Scan another QR, Logout, and a dashboard action; it does not expose personal details, registration detail screens, or medical editing controls. Optional synthetic medical entry is confined to the registration path for this flow. Logout clears authentication and returns to Scanner Entry; failure must remain visible without claiming sign-out succeeded.

Terms remain remembered rather than requiring acceptance on every launch. App restart always returns through Splash to Scanner Entry, even with a retained authenticated session. Back navigation must not strand users on a blank route; entry and account recovery retain public-resource access.

## Approach

Use the existing named-route navigation, authentication repository, access gate, medical form, QR repository and camera screen. Add one entry screen and explicit registration/sign-in route intents. Carry registration-vs-sign-in intent through the existing gate so successful registration still offers medical information while ordinary profile/sign-in navigation goes directly to My QR.

Alternative considered: make the camera itself the initial screen. A separate entry screen matches the four branches in the supplied diagram and avoids immediately requesting camera access. No new router, state-management package, authentication scheme, or backend is required.

## Verification

Add route/widget tests first for both consent paths, four entry actions, guest escape when backend is unavailable, registration success through Save/Skip, existing-account sign-in directly to My QR, private-data-free Profile, scanner dashboard destination, and logout success/failure. Preserve partial-registration recovery, pending-account restrictions and public emergency route tests. Run focused tests, full Flutter tests, analyzer, debug APK build and diff check. Physical camera and hosted backend acceptance remain separate.

## Boundaries

Local navigation/UI changes only. No hosted Firebase access, deployment, permission changes, QR authentication, Tier 2 implementation, hotline implementation, or alterations to server contracts. Preserve existing unrelated dependency and generated-plugin changes.
