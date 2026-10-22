# Flutter CI and regional staging delivery

Updated: 2026-10-20. App release artifacts are built only from validated
`main` commits. Development branches are not publication sources. A signed
build is not a store upload, review approval or tester invitation.

| Target | Build configuration | Distribution |
| --- | --- | --- |
| Local | `config/environments/local.json`, Android `local` | Emulator/developer machine only |
| Singapore staging | `config/environments/staging.json`, Android `staging` | Signed invite APK after Product/Agent readiness |
| North America staging | `config/release-targets/north-america-staging.ci.json` for static CI; approved private target for release | Signed Play appbundle and TestFlight IPA after separate service/contract/signing gates |

Both regional artifacts set `MOMCOZY_ENV=staging`; region is selected through
`--release-target singapore-staging` or `north-america-staging`. An unscoped
`staging` build is allowed only with `--smoke` as a non-distributable Android
debug APK or unsigned iOS compiler check; signed/store builds require an
explicit regional release target. Existing
Android/iOS package identities are retained. `release` means the compiler
build mode, not a production deployment environment.

`app-pr-verify.yml` checks proposed changes without building an App package.
On `main`, `app-ci.yml` owns shared quality, Golden and Singapore compilation;
`app-north-america-ci.yml` checks regional login/configuration and compiles
North America Android/iOS without rerunning the shared suite. The Singapore
manual workflow is `app-singapore-staging-release.yml`. North America store
artifact preparation is `app-north-america-store-build.yml`, gated on an exact
remote `main` commit and successful matching CI. Store upload, compliance,
review and distribution remain separate explicit operations. Product Backend
must be deployed and healthy before Agent, and both before App distribution.
Singapore App delivery also checks successful shared CI on the exact current
remote `main` SHA; its release gate runs live Product–Agent smoke and the
invite-mode signed build rather than rerunning the shared static/widget suite.

Run `node scripts/validate-workspace-environments.mjs` and
`node scripts/build-mobile-app.mjs --platform android --environment staging
--mode release --format apk --release-target singapore-staging --check-config`
for a static Singapore check. For North America, use the same build entrypoint
with its approved regional target declaration and required signing. Static
checks do not prove live DNS/TLS, service deployment or cry-analysis inference.

After local App changes, `make local-dev-refresh` builds a Debug APK, creates
and verifies a new local account, installs a fresh local-flavor app and leaves
the target emulator at the role-selection screen. Never reuse an authenticated
session for this acceptance check.
