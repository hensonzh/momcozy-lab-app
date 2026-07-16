#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_API_BASE_URL="https://lute-momcozylab.luteos.cloud:8443"
DEFAULT_DOWNLOAD_BASE_URL="${DEFAULT_API_BASE_URL}/app"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/build-flutter-app.sh

Builds the Flutter Android APK and generates its download page and
"Momcozy Lab" QR code under dist/android-apk/.

Environment overrides:
  MOMCOZY_API_BASE_URL           API compiled into the Flutter App.
  MOMCOZY_DOWNLOAD_BASE_URL      Public URL that will host dist/android-apk/.
  MOMCOZY_APK_FLAVOR             local | staging | production (default: staging).
  MOMCOZY_APK_MODE               debug | release (default: release).
  MOMCOZY_EXTRA_DART_DEFINES     Extra comma-separated KEY=VALUE definitions.
  MOMCOZY_SKIP_NPM_CI            Set to 1 to skip npm ci.
  MOMCOZY_REQUIRE_RELEASE_SIGNING
                                  Set to 1 to reject unsigned release builds.

Release signing variables are passed through without being written to disk:
  MOMCOZY_FLUTTER_RELEASE_STORE_FILE
  MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD
  MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS
  MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

cd "${PROJECT_ROOT}"

api_base_url="${MOMCOZY_API_BASE_URL:-${DEFAULT_API_BASE_URL}}"
download_base_url="${MOMCOZY_DOWNLOAD_BASE_URL:-${DEFAULT_DOWNLOAD_BASE_URL}}"
apk_flavor="${MOMCOZY_APK_FLAVOR:-staging}"
apk_mode="${MOMCOZY_APK_MODE:-release}"
dart_defines="MOMCOZY_API_BASE_URL=${api_base_url}"

if [[ -n "${MOMCOZY_EXTRA_DART_DEFINES:-}" ]]; then
  dart_defines="${dart_defines},${MOMCOZY_EXTRA_DART_DEFINES}"
fi

if [[ "${MOMCOZY_SKIP_NPM_CI:-0}" != "1" ]]; then
  npm ci --ignore-scripts
fi

export MOMCOZY_DOWNLOAD_BASE_URL="${download_base_url}"
export MOMCOZY_APK_DART_DEFINES="${dart_defines}"
export MOMCOZY_APK_FLAVOR="${apk_flavor}"
export MOMCOZY_APK_MODE="${apk_mode}"

printf 'Building Momcozy Lab Flutter App\n'
printf '  API:      %s\n' "${api_base_url}"
printf '  Download: %s\n' "${download_base_url}"
printf '  Variant:  %s %s\n\n' "${apk_flavor}" "${apk_mode}"

make flutter-apk-download-site
