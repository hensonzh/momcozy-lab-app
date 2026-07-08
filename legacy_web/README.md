# Legacy Web Implementation

This directory contains the archived React/Vite/Capacitor implementation.

It remains useful for:

- historical API, storage, route, and native bridge behavior checks,
- manual archaeology when comparing old behavior with the Flutter implementation.

Install and run the legacy Web toolchain from this directory:

```bash
cd legacy_web
npm install
npm run dev
npm run build
npm test
```

The repository root no longer forwards `dev`, `build`, or `test` to this directory. The legacy Web Node dependencies and lockfile are owned by this directory.

Run legacy Capacitor sync from this directory after building:

```bash
cd legacy_web
npx cap sync android
```

The new Flutter implementation lives in `../flutter_app/` and should not import source files from this directory.
