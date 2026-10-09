#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# A separate target is mandatory. Do not pass production API/token defines to
# a public static build. Flutter's own assets are hosted with the page.
for name in MOMCOZY_API_TOKEN MOMCOZY_REFRESH_TOKEN MOMCOZY_API_BASE_URL MOMCOZY_AGENT_API_BASE_URL; do
  if [[ -n "${!name:-}" ]]; then
    echo "Refusing to build a public demo with ${name} set" >&2
    exit 1
  fi
done

out="${1:-build/web-demo}"
base="${MOMCOZY_WEB_DEMO_BASE_HREF:-/}"
if [[ "$base" != /* || "$base" != */ ]]; then
  echo "MOMCOZY_WEB_DEMO_BASE_HREF must start and end in /" >&2
  exit 1
fi
flutter build web --release --no-pub --target lib/main_web_mock.dart \
  --no-web-resources-cdn --base-href "$base" --output "$out"

# The shared Flutter web/index.html still belongs to the mobile app target.
# Only the dedicated static artifact receives demo metadata and fail-closed CSP.
python3 - "$out/index.html" "$out/flutter_bootstrap.js" "$base" <<'PYBOOT'
import pathlib
import sys

index, bootstrap, base = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
index.write_text(pathlib.Path('web_demo/index.html').read_text().replace('$FLUTTER_BASE_HREF', base))
source = bootstrap.read_text()
start = source.rfind('_flutter.loader.load({')
if start < 0 or not source[start:].startswith('_flutter.loader.load({'):
    raise SystemExit('Cannot locate Flutter bootstrap loader')
# No deprecated service worker. CanvasKit and font fallbacks load locally.
bootstrap.write_text(source[:start] + '_flutter.loader.load({config: {fontFallbackBaseUrl: "' + base + 'demo-fonts/"}});\n')
PYBOOT
cp "$out/index.html" "$out/404.html"
# The source asset inventory contains an internal CA and a version file with a
# mobile build number; neither belongs on a public Web test site.
rm -rf "$out/assets/assets/certificates" "$out/demo-fonts"
rm -f "$out/flutter_service_worker.js" "$out/version.json" "$out/.last_build_id"
cp -R web_demo/fonts "$out/demo-fonts"
python3 scripts/subset_web_demo_fonts.py "$out"
python3 scripts/check_web_demo_artifact.py "$out"
