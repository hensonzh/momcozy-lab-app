# Regional staging configuration

Updated: 2026-10-20. The workspace has **local development**, **Singapore
staging**, and **North America staging** targets. Both deployed targets run
`APP_ENV=staging` / `MOMCOZY_ENV=staging`; region is a separate deployment
target, not a separate runtime mode. CI `test` is not a deployable target.
There is no production environment entrypoint.

| Target | Product / Agent env | App target | Delivery |
| --- | --- | --- | --- |
| Local | each service's ignored `env/local.env` | `config/environments/local.json`; Android `local` | `make local-dev-up`, `make local-dev-refresh` |
| Singapore staging | each service's private env from `env/staging.env.example` | `config/environments/staging.json`; Android `staging` | Backend first, Agent second, then signed invite APK |
| North America staging | each service's separate private env from `env/us-east-uat.env.example` | `config/release-targets/north-america-staging.ci.json` for static CI; private target declaration for release | Backend first, Agent second, then signed Play bundle/TestFlight IPA |

Only proven `main` commits may publish a service image or App artifact. `dev`
and feature branches are development sources, not build/deployment sources.
CI image publication does **not** deploy a host; App signing and distribution
are separate gates. Do not infer live deployment from committed templates.

The existing App identities are intentionally unchanged:

- Local Android: `com.momcozymai.app.flutterpoc.local`.
- Singapore Android: `com.momcozymai.app.flutterpoc.staging`.
- North America Android: `momcozy.com.mai`.
- North America iOS: `com.momcozy.mai.staging`.

No separate Singapore iOS release identity is declared. `release` is still a
build mode, not a production environment. Regional signing credentials and
store distribution rules remain distinct even though the code source is
unified on `main`.

Product owns each region's shared network/state. Agent is an external consumer
with a separate database and credentials. The private envs must agree on
public Product/Agent origins, JWKS, internal service identities and topology;
`node scripts/validate-workspace-environments.mjs` checks the committed
non-secret configuration only. Both Product Backend regional private envs require the Zoundream endpoint/key
for the separate cry-analysis API. Agent receives only an owner/thread-verified
result ID, never vendor credentials or audio. Provision the key privately and
verify a real cry sample end to end; a healthy Agent is not proof of analysis.

Before a release, inspect the region's actual host identity, TLS/ingress,
current/previous pointers, schema, immutable image digest, backup/restore and
App signing. Do not run bootstrap on a non-empty host or treat a static
preflight as release authorization. This documentation does not assert that
either regional host is currently deployed.
