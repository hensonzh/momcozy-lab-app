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

Builds the Flutter Android APK, generates its download page and "momcozy AI"
QR code under dist/android-apk/, uploads the APK to GitHub Releases and publishes
the download page through GitHub Pages.

Environment overrides:
  MOMCOZY_API_BASE_URL           Product Backend API compiled into the Flutter App.
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
pages_namespace="staging"

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

if [[ "${check_config}" != "1" && "${skip_upload}" == "0" && "${apk_flavor}" != "staging" ]]; then
  printf 'Only the staging flavor may be published. Set MOMCOZY_SKIP_UPLOAD=1 for other flavors.\n' >&2
  exit 2
fi

if [[ "${apk_flavor}" == "staging" && "${download_base_url%/}" != */"${pages_namespace}" ]]; then
  download_base_url="${download_base_url%/}/${pages_namespace}"
fi

node "${SCRIPT_DIR}/flutter-api-config.mjs" validate \
  --flavor "${apk_flavor}" \
  --product-url "${api_base_url}" \
  --agent-url "${agent_api_base_url}" \
  --extra-dart-defines "${MOMCOZY_EXTRA_DART_DEFINES:-}"

if [[ "${check_config}" == "1" ]]; then
  printf 'Flutter build config is valid.\n'
  printf '  Product Backend API: %s\n' "${api_base_url}"
  printf '  Agent Runtime API:   %s\n' "${agent_api_base_url}"
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

printf 'Building momcozy AI Flutter App\n'
printf '  Product Backend API: %s\n' "${api_base_url}"
printf '  Agent Runtime API:   %s\n' "${agent_api_base_url}"
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
provenance_file="$(read_manifest_field provenanceFile)"
apk_path="${PROJECT_ROOT}/dist/android-apk/releases/${apk_file}"
checksum_path="${apk_path}.sha256"
provenance_path="${PROJECT_ROOT}/dist/android-apk/releases/${provenance_file}"
release_title="momcozy AI Android ${version_name} (${build_number})"
release_notes="momcozy AI Android 内测版 ${version_name} (${build_number})。"
pages_checkout=""
existing_release_dir=""
cleanup() {
  if [[ -n "${pages_checkout}" ]]; then
    rm -rf "${pages_checkout}"
  fi
  if [[ -n "${existing_release_dir}" ]]; then
    rm -rf "${existing_release_dir}"
  fi
}
trap cleanup EXIT

printf '\nPublishing APK to GitHub Release %s\n' "${release_tag}"
if gh release view "${release_tag}" --repo "${github_release_repo}" >/dev/null 2>&1; then
  existing_release_dir="$(mktemp -d "${TMPDIR:-/tmp}/momcozy-release.XXXXXX")"
  if ! gh release download \
    "${release_tag}" \
    --repo "${github_release_repo}" \
    --pattern "${apk_file}" \
    --pattern "${apk_file}.sha256" \
    --pattern "${provenance_file}" \
    --dir "${existing_release_dir}"; then
    printf 'Release %s already exists without the complete immutable bundle; refusing to mutate it.\n' "${release_tag}" >&2
    exit 1
  fi
  if ! cmp -s "${apk_path}" "${existing_release_dir}/${apk_file}"; then
    printf 'Release %s already points to different APK bytes; increment the build number.\n' "${release_tag}" >&2
    exit 1
  fi
  if [[ ! -f "${existing_release_dir}/${apk_file}.sha256" ]] || \
    ! cmp -s "${checksum_path}" "${existing_release_dir}/${apk_file}.sha256"; then
    printf 'Release %s has a missing or different checksum asset; refusing to mutate it.\n' "${release_tag}" >&2
    exit 1
  fi
  if [[ ! -f "${existing_release_dir}/${provenance_file}" ]] || \
    ! cmp -s "${provenance_path}" "${existing_release_dir}/${provenance_file}"; then
    printf 'Release %s has different provenance; increment the build number.\n' "${release_tag}" >&2
    exit 1
  fi
  printf 'Release already contains the identical APK; publication is idempotent.\n'
else
  gh release create \
    "${release_tag}" \
    "${apk_path}" \
    "${checksum_path}" \
    "${provenance_path}" \
    --repo "${github_release_repo}" \
    --target main \
    --title "${release_title}" \
    --notes "${release_notes}" \
    --latest
fi

pages_checkout="$(mktemp -d "${TMPDIR:-/tmp}/momcozy-pages.XXXXXX")"

printf '\nPublishing download page to GitHub Pages\n'
gh repo clone "${github_release_repo}" "${pages_checkout}" -- --depth 1
git -C "${pages_checkout}" config --local credential.helper ""
git -C "${pages_checkout}" config --local --add credential.helper "!gh auth git-credential"
mkdir -p "${pages_checkout}/${pages_namespace}/assets"
cp "${PROJECT_ROOT}/dist/android-apk/index.html" "${pages_checkout}/${pages_namespace}/index.html"
cp "${PROJECT_ROOT}/dist/android-apk/manifest.json" "${pages_checkout}/${pages_namespace}/manifest.json"
cp \
  "${PROJECT_ROOT}/dist/android-apk/assets/momcozy-lab-download-qr.svg" \
  "${pages_checkout}/${pages_namespace}/assets/momcozy-lab-download-qr.svg"
touch "${pages_checkout}/.nojekyll"

git -C "${pages_checkout}" add \
  .nojekyll \
  "${pages_namespace}/index.html" \
  "${pages_namespace}/manifest.json" \
  "${pages_namespace}/assets/momcozy-lab-download-qr.svg"

if ! git -C "${pages_checkout}" diff --cached --quiet; then
  github_login="$(gh api user --jq .login)"
  git -C "${pages_checkout}" config user.name "${github_login}"
  git -C "${pages_checkout}" config user.email "${github_login}@users.noreply.github.com"
  git -C "${pages_checkout}" commit -m "release: Android ${version_name} (${build_number})"
  git -C "${pages_checkout}" push origin main
fi

printf '\nDeployment succeeded.\n'
printf 'App release:        %s/\n' "${download_base_url%/}"
printf 'Invite code admin:  %s/v1/admin/invite-codes/ui\n' "${api_base_url%/}"
