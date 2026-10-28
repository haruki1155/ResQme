# ResQMe

ResQMe is an Android-first QR-based Student Emergency Support System. This
repository currently contains the Tier 1 A0 foundation for controlled pilot
testing with synthetic data.

## A0 local staging checklist

This app is configured only for the staging Firebase project:

- Firebase project: `resqme-943ee`
- Android application ID: `com.example.resqme`
- Authentication emulator: `9099`
- Firestore emulator: `8080`
- Functions emulator: `5001`
- Emulator UI: `4000`

Before running a debug app, complete each step:

1. Install and build the local Functions scaffold.

   ```powershell
   Set-Location functions
   npm.cmd install
   npm.cmd run build
   Set-Location ..
   ```

2. Start the local Emulator Suite in a separate terminal.

   ```powershell
   firebase.cmd emulators:start --only auth,firestore,functions,ui
   ```

3. Start an Android emulator, then run the debug app from the repository root.

   ```powershell
   flutter emulators
   flutter run -d <android-device-id>
   ```

Debug builds configure Auth, Firestore, and Functions to use the local
emulators before any client request. Do not run this application as a
production client, and do not deploy Firebase resources from this repository.

## Validation

```powershell
flutter analyze
flutter test
firebase.cmd emulators:exec --only auth,firestore,functions "flutter test"
flutter build apk --debug
```

The Tier 1 A0 foundation has no QR payloads, student records, medical data, or
server endpoint. Tier 2 medical access is not implemented.
