# Flutter Refactor Review Issues

Status: active

This document records the Flutter-side issues found during the production
refactor review. The backend is being refactored independently first, so App
work should be split into immediate engineering fixes and later contract-driven
integration with the new backend.

## Decision

Do not deeply adapt the Flutter app to the legacy MomCozyAgent API while the
production backend is being rebuilt.

The Flutter app should:

- Fix local build, security, permission, and error-handling blockers now.
- Wait for the new backend OpenAPI, error schema, auth contract, and agent event
  schema before rewriting feature repositories.
- Remove legacy API compatibility code once the production backend contract is
  stable.

## Immediate App Fixes

These issues do not depend on the new backend contract and should be fixed in
the Flutter project directly.

| Priority | Area | Issue | Required Fix |
|---|---|---|---|
| P1 | Android build | `android/app/build.gradle.kts` has Kotlin sources and a `kotlin {}` block, but does not apply the Kotlin Android plugin. | Apply `org.jetbrains.kotlin.android` / `kotlin-android` before `dev.flutter.flutter-gradle-plugin`. |
| P1 | Agent stream transport | `agent_stream_io_transport.dart` appends bearer tokens as `token=` URL query params while also sending `Authorization`. | Keep access tokens out of URLs; use authorization headers or short-lived backend-issued stream tokens only when headers are impossible. |
| P2 | Android permissions | `MainActivity.kt` returns permission state immediately after `requestPermissions()` instead of after `onRequestPermissionsResult`. | Complete the method-channel result only after the platform permission callback returns. |
| P2 | Network transport | `api_json_transport.dart` decodes body before checking status, so non-JSON 502/503 bodies become `FormatException`. | Preserve HTTP status and raise typed transport errors for non-JSON error bodies. |

## Wait For New Backend Contract

These issues are real, but should be resolved against the production backend
contract rather than patched around the legacy API.

| Priority | Area | Legacy Mismatch | Target Handling |
|---|---|---|---|
| P1 | API envelope | `api_envelope.dart` expects mandatory `{status, data}`, while legacy endpoints return raw objects with `error` and payload fields. | Generate or validate DTOs from the new backend OpenAPI and use one stable success/error shape. |
| P2 | Feeding records | `records_api_repository.dart` calls `/v1/feeding/record/query` with `date`, while legacy docs expose `/v1/feeding/query` with `timestamp`. | Rebuild the records repository from the new records API contract. |
| P2 | Growth history | The legacy response uses `growth_data` and fields such as `growth_id`, `weight_kg`, and `date`, while current Flutter mapping expects other names. | Map against the new typed growth DTOs after the backend records module is migrated. |

## Backend Contract Dependencies

Flutter integration should wait for these backend artifacts:

- OpenAPI schema for auth, files, records, plans, diary, devices, and agent APIs.
- Stable error envelope and HTTP status semantics.
- Access/refresh token contract and device-session behavior.
- File upload contract with owner-scoped file IDs and object storage semantics.
- Agent application event schema, including `event_id`, `sequence`, `run_id`,
  `message_id`, `tool_call_id`, `artifact_id`, and `action_id`.
- Action confirmation contract for high-risk writes.

## App Acceptance Criteria

- Android fresh build succeeds.
- Access tokens are not present in URLs, logs, analytics, crash reports, or
  screenshots.
- First-time BLE and notification permission prompts return the post-prompt
  result.
- Non-JSON 5xx responses preserve HTTP status and map to typed UI errors.
- Feature repositories consume the new backend contract, not legacy raw
  responses.
