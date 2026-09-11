# App notification module

The shared `NotificationCoordinator` connects the existing API Runtime,
ChangeNotifier inbox, OS permission adapter, Firebase Messaging gateway,
installation secure store and GoRouter. Production notification behavior uses the
same `features/notifications` inbox as before; it does not maintain a separate
local copy of push messages.

- Startup only checks permission. First reminder opt-in explains the purpose,
  requests OS permission once, registers a device, then enables a backend task.
- Startup/resume/settings/reminder operations refresh OS truth. Denial goes to
  settings; restoring permission reloads the backend reminder state.
- Account/login-session changes immediately clear the inbox and old system
  alerts. Baby selection, locale changes and token rotation preserve the binding;
  same-session runtime rebuilds replace repository dependencies without detaching
  the installation or discarding the account-wide inbox. Async generations
  prevent a previous session's result from repopulating the UI.
- Installation identity/secret/revision and pending notification IDs are stored
  with FlutterSecureStorage. Logout preserves the device token and reserves the
  detach revision so the next session can register on its first attempt.
- Foreground banners require the current binding. Background/cold clicks are
  saved before opening, survive login/expired sessions, and resolve through the
  authenticated backend. Only a small set of resource routes is accepted.
- The notification center supports server unread totals, cursor paging, read-all,
  single read/archive, retry and empty/loading states. More shows the unread
  count; iOS badges also receive the server count in push envelopes.
- The settings page separates service categories from marketing. Booking and
  appointment details display reminder status independently of booking success.

Firebase client configuration uses the four empty fields in
`notification-firebase-defines.example.json`; copy it to a private local build
configuration and supply it with `--dart-define-from-file`. Register the exact
flavor package ID and iOS bundle ID. Server service-account private keys never
belong in the App. Missing client or server provider configuration means
background notifications are unavailable; the inbox still works.

The selected Firebase SDK requires iOS 15+. Android service notifications use the
`service_updates` channel. Existing pump foreground/local notifications keep
their separate purpose and are preserved when account alerts are cleared.

Backend architecture, migration, task and token state flows, complete API and
business trigger tables, worker operations and provider handoff are documented
in the workspace's `backend/docs/notification-operations.md` and acceptance
matrix `backend/docs/notification-module.md`.

Local verification (2026-09-10): Flutter full suite **957 passed**, full analyzer
clean, API contract checker passed, and Android local/debug arm64 build passed.
All Runner Swift files also pass type checking against the real Flutter/UIKit
frameworks for an iOS 15 simulator; Info.plist, entitlements and the Xcode project
pass plist lint. The notification settings entry point is guarded at iOS 16,
with the application settings entry point used on iOS 15.

The complete iOS simulator build remains unverified: SwiftPM's official Firebase
SDK download stalled, and a source download retry timed out. Native type checking
does not substitute for the full Firebase link/build or device acceptance.

The default Maven AAPT2 failed to start on this Mac; this smoke build used the
installed SDK 36.1.0 executable via the process-local
`ORG_GRADLE_PROJECT_android.aapt2FromMavenOverride` variable. No project or global
Gradle override was persisted. The Android Gradle plugin supports this local
executable override ([upstream implementation](https://android.googlesource.com/platform/tools/base/+/213bb9dfc9fc4dc8a1e47b17d356dd2b474717cb/build-system/gradle-core/src/main/java/com/android/build/gradle/internal/res/Aapt2FromMaven.kt)).

No real Firebase/APNs project is configured yet. Provider delivery, physical device
lifecycle behavior, iOS signing and cloud deployment require later acceptance.

## Review fixes — 2026-09-11

After OS permission has been confirmed, `FirebasePushMessaging.token()` first
enables auto-init. The installed `firebase_messaging` 16.6.0 iOS implementation
starts `registerForRemoteNotifications` from that call; checking APNs first would
leave a fresh installation unable to register. The gateway then polls APNs for
up to two seconds before requesting FCM. If APNs is still unavailable, it returns
pending and the token-refresh listener or a later explicit sync can retry. Startup
still does not request authorization, and logout pauses auto-init. See the
[FCM initialization and APNs guidance](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

The App now uses the runtime controller's login generation and user ID for the
notification binding key. An explicit new login advances that generation even
for the same user; token rotation and baby selection do not. Replacing clients
within that session keeps the installation, inbox and pending sends intact,
including when the first notification startup is still in progress.

Regression tests are in `test/features/notifications/firebase_push_messaging_test.dart`,
`test/features/notifications/notification_coordinator_test.dart`, and
`test/app/notification_runtime_test.dart`. They cover first APNs registration,
delayed readiness, bounded pending/retry, Android behavior, same-session client
replacement, startup races, baby selection after token refresh, a new login to
the same account, logout and account switching. The key reproductions failed
before the fixes. SDK responses and the server are controlled test adapters;
real APNs/FCM delivery is still unverified.

Verification: seven new regression tests; the focused notification/runtime/auth
run passed **50 tests**, and the full Flutter run passed **964 tests**. Full
`flutter analyze` is clean. Logs are
`/tmp/momcozy-notification-review-targeted.log`,
`/tmp/momcozy-notification-review-full.log`, and
`/tmp/momcozy-notification-review-analyze.log`.

The Android artifact and native Swift checks described above are from September
10. No new mobile package, deployment or live provider call is part of these
review fixes.

Follow-up verification (2026-09-11): both review fixes remain present in the
current worktree. Re-running all notification tests plus the App notification
runtime, API runtime, session and account-session lifecycle tests passed
**68 tests**. Static analysis of these tests and the notification/runtime source
passed. Full App analysis currently reports two informational missing-brace
findings in unrelated Me UI tests (`lactation_test.dart:214` and
`mother_forms_design_test.dart:105`). These are fresh targeted results, separate
from the earlier 964-test full-suite result above. No additional notification
source changes were needed in this verification.
Logs: `/tmp/momcozy-notification-review-verify.log`,
`/tmp/momcozy-notification-review-verify-focused-analyze.log`, and
`/tmp/momcozy-notification-review-verify-analyze.log`. Real FCM/APNs delivery
remains outside this local verification.
