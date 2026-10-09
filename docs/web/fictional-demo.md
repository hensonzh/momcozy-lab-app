# Fictional Web demo (B App)

The public Web demo is a **separate static artifact and site**. It is not an
online account service and is not an Android/iOS release. It reuses the current
Flutter Me, Baby, Schedule and Agent Hub pages but never boots the mobile
`lib/main.dart` entrypoint. Build from `lib/main_web_mock.dart` only.

## Supported and disabled

| Surface | Demo behavior |
| --- | --- |
| Me | Mia's fictional profile and example records; manual edits stay in this tab's memory. |
| Baby | Luna's fictional profile, feeding/diaper/growth examples and manual record edits stay in memory. |
| Schedule | Add, edit and remove personal demo items in memory. |
| Momcozy AI | Scripted, deterministic text events; no model, tools, uploads or action execution. |
| More | Demo explanation, feature limits, no account management. |
| Reset demo | Recreates all in-memory state and returns to Me. Browser refresh and a separate tab also reset. |
| Bluetooth / camera / live video / notifications / native push / uploads / account / media assets | Not available. Unknown routes and API operations reject or show a demo-unavailable screen. |

The website has no registration, login, Product Backend, Agent, shared database,
analytics or cross-device storage. It does **not** promise per-person private
isolation or persistence. Do not type personal information: a Web browser and
its extensions remain outside this application's control.

## Local verification

Use pinned Flutter 3.44.4 / Dart 3.12.2 and Node >= 20:

```sh
cd app
flutter pub get
npm ci --ignore-scripts
npx playwright install chromium
flutter test --no-pub test/web_demo
flutter analyze --no-pub
MOMCOZY_WEB_DEMO_BASE_HREF=/momcozy-ai-web-demo/ bash scripts/build-web-demo.sh
MOMCOZY_WEB_DEMO_BASE_HREF=/momcozy-ai-web-demo/ npm run test:web-demo
```

For the root path `/`, omit `MOMCOZY_WEB_DEMO_BASE_HREF` in both commands.
The browser test serves the built bundle, exercises navigation, writes, reset,
refresh, another tab and scripted chat at 390 px, plus 1280 px desktop. It
**aborts and fails on every cross-origin request**, missing local asset and
uncaught browser error. `web_demo/index.html` additionally applies a strict
Content Security Policy with `connect-src 'self'` and `form-action 'none'`.
The build gate removes Flutter's legacy service worker, internal CA and mobile
`version.json`, and hosts CanvasKit and fallback fonts locally.

## CI and publication

`.github/workflows/web-demo.yml` is an independent source/PR/dispatch CI gate
that produces a **verified static artifact only**; it has no production
credentials and does not deploy a B service or change TestFlight/Play.
After the workflow succeeds for the intended source SHA, release the artifact
to a **separate** public static hosting repository (for example a dedicated
GitHub Pages repository) with its own base path. Do not enable Pages for the
App source repository by accident, do not reuse the A/B APK download pages,
and do not expose any mobile signing keys, Product or Agent secrets. Deploying
or updating the public site is a separate, controlled operation. Verify the
public page, `/404.html` navigation fallback, CSP, the script response and
browser network from the live origin. Never say “published” before these
checks and a known URL are confirmed.

Rollback by reverting the static site artifact; mobile binaries and business
services are out of scope. The demo must remain visibly labelled **fictional**.
