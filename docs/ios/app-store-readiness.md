# momcozy AI — iOS App Store readiness

Last verified: 2026-09-24

## Scope

- Flutter project: this repository
- Store-facing name: `momcozy AI`
- Intended release: a new App Store app, not an update to an existing Momcozy listing
- Bundle ID: pending company confirmation
- No Apple App ID, App Store Connect record, certificate, profile, TestFlight upload, or review submission was created during this preflight

## Completed locally

| Check | Result |
| --- | --- |
| Flutter version | 3.44.4 / Dart 3.12.2 |
| Xcode version | 26.6 (17F113) |
| Formatting | 615 files checked, clean |
| Static analysis | `flutter analyze --no-pub`, clean |
| Security/privacy script | Passed after replacing a stale check for a removed Agent voice file with the active Motion voice transport checks |
| Non-visual tests | 816 passed across 132 `*_test.dart` files |
| Native branding test | Passed for Flutter, iOS, and Android display name `momcozy AI` |
| iOS device build | Release, arm64, no code signing, succeeded |
| Minimum iOS version | 15.0 |
| App icon asset shape | Complete iPhone/iPad slot inventory; 1024×1024 marketing file has no alpha |
| Legal links currently used by login UI | Terms and privacy pages both returned HTTP 200 on 2026-09-24 |

## Local unsigned build

The build is a compiler/archive preflight only. It cannot be installed on a physical device or uploaded to App Store Connect because it is unsigned.

- App: `build/ios/iphoneos/Runner.app`
- Zip: `build/ios/preflight/momcozy-ai-ios-unsigned-1.0.0-57.zip`
- Zip SHA-256: `96d8e2db9bbe61e03653fdefb04e3224cdcc875d2632431500105eb2c43ff944`
- Zip size: approximately 81 MB
- App size: approximately 121 MB on disk
- Architectures: arm64
- Version compiled for preflight: `1.0.0 (57)`
- Display name: `momcozy AI`
- SDK: iPhoneOS 26.5
- Test API endpoints were compiled into this artifact. It is not a production candidate.

Build command:

```bash
flutter build ios \
  --release \
  --no-codesign \
  --no-pub \
  --build-name=1.0.0 \
  --build-number=57 \
  --dart-define=MOMCOZY_ENV=staging \
  --dart-define=MOMCOZY_API_BASE_URL=https://backend-test.lute-momcozylab.luteos.cloud:8443 \
  --dart-define=MOMCOZY_AGENT_API_BASE_URL=https://agent-test.lute-momcozylab.luteos.cloud:8443
```

## Known release blockers

### 1. Final Bundle ID

The unsigned build still uses the temporary engineering identifier:

```text
com.momcozymai.app.flutterpoc
```

Do not register or publish this identifier unless the company explicitly approves it. The final explicit Bundle ID must be used consistently in Apple Developer, App Store Connect, Xcode, Firebase, Google OAuth, APNs, and any universal-link configuration.

### 2. Apple signing and App Store Connect access

The local machine currently has:

- no valid Apple Development or Apple Distribution signing identity;
- no provisioning profile;
- no configured App Store Connect API key;
- no Xcode team selected in the project.

An Admin or App Manager must create the new App Store Connect app. A team administrator must also grant the developer access to Certificates, Identifiers & Profiles or provide managed signing.

### 3. Production service endpoints

The final Product API and Agent API HTTPS endpoints are not confirmed. A store build must not use loopback or the current test endpoints unless it is deliberately a private TestFlight build and the security/trust setup is approved.

### 4. App icon and launch experience

The current iOS 1024×1024 App Store icon is still the default Flutter logo. It is technically valid but not store-ready for `momcozy AI`.

The launch image files are transparent 1×1 placeholders, so the launch screen is effectively a plain white screen. Brand-approved iOS icon and launch treatment are required before submission. Do not upscale the 192 px Android launcher icon as the final 1024 px App Store artwork.

### 5. Google and Apple login

The app currently exposes Google login and email/password login. The unsigned build resolved the Google callback URL scheme to an empty string because the iOS OAuth configuration is absent.

Before release, choose one path:

1. keep Google login, configure its iOS OAuth client, and add Sign in with Apple; or
2. hide Google login in the first iOS release and ship email/password only.

The selected path must be reflected in the review notes and privacy disclosures.

### 6. Push notifications

The iOS project declares production push entitlements and `remote-notification` background mode, but no real Firebase/APNs project is configured. Before release, either:

- configure the Firebase iOS app, APNs authentication key, app credentials, and a real-device delivery test; or
- remove/disable push capability and background mode for the first release.

### 7. Payment classification

The app contains a Stripe checkout path for care-service purchases. Legal/product must confirm that every externally paid item is a synchronous one-to-one person-to-person service. Digital content, AI features, subscriptions, group sessions, or feature unlocks may require Apple in-app purchase.

### 8. Privacy policy and App Privacy answers

The login screen currently links to:

- `https://momcozy.com/pages/privacy-security`
- `https://momcozy.com/pages/terms-conditions`

Both links are reachable, but legal must confirm that they specifically cover this app's AI conversations, maternal and baby health data, media uploads, voice/video consultation, motion camera processing, push tokens, account deletion, service providers, retention, and cross-border processing.

See `app-privacy-draft.md` for the code-derived inventory.

### 9. Visual regression review

The complete `flutter test` run produced:

- 1,614 passes;
- 6 skips;
- 250 failures.

Most failures are stale Golden image differences, reproduced in isolation. They affect many screens and are not caused by code-signing or iOS compilation. They must be reviewed intentionally; do not bulk-accept all Golden changes without visual approval.

The non-visual suite, selected by excluding test files containing `matchesGoldenFile`, passed all 816 tests.

### 10. iPad decision

The project currently targets both iPhone and iPad (`UIDeviceFamily` 1 and 2) and allows iPad landscape orientations. Before submission, either:

- keep iPad support, test all release-critical flows on iPad, and prepare required iPad screenshots; or
- deliberately change the target to iPhone only and regression-test that decision.

## Build observations

- The unsigned app embeds privacy manifests supplied by Flutter, WebRTC, Firebase, Google Sign-In, and several Flutter plugins.
- No app-owned `PrivacyInfo.xcprivacy` currently exists. Generate and review the Xcode privacy report from the signed archive before submission, then add an app-owned manifest if the app's own required-reason API use or declared data practices require it.
- Camera, microphone, and photo-library usage strings are present in Chinese.
- No Core Location usage description is declared.
- No ad/analytics/ATT SDK was found in the Flutter dependency and source audit. Backend and third-party processing still require separate confirmation.

## Required sequence after Bundle ID confirmation

1. Register the explicit Bundle ID and enable only required capabilities.
2. Create the App Store Connect app and assign this developer access.
3. Update Xcode Bundle ID and Development Team.
4. Choose the final build number after checking App Store Connect.
5. Configure production API endpoints.
6. Finalize login, push, payment, icon, launch screen, privacy policy, and App Privacy answers.
7. Create a signed archive and inspect Xcode validation/privacy reports.
8. Install on real iPhone and, if supported, real iPad; test login, deletion, camera, microphone, media upload, consultation, payment, notifications, and poor-network recovery.
9. Upload to internal TestFlight first.
10. Complete metadata/screenshots/review account, then submit for review.
