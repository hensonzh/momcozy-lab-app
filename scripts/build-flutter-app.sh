#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_LOCAL_API_BASE_URL="http://127.0.0.1:8769"
DEFAULT_LOCAL_AGENT_API_BASE_URL="http://127.0.0.1:8010"
DEFAULT_GITHUB_RELEASE_REPO="hensonzh/momcozy-lab-releases"
DEFAULT_DOWNLOAD_BASE_URL="https://hensonzh.github.io/momcozy-lab-releases"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/build-flutter-app.sh
  ./scripts/build-flutter-app.sh --check-config

Builds the Flutter Android APK, generates its download page and "Momcozy Lab"
QR code under dist/android-apk/, uploads the APK to GitHub Releases and publishes
the download page through GitHub Pages.

Environment overrides:
  MOMCOZY_API_BASE_URL           Product API compiled into the Flutter App.
  MOMCOZY_AGENT_API_BASE_URL     Agent Runtime API compiled into the Flutter App.
  MOMCOZY_DOWNLOAD_BASE_URL      Public GitHub Pages URL for the download page.
  MOMCOZY_GITHUB_RELEASE_REPO    Public owner/repository for Releases and Pages.
  MOMCOZY_APK_FLAVOR             local | staging | production (default: staging).
  MOMCOZY_APK_MODE               debug | release (default: release).
  MOMCOZY_EXTRA_DART_DEFINES     Extra comma-separated KEY=VALUE definitions;
                                  the two API URL keys are reserved.
  MOMCOZY_SKIP_NPM_CI            Set to 1 to skip npm ci.
  MOMCOZY_SKIP_UPLOAD            Set to 1 to build without publishing to GitHub.
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
  --check-config)
    check_config=1
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

cd "${PROJECT_ROOT}"

check_config="${check_config:-0}"
download_base_url="${MOMCOZY_DOWNLOAD_BASE_URL:-${DEFAULT_DOWNLOAD_BASE_URL}}"
github_release_repo="${MOMCOZY_GITHUB_RELEASE_REPO:-${DEFAULT_GITHUB_RELEASE_REPO}}"
apk_flavor="${MOMCOZY_APK_FLAVOR:-staging}"
apk_mode="${MOMCOZY_APK_MODE:-release}"
skip_upload="${MOMCOZY_SKIP_UPLOAD:-0}"

if [[ "${apk_flavor}" == "local" ]]; then
  api_base_url="${MOMCOZY_API_BASE_URL:-${DEFAULT_LOCAL_API_BASE_URL}}"
  agent_api_base_url="${MOMCOZY_AGENT_API_BASE_URL:-${DEFAULT_LOCAL_AGENT_API_BASE_URL}}"
else
  api_base_url="${MOMCOZY_API_BASE_URL:-}"
  agent_api_base_url="${MOMCOZY_AGENT_API_BASE_URL:-}"
fi

if [[ "${skip_upload}" != "0" && "${skip_upload}" != "1" ]]; then
  printf 'MOMCOZY_SKIP_UPLOAD must be 0 or 1.\n' >&2
  exit 2
fi

node "${SCRIPT_DIR}/flutter-api-config.mjs" validate \
  --flavor "${apk_flavor}" \
  --product-url "${api_base_url}" \
  --agent-url "${agent_api_base_url}" \
  --extra-dart-defines "${MOMCOZY_EXTRA_DART_DEFINES:-}"

if [[ "${check_config}" == "1" ]]; then
  printf 'Flutter build config is valid.\n'
  printf '  Product API: %s\n' "${api_base_url}"
  printf '  Agent API:   %s\n' "${agent_api_base_url}"
  printf '  Variant:     %s %s\n' "${apk_flavor}" "${apk_mode}"
  exit 0
fi

if [[ "${MOMCOZY_SKIP_NPM_CI:-0}" != "1" ]]; then
  npm ci --ignore-scripts
fi

export MOMCOZY_DOWNLOAD_BASE_URL="${download_base_url}"
export MOMCOZY_GITHUB_RELEASE_REPO="${github_release_repo}"
export MOMCOZY_API_BASE_URL="${api_base_url}"
export MOMCOZY_AGENT_API_BASE_URL="${agent_api_base_url}"
export MOMCOZY_APK_DART_DEFINES="${MOMCOZY_EXTRA_DART_DEFINES:-}"
export MOMCOZY_APK_FLAVOR="${apk_flavor}"
export MOMCOZY_APK_MODE="${apk_mode}"

printf 'Building Momcozy Lab Flutter App\n'
printf '  Product API: %s\n' "${api_base_url}"
printf '  Agent API:   %s\n' "${agent_api_base_url}"
printf '  Download:    %s\n' "${download_base_url}"
printf '  Releases:    %s\n' "${github_release_repo}"
printf '  Variant:     %s %s\n' "${apk_flavor}" "${apk_mode}"
if [[ "${skip_upload}" == "1" ]]; then
  printf '  Publish:  skipped\n\n'
else
  printf '  Publish:  GitHub Releases + Pages\n\n'
fi

make flutter-apk-download-site

if [[ "${skip_upload}" == "1" ]]; then
  printf '\nUpload skipped. Local output: %s\n' "${PROJECT_ROOT}/dist/android-apk"
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  printf 'GitHub CLI (gh) is required to publish the generated artifacts.\n' >&2
  exit 1
fi

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  printf 'GitHub CLI is not authenticated. Run: gh auth login\n' >&2
  exit 1
fi

read_manifest_field() {
  node -e '
    const fs = require("node:fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const value = manifest[process.argv[2]];
    if (value === undefined || value === null || value === "") process.exit(1);
    process.stdout.write(String(value));
  ' "${PROJECT_ROOT}/dist/android-apk/manifest.json" "$1"
}

apk_file="$(read_manifest_field apkFile)"
release_tag="$(read_manifest_field githubReleaseTag)"
version_name="$(read_manifest_field versionName)"
build_number="$(read_manifest_field buildNumber)"
apk_path="${PROJECT_ROOT}/dist/android-apk/releases/${apk_file}"
checksum_path="${apk_path}.sha256"
release_title="Momcozy Lab Android ${version_name} (${build_number})"
release_notes="Momcozy Lab Android 内测版 ${version_name} (${build_number})。"

printf '\nPublishing APK to GitHub Release %s\n' "${release_tag}"
if gh release view "${release_tag}" --repo "${github_release_repo}" >/dev/null 2>&1; then
  gh release upload \
    "${release_tag}" \
    "${apk_path}" \
    "${checksum_path}" \
    --repo "${github_release_repo}" \
    --clobber
  gh release edit \
    "${release_tag}" \
    --repo "${github_release_repo}" \
    --title "${release_title}" \
    --notes "${release_notes}" \
    --latest
else
  gh release create \
    "${release_tag}" \
    "${apk_path}" \
    "${checksum_path}" \
    --repo "${github_release_repo}" \
    --target main \
    --title "${release_title}" \
    --notes "${release_notes}" \
    --latest
fi

pages_checkout="$(mktemp -d "${TMPDIR:-/tmp}/momcozy-pages.XXXXXX")"
cleanup() {
  rm -rf "${pages_checkout}"
}
trap cleanup EXIT

printf '\nPublishing download page to GitHub Pages\n'
git clone --depth 1 "git@github.com:${github_release_repo}.git" "${pages_checkout}"
mkdir -p "${pages_checkout}/assets"
cp "${PROJECT_ROOT}/dist/android-apk/index.html" "${pages_checkout}/index.html"
cp "${PROJECT_ROOT}/dist/android-apk/manifest.json" "${pages_checkout}/manifest.json"
cp \
  "${PROJECT_ROOT}/dist/android-apk/assets/momcozy-lab-download-qr.svg" \
  "${pages_checkout}/assets/momcozy-lab-download-qr.svg"
touch "${pages_checkout}/.nojekyll"

git -C "${pages_checkout}" add \
  .nojekyll \
  index.html \
  manifest.json \
  assets/momcozy-lab-download-qr.svg

if ! git -C "${pages_checkout}" diff --cached --quiet; then
  github_login="$(gh api user --jq .login)"
  git -C "${pages_checkout}" config user.name "${github_login}"
  git -C "${pages_checkout}" config user.email "${github_login}@users.noreply.github.com"
  git -C "${pages_checkout}" commit -m "release: Android ${version_name} (${build_number})"
  git -C "${pages_checkout}" push origin main
fi

if ! gh api "repos/${github_release_repo}/pages" >/dev/null 2>&1; then
  gh api \
    --method POST \
    "repos/${github_release_repo}/pages" \
    -f build_type=legacy \
    -f 'source[branch]=main' \
    -f 'source[path]=/' \
    >/dev/null
fi

printf '\nDeployment succeeded.\n'
printf 'App release:        %s/\n' "${download_base_url%/}"
printf 'Invite code admin:  %s/v1/admin/invite-codes/ui\n' "${api_base_url%/}"
