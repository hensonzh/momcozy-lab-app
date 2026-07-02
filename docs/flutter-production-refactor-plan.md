# MomCozy Flutter Production Refactor Plan

Status: active

This plan turns the current Flutter proof-of-concept into a production mobile
client for the production backend contract. It follows the global
`flutter-product-app-architecture` guidance and treats the backend OpenAPI
snapshot in `docs/backend-contract/` as the client source of truth.

## Contract Sources

- OpenAPI snapshot: `docs/backend-contract/openapi.generated.json`
- Human handoff: `docs/backend-contract/api-contract-handoff.md`
- Compatibility policy: `docs/backend-contract/flutter-client-compatibility.md`
- Smoke flows: `docs/backend-contract/flutter-smoke-flows.json`
- Local validator: `python scripts/validate_backend_contract.py`

The legacy MomCozyAgent raw response shapes are not compatibility targets.
Feature repositories must migrate to the production `/v1` contract.

## Current State

Already present:

- `app/`, `core/`, `features/`, and `native/` directories.
- `go_router` shell, bottom navigation, route intent bridge, and agent hub.
- Core network transport, session model/store, observability redaction, storage
  migration helpers, BLE/native platform interfaces, and feature repositories.
- Production auth data-layer repository and refresh coordinator for
  `/v1/auth/signup`, `/login`, `/refresh`, and `/logout`.
- App shell runtime controller can replace the active session/runtime after
  login, refresh, logout, or account switch.
- Network transport parses production error envelopes and supports per-request
  headers such as `Idempotency-Key`.
- Records and media repositories target production `/v1/records/*` and
  `/v1/files/upload` contracts without sending `user_id` as authority.
- Status repository targets production `/v1/profile/me` and
  `/v1/profile/infants` contracts.
- Schedule repository targets production `/v1/plans/tasks/list` and maps
  `PlanTaskRead` into the existing day-plan domain model without sending
  `user_id` as authority.
- Pump workstate upload targets production `/v1/devices/pump-telemetry` and
  stores left/right side state in telemetry payload instead of posting
  `user_id` or legacy agent reply fields.
- Hospital bag cart sync writes a `/v1/plans` projection with
  `plan_type=hospital_bag_cart` and an idempotency key, removing the legacy
  `/api/hospital-bag/cart-update` path.
- Immediate App blockers fixed: Kotlin Android plugin, no bearer token in agent
  stream URLs, callback-based Android permission results, typed non-JSON HTTP
  errors.

Main gaps:

- Runtime still bootstraps from dart-define demo users and optional bearer token.
- Auth UI and route guards are not wired yet.
- Some feature repositories still pass `user_id` and target legacy endpoints.
- Agent chat still uses legacy AG-UI endpoints instead of `/v1/agent` thread,
  run, replay, stream, cancel, and action-confirmation resources.
- API client is handwritten and only partially validated against OpenAPI.
- CI cannot yet run Flutter format/analyze/test in this local environment.

## Target Architecture

- Backend owns user scope through `Authorization: Bearer <access_token>`.
- Refresh token is stored in secure storage and sent only to
  `POST /v1/auth/refresh`.
- Access token is scoped to the runtime/session client and never placed in URLs,
  logs, analytics, screenshots, or local plain storage.
- API DTOs are generated from or validated against OpenAPI before repositories
  map them into domain entities.
- Repositories use production paths such as `/v1/profile/me`,
  `/v1/profile/infants`, `/v1/records/feeding`, `/v1/records/pumping`,
  `/v1/records/growth`, `/v1/plans`, `/v1/files/upload`, and `/v1/agent/*`.
- Agent UI consumes application events with stable IDs and sequence cursors; it
  does not parse assistant text to infer tool, artifact, or action state.

## Phase To PR Slices

| Phase | Skill/reference | PR slice | Acceptance gate |
|---|---|---|---|
| 0. Contract foundation | Flutter API/auth + backend handoff | Copy backend contract snapshot and add validator. | `python scripts/validate_backend_contract.py` passes. |
| 1. Auth/session | `api-state-auth.md`, backend `/v1/auth/*` | Add auth DTOs/repository/session service, refresh lock, logout cache purge. | Unit tests cover signup/login/refresh/logout, expired token refresh, logout cleanup. |
| 2. Network contract | `api-state-auth.md` | Add stable error envelope mapper, idempotency header support, generated-client policy. | Tests cover `{error:{code,message,request_id}}`, 401, 403, 409, 422, 429, 5xx. |
| 3. Records/profile/files | `project-organization.md` | Move status/records/media repositories to production `/v1` endpoints and remove `user_id` authority params from requests. | Repository tests use OpenAPI-aligned fixtures and no legacy path constants. |
| 4. Agent runtime UI | `agent-streaming-ui.md`, production agent contract | Replace legacy AG-UI endpoints with `/v1/agent/threads`, `/runs`, `/events`, `/stream`, `/cancel`, `/actions`. | Reducer tests cover replay, duplicate events, action IDs, cancel, reconnect cursor. |
| 5. App shell hardening | `complete-flutter-build.md` | Add authenticated/anonymous routing states, production flavors, diagnostics screen, and privacy redaction review. | Widget tests cover auth gate, route restore, offline/error/permission states. |
| 6. Release gates | `testing-release.md` | Add CI for contract validator, Flutter format/analyze/test, Android build, staging smoke flow. | CI blocks stale contract, legacy endpoints, token URLs, and failing tests. |

## Immediate Next Slices

1. Keep `docs/backend-contract/` synchronized with backend PRs and run the
   validator in both repos.
2. Wire production auth/session into app routing and runtime replacement,
   because every owner-scoped feature depends on it.
3. Continue migrating voice repositories to `/v1`, so `user_id` can stop being
   passed as authority.
4. Migrate agent chat after the runtime API adapter exists, because stream
   replay and action confirmation need a different state model from the legacy
   AG-UI transport.

## Non-Goals

- Do not add compatibility code for legacy raw backend responses.
- Do not use query `user_id` as authority for production APIs.
- Do not put access tokens, refresh tokens, or service keys in URLs.
- Do not build server behavior from Flutter summaries; backend OpenAPI and the
  agent runtime contract are the source of truth.
