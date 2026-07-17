#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_API_BASE_URL="https://lute-momcozylab.luteos.cloud:8443"
DEFAULT_DOWNLOAD_BASE_URL="${DEFAULT_API_BASE_URL}/app"
DEFAULT_UPLOAD_TARGET="ubuntu@54.254.112.41:/var/www/momcozy/android-apk/"
DEFAULT_RSYNC_RSH="ssh -i ${HOME}/.ssh/id_ed25519 -o IdentitiesOnly=yes -o ConnectTimeout=10"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/build-flutter-app.sh

Builds the Flutter Android APK, generates its download page and "Momcozy Lab"
QR code under dist/android-apk/, then uploads that directory with rsync.

Environment overrides:
  MOMCOZY_API_BASE_URL           API compiled into the Flutter App.
  MOMCOZY_DOWNLOAD_BASE_URL      Public URL that will host dist/android-apk/.
  MOMCOZY_APK_FLAVOR             local | staging | production (default: staging).
  MOMCOZY_APK_MODE               debug | release (default: release).
  MOMCOZY_EXTRA_DART_DEFINES     Extra comma-separated KEY=VALUE definitions.
  MOMCOZY_SKIP_NPM_CI            Set to 1 to skip npm ci.
  MOMCOZY_SKIP_UPLOAD            Set to 1 to build without uploading.
  MOMCOZY_UPLOAD_TARGET          rsync target (default: ubuntu@54.254.112.41:/var/www/momcozy/android-apk/).
  MOMCOZY_RSYNC_RSH              Remote shell used by rsync (default: SSH with ~/.ssh/id_ed25519).
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
skip_upload="${MOMCOZY_SKIP_UPLOAD:-0}"
upload_target="${MOMCOZY_UPLOAD_TARGET:-${DEFAULT_UPLOAD_TARGET}}"
rsync_rsh="${MOMCOZY_RSYNC_RSH:-${DEFAULT_RSYNC_RSH}}"
dart_defines="MOMCOZY_API_BASE_URL=${api_base_url}"

if [[ "${skip_upload}" != "0" && "${skip_upload}" != "1" ]]; then
  printf 'MOMCOZY_SKIP_UPLOAD must be 0 or 1.\n' >&2
  exit 2
fi

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
printf '  Variant:  %s %s\n' "${apk_flavor}" "${apk_mode}"
if [[ "${skip_upload}" == "1" ]]; then
  printf '  Upload:   skipped\n\n'
else
  printf '  Upload:   %s\n\n' "${upload_target}"
fi

make flutter-apk-download-site

if [[ "${skip_upload}" == "1" ]]; then
  printf '\nUpload skipped. Local output: %s\n' "${PROJECT_ROOT}/dist/android-apk"
  exit 0
fi

if ! command -v rsync >/dev/null 2>&1; then
  printf 'rsync is required to upload the generated artifacts.\n' >&2
  exit 1
fi

printf '\nUploading Momcozy Lab artifacts to %s\n' "${upload_target}"
RSYNC_RSH="${rsync_rsh}" rsync \
  -av \
  --checksum \
  --delay-updates \
  "${PROJECT_ROOT}/dist/android-apk/" \
  "${upload_target}"

printf '\nPublished: %s/\n' "${download_base_url%/}"
