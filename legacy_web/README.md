# Legacy Web Implementation

This directory contains the archived React/Vite/Capacitor implementation.

It remains useful for:

- visual parity references while Flutter is being rebuilt,
- current Web/Capacitor rollback packaging,
- historical API, storage, route, and native bridge behavior checks.

Install and run the legacy Web toolchain from this directory:

```bash
cd legacy_web
npm install
npm run dev
npm run build
npm test
```

The repository root keeps forwarding scripts such as `npm run dev/build/test`, but the legacy Web Node dependencies and lockfile are owned by this directory.

Run legacy Capacitor sync from this directory after building:

```bash
cd legacy_web
npx cap sync android
```

The new Flutter implementation lives in `../flutter_app/` and should not import source files from this directory.
