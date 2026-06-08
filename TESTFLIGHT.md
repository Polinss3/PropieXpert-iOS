# TestFlight Checklist

## Project Status

- Scheme: `PropieXpert`
- Bundle ID: `com.propiexpert.app`
- Team ID: `6U4MD8PQ2L`
- Minimum iOS version: `16.0`
- App Store Connect app record: configured
- Distribution certificate: `Apple Distribution`
- Google Sign-In package: configured
- Google URL scheme: configured
- Privacy manifest: configured
- JWT storage: Keychain-backed session configured
- App icon: temporary placeholder configured

## Local Archive

From `PropieXpert-iOS/PropieXpert`:

```bash
xcodebuild archive \
  -project "PropieXpert.xcodeproj" \
  -scheme "PropieXpert" \
  -destination "generic/platform=iOS" \
  -archivePath "../build/PropieXpert.xcarchive" \
  -allowProvisioningUpdates
```

## Export IPA

```bash
xcodebuild -exportArchive \
  -archivePath "../build/PropieXpert.xcarchive" \
  -exportPath "../build/export" \
  -exportOptionsPlist "TestFlightExportOptions.plist" \
  -allowProvisioningUpdates
```

## Upload

Command-line upload succeeded with `signingCertificate = Apple Distribution`. After upload, wait for the build to finish processing in App Store Connect > TestFlight.

The simplest path is Xcode Organizer:

1. Open Xcode.
2. `Window > Organizer`.
3. Select the `PropieXpert` archive.
4. Click `Distribute App`.
5. Choose `App Store Connect`.
6. Upload and wait for processing in TestFlight.

## Pending Before External Testers

- Replace the temporary icon with the final brand icon.
- Confirm App Store Connect app record exists for `com.propiexpert.app`.
- Complete App Privacy answers in App Store Connect.
- Test Google login on a real device.
