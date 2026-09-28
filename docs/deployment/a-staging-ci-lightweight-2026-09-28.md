# A staging CI / delivery: lightweight pass

Measured on 2026-09-28 from GitHub Actions step timestamps. This pass removes no
release gates; it caches reproducible dependencies and keeps the existing
one-click delivery workflows. Cold-cache timings are not a speed guarantee.

| Repository / workflow | Run | Wall time | Critical work |
|---|---:|---:|---|
| Backend `backend-ci` | 36375287829 attempt 2 | 5.5 min | MinIO source build twice (1.6 and 1.9 min), backend tests 1.5 min |
| Backend `backend-delivery` | 36375987477 | 1.1 min | immutable-image deploy 0.4 min |
| Agent `agent-ci` | 36371457324 | 7.3 min | pinned MinIO source build 3.4 min |
| Agent `agent-delivery` | 36376161722 | 1.1 min | runtime deploy 0.6 min |
| App `app-ci` | 36376591153 | 9.5 min | macOS golden 6.7 min, Android compile 5.3 min (parallel jobs) |
| App `app-staging-release` | 36377367569 | 12.8 min | signed build and live Product–Agent smoke 10.4 min |

## Minimal optimization

- Backend and Agent CI build the same pinned MinIO source as before, load it into
  Docker, and retain migration/readiness/object-storage checks. Docker Buildx
  uses the repository-scoped GitHub Actions layer cache. Only a trusted `main`
  push writes that cache; PRs/feature branches may read but do not update it.
- App Android CI caches Gradle dependencies only on `main`; other refs read
  without writing. The staging release reads this cache without writing any
  signing-related build state. Flutter and npm caches already existed.
- Golden tests still run on macOS; signed APK creation, invite-login mode,
  immutable Backend/Agent manifest match, live smoke, database migrations,
  health checks, and final APK/Pages verification remain mandatory. The two
  backend deployment workflows already take about one minute; bypassing their
  verification is not a useful optimization.

## Short operator sequence

1. Push each **clean** latest commit to its own `main`; require the matching
   Backend `backend-ci`, Agent `agent-ci`, and App `app-ci` run to succeed. Do
   not substitute CI results from an older SHA or a local uncommitted tree.
2. When Backend changes, manually run `backend-delivery` with the exact
   successful main SHA; verify its staging manifest and public readiness.
3. Run `agent-delivery` against that Product manifest, even when the Agent code
   SHA is unchanged but the Product identity changed. Verify its dependency,
   worker heartbeat, and public readiness.
4. Reserve a fresh App build number/tag. Run `app-staging-release` from the
   latest successful App main SHA, passing all six identity fields from the
   two **live** staging manifests. The workflow signs, smokes, publishes and
   verifies the new APK. Check Release, Pages manifest, QR target, and real
   device install separately. CI-only follow-up commits do **not** republish
   an existing APK/build number.

See `environment-workflow.md` and `a-full-rebuild-2026-09-27.md` for the
configuration, recovery, and rollback boundaries. Cache misses must not relax
any of the checks above.
