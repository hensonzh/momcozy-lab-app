# Unified App Integration Baseline

This branch combines the two Flutter lines without treating either repository
as an all-or-nothing winner.

## Frozen inputs

- Existing app baseline: `pre-merge-current-20260815`
- MomCozyApp product baseline: `pre-merge-momcozyapp-20260815`
- Integration branch: `integration/unified-app`
- Product Backend snapshot SHA-256: `71fd45937c95310798d626bd306ef940f36b4d5639aeb2582d89aba9471ceb57`
- Agent Runtime snapshot SHA-256: `b98e8d9941e3b1926028f7dce94ad335457866e94b2dfdd3dd84610591b95ff9`

The MomCozyApp tree owns the current product shell, visual design, new feature
modules, motion assessment, media, Agent conversation UI, and native pose
capabilities. The existing app baseline remains authoritative for deployed
Product Backend and Agent Runtime service boundaries and the Agent Runtime
request/event contract.

## Contract ownership

| Boundary | Authority | App rule |
| --- | --- | --- |
| Product Backend HTTP API | `product.openapi.generated.json` | Use `MOMCOZY_API_BASE_URL`. |
| Agent Runtime HTTP/SSE API | `agent-runtime.openapi.generated.json` | Use `MOMCOZY_AGENT_API_BASE_URL` for every `/v1/agent/*` request. |
| Agent run creation | Agent Runtime snapshot | Send `runtime_pattern: proprietary_runtime` and typed attachment references. |
| Authentication/session | Product Backend plus App secure store | Keep the atomic secure payload and one refresh coordinator. |
| Product UI and routes | MomCozyApp | Keep `/status -> /me` and `/schedule -> /plan` compatibility redirects. |

The old unified `openapi.generated.json` is intentionally removed. It hid
service ownership and allowed Agent Runtime routes to be sent to the Product Backend origin.
The frozen snapshots above are this App release's compatibility boundary;
moving backend `main` branches are not silently substituted during App CI.

## Compatibility gates

The Product Backend snapshot does not yet expose every endpoint implemented by
the newer product UI. Unsupported launch-blocking behavior is therefore off by
default and must be enabled explicitly after staging contract verification.

- `MOMCOZY_ENABLE_ONBOARDING`: enables the backend-driven onboarding gate.
- `MOMCOZY_ENABLE_RELEASE_RESET`: opts into the internal-test release reset,
  but the reset runs only when `MOMCOZY_ENABLE_ONBOARDING` is also true. The
  reset flag alone is intentionally inert.
- `MOMCOZY_ENABLE_AGENT_HISTORY`: must remain disabled for this baseline. The
  frozen Agent Runtime OpenAPI does not expose
  `GET /v1/agent/threads/{thread_id}/history`; enable it only after that endpoint
  and its response schema pass staging contract verification.
- `MOMCOZY_ENABLE_EXTENDED_PRODUCT_API`: enables Body Profile and Motion
  Assessment routes plus extended Me/Baby resources only after their Product
  endpoints are verified.

Release-reset startup behavior is intentionally conjunctive:

| Onboarding | Release reset | Startup reset |
| --- | --- | --- |
| `false` | `false` | Off |
| `false` | `true` | Off |
| `true` | `false` | Off |
| `true` | `true` | On |

The same resource-level gate covers `/v1/care-overview/me`,
`/v1/records/feeding-summary`, `/v1/records/water`,
`/v1/records/water-trends`, `/v1/records/vitals`, `/v1/records/sleep`, and
`/v1/records/diaper`. With the flag off, `/me`, `/baby`, and the compatibility
redirect `/status -> /me` still load snapshot-supported profile, feeding,
growth, milk-trend, and plan resources; extended cards render an explicit
unavailable/empty state and make no request to those gated paths. These
resources must not become authentication or app-shell prerequisites.

## Merge rules

- Do not restore the retired duplicate Status and Schedule page trees.
- Do not add a second state-management or routing framework during integration.
- Preserve application-event reduction by stable IDs and replay sequence.
- A queued Agent action is not rendered as applied.
- Keep native MotionPose support; do not restore retired schedule receivers.
- The integration build number must be greater than 54.

## Verification gates

1. Validate both OpenAPI snapshots and smoke-flow service ownership.
2. Run Flutter format, analyzer, unit/widget tests, and contract tests.
3. Build at least a local debug APK and a staging release APK.
4. Run real-device checks for MotionPose, camera/microphone permissions, BLE,
   Agent SSE reconnect/cancel, secure-session upgrade, and login/logout.
5. Enable gated backend capabilities only after the matching staging endpoints
   and response schemas pass contract smoke tests.
