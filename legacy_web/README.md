# Legacy Web Implementation

This directory contains the archived React/Vite/Capacitor implementation.

It remains useful for:

- visual parity references while Flutter is being rebuilt,
- current Web/Capacitor rollback packaging,
- historical API, storage, route, and native bridge behavior checks.

Run common commands from the repository root:

```bash
npm run dev
npm run build
npm test
```

Run legacy Capacitor sync from this directory after building:

```bash
cd legacy_web
npx cap sync android
```

The new Flutter implementation lives in `../flutter_app/` and should not import source files from this directory.
