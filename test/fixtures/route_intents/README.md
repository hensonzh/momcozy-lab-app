# Route Intent Fixtures

These fixtures define how current Web/Capacitor route inputs should map to Flutter typed route intents.

Common shape:

```json
{
  "id": "stable-fixture-id",
  "input": {},
  "expectedIntents": [],
  "sideEffects": {},
  "assertions": []
}
```

Rules:

- Raw paths are allowed only at the deep-link/native boundary.
- Flutter internals should use typed route intents.
- Notification and pending-storage intents must be consumed once.
- User or health data must be sanitized before entering chat or logs.
- Unknown route or malformed payload must not crash the app.
