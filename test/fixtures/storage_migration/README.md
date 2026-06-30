# Storage Migration Fixtures

These fixtures define legacy Web/Capacitor storage input and expected Flutter migration output.

Each fixture uses the same shape:

```json
{
  "id": "stable-fixture-id",
  "legacy": {
    "localStorage": {},
    "sessionStorage": {},
    "capacitorPreferences": {},
    "androidSharedPreferences": {}
  },
  "context": {},
  "expected": {},
  "assertions": []
}
```

Rules:

- Values under `legacy.localStorage`, `legacy.sessionStorage`, and `legacy.capacitorPreferences` are raw string values, matching browser storage behavior.
- `expected` uses semantic target buckets instead of final package-specific class names, so the fixtures stay valid if Flutter storage libraries change.
- One-shot route and notification keys must be consumed once and removed from legacy storage.
- Runtime pump session keys must not be trusted unless a native active-session snapshot validates them.
- Sensitive values such as tokens and serial numbers should be represented with test-safe placeholders only.
