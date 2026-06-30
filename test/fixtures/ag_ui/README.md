# AG-UI stream fixtures

These fixtures freeze transport-agnostic Agent stream behavior before the Flutter rewrite.

Sources of truth:

- `src/lib/agentApi.ts`
- `src/lib/agUiStreamSideEffects.ts`
- `src/pages/AgentHub.tsx`
- `doc/flutter-app-test-plan.md`

Files:

- `run_started.json`: minimum run start event with loaded skill metadata.
- `text_stream_basic.jsonl`: canonical logical event sequence for a text-only answer.
- `text_stream_basic.eventstream`: the same text sequence encoded as SSE blocks.
- `text_stream_basic.websocket.jsonl`: the same text sequence encoded as WebSocket frames, mixing JSON frames and SSE-like frames because the current client supports both.
- `tool_call_lifecycle.jsonl`: tool start/args/end/result lifecycle plus artifact and final answer.
- `activity_snapshot.json`: activity/status metadata snapshot.
- `rich_text_artifact.json`: structured artifact event with safe rich text payload.
- `image_upload_message.json`: outbound AG-UI payload with text and image content.
- `run_error.json`: terminal error event.
- `cancel_ack.json`: cancel endpoint acknowledgement.

Flutter should parse these into one domain model before updating UI. SSE and WebSocket adapters must produce the same logical event list for equivalent input.
