#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
APP_BUNDLE="$DIST_DIR/Codex Keyring.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
ARTIFACT_PREFIX="CodexKeyring"
RUN_APP_SMOKE=0
SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
AD_HOC_SIGN="${AD_HOC_SIGN:-1}"
NOTARIZE_RELEASE="${NOTARIZE_RELEASE:-0}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"
NOTARYTOOL_KEYCHAIN_PROFILE="${NOTARYTOOL_KEYCHAIN_PROFILE:-}"
NOTARYTOOL_KEYCHAIN="${NOTARYTOOL_KEYCHAIN:-}"
NOTARYTOOL_TIMEOUT="${NOTARYTOOL_TIMEOUT:-30m}"
VERSION="${APP_VERSION:-}"
BUILD_NUMBER="${APP_BUILD:-}"

usage() {
  cat <<USAGE
usage: $0 [--version <version>] [--build <number>] [--app-smoke] [--notarize]

Builds the release app bundle, signs it when possible, packages it as a zip,
and writes a SHA256 checksum under dist/release.

Options:
  --version <version>   release version, such as 0.1.0; defaults to a v* tag
                        when available, then 0.1.0
  --build <number>      build number; defaults to GITHUB_RUN_NUMBER, then the
                        git commit count
  --app-smoke           launch and verify the staged release app before zipping
  --notarize            submit the signed app for notarization before zipping
  -h,--help             show this help

Environment:
  APP_VERSION=0.1.0                        same as --version
  APP_BUILD=1                              same as --build
  CODESIGN_IDENTITY=<name>                 sign with a Developer ID identity
  AD_HOC_SIGN=0                            skip default ad hoc signing
  NOTARIZE_RELEASE=1                       same as --notarize
  APPLE_ID=<email>                         notarytool Apple ID auth
  APPLE_TEAM_ID=<team-id>                  notarytool Apple ID auth
  APPLE_APP_SPECIFIC_PASSWORD=<password>   notarytool Apple ID auth
  NOTARYTOOL_KEYCHAIN_PROFILE=<profile>    notarytool keychain profile auth
  NOTARYTOOL_KEYCHAIN=<path>               keychain for the profile, optional
  NOTARYTOOL_TIMEOUT=30m                   notarytool wait timeout
USAGE
}

while (($#)); do
  case "$1" in
    --version)
      if (($# < 2)); then
        echo "--version requires a value" >&2
        exit 2
      fi
      VERSION="$2"
      shift
      ;;
    --build)
      if (($# < 2)); then
        echo "--build requires a value" >&2
        exit 2
      fi
      BUILD_NUMBER="$2"
      shift
      ;;
    --app-smoke)
      RUN_APP_SMOKE=1
      ;;
    --notarize)
      NOTARIZE_RELEASE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

cd "$ROOT_DIR"

derive_version() {
  if [[ -n "${GITHUB_REF_NAME:-}" && "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
    printf '%s\n' "${GITHUB_REF_NAME#v}"
    return
  fi

  if tag="$(git describe --tags --exact-match 2>/dev/null)"; then
    printf '%s\n' "${tag#v}"
    return
  fi

  printf '0.1.0\n'
}

derive_build_number() {
  if [[ -n "${GITHUB_RUN_NUMBER:-}" ]]; then
    printf '%s\n' "$GITHUB_RUN_NUMBER"
    return
  fi

  if count="$(git rev-list --count HEAD 2>/dev/null)"; then
    printf '%s\n' "$count"
    return
  fi

  printf '1\n'
}

VERSION="${VERSION:-$(derive_version)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(derive_build_number)}"

if [[ ! "$VERSION" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
  echo "release version must be numeric and dot-separated, such as 0.1.0" >&2
  exit 2
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+([.][0-9]+){0,2}$ ]]; then
  echo "build number must be numeric and dot-separated, such as 42" >&2
  exit 2
fi

if [[ "$NOTARIZE_RELEASE" == "1" && -z "$SIGN_IDENTITY" ]]; then
  echo "notarization requires CODESIGN_IDENTITY for Developer ID signing" >&2
  exit 2
fi

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

build_args=(--release)
if ((RUN_APP_SMOKE)); then
  build_args+=(--verify)
else
  build_args+=(--stage-only)
fi

env \
  APP_VERSION="$VERSION" \
  APP_BUILD="$BUILD_NUMBER" \
  SWIFT_WARNINGS_AS_ERRORS=1 \
  "$ROOT_DIR/script/build_and_run.sh" "${build_args[@]}"

sign_executables() {
  local sign_identity="$1"
  shift

  local file
  while IFS= read -r -d '' file; do
    "$@" "$sign_identity" "$file"
  done < <(/usr/bin/find "$APP_CONTENTS" -type f -perm -111 -print0)
}

developer_id_sign() {
  local identity="$1"
  local path="$2"
  /usr/bin/codesign --force --options runtime --timestamp --sign "$identity" "$path"
}

ad_hoc_sign() {
  local identity="$1"
  local path="$2"
  /usr/bin/codesign --force --sign "$identity" "$path"
}

if [[ -n "$SIGN_IDENTITY" ]]; then
  sign_executables "$SIGN_IDENTITY" developer_id_sign
  /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
elif [[ "$AD_HOC_SIGN" == "1" ]]; then
  sign_executables "-" ad_hoc_sign
  /usr/bin/codesign --force --sign - "$APP_BUNDLE"
else
  echo "warning: leaving app bundle unsigned because AD_HOC_SIGN=0" >&2
fi

if [[ -n "$SIGN_IDENTITY" || "$AD_HOC_SIGN" == "1" ]]; then
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
fi

ZIP_NAME="$ARTIFACT_PREFIX-$VERSION-macOS.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
CHECKSUM_PATH="$RELEASE_DIR/$ZIP_NAME.sha256"
NOTES_PATH="$RELEASE_DIR/$ARTIFACT_PREFIX-$VERSION-release-notes.md"

notarize_app_bundle() {
  local notary_zip="$RELEASE_DIR/$ARTIFACT_PREFIX-$VERSION-notary-submission.zip"
  local -a notarytool_args=()

  if [[ -n "$NOTARYTOOL_KEYCHAIN_PROFILE" ]]; then
    notarytool_args+=(--keychain-profile "$NOTARYTOOL_KEYCHAIN_PROFILE")
    if [[ -n "$NOTARYTOOL_KEYCHAIN" ]]; then
      notarytool_args+=(--keychain "$NOTARYTOOL_KEYCHAIN")
    fi
  elif [[ -n "$APPLE_ID" && -n "$APPLE_TEAM_ID" && -n "$APPLE_APP_SPECIFIC_PASSWORD" ]]; then
    notarytool_args+=(--apple-id "$APPLE_ID")
    notarytool_args+=(--team-id "$APPLE_TEAM_ID")
    notarytool_args+=(--password "$APPLE_APP_SPECIFIC_PASSWORD")
  else
    echo "notarization requires NOTARYTOOL_KEYCHAIN_PROFILE or Apple ID credentials" >&2
    exit 2
  fi

  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$notary_zip"
  /usr/bin/xcrun notarytool submit "$notary_zip" "${notarytool_args[@]}" \
    --wait --timeout "$NOTARYTOOL_TIMEOUT"
  /usr/bin/xcrun stapler staple "$APP_BUNDLE"
  /usr/bin/xcrun stapler validate "$APP_BUNDLE"
  /usr/sbin/spctl --assess --type execute --verbose=4 "$APP_BUNDLE"
  rm -f "$notary_zip"
}

if [[ "$NOTARIZE_RELEASE" == "1" ]]; then
  notarize_app_bundle
fi

/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

(
  cd "$RELEASE_DIR"
  /usr/bin/shasum -a 256 "$ZIP_NAME" >"$(basename "$CHECKSUM_PATH")"
)

{
  printf '# Codex Keyring %s\n\n' "$VERSION"
  printf -- '- Build: `%s`\n' "$BUILD_NUMBER"
  printf -- '- Artifact: `%s`\n' "$ZIP_NAME"
  printf -- '- SHA256: see `%s`\n\n' "$(basename "$CHECKSUM_PATH")"
  printf 'This build is produced from the SwiftPM release configuration.\n\n'
  if [[ "$NOTARIZE_RELEASE" == "1" ]]; then
    printf 'The app bundle was Developer ID signed, notarized, stapled, and '
    printf 'validated with Gatekeeper before packaging.\n'
  elif [[ -n "$SIGN_IDENTITY" ]]; then
    printf 'The app bundle was Developer ID signed, but notarization was not '
    printf 'enabled for this build. macOS Gatekeeper may warn before first '
    printf 'launch.\n'
  else
    printf 'This build uses ad hoc signing. Configure the release workflow with '
    printf 'a Developer ID signing identity and notarization secrets before '
    printf 'treating it as a public macOS distribution build.\n'
  fi
} >"$NOTES_PATH"

printf 'Release package written:\n'
printf '  %s\n' "$ZIP_PATH"
printf '  %s\n' "$CHECKSUM_PATH"
printf '  %s\n' "$NOTES_PATH"
