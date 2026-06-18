#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/release"
APP_BUNDLE="$DIST_DIR/Codex Keyring.app"
ARTIFACT_PREFIX="CodexKeyring"
RUN_APP_SMOKE=0
SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
AD_HOC_SIGN="${AD_HOC_SIGN:-1}"
VERSION="${APP_VERSION:-}"
BUILD_NUMBER="${APP_BUILD:-}"
SPARKLE_REQUIRED="${SPARKLE_REQUIRED:-0}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"

usage() {
  cat <<USAGE
usage: $0 [--version <version>] [--build <number>] [--app-smoke]

Builds the release app bundle, signs it when possible, packages it as a zip,
and writes a SHA256 checksum under dist/release.

Options:
  --version <version>   release version, such as 0.1.0; defaults to a v* tag
                        when available, then 0.1.0
  --build <number>      build number; defaults to GITHUB_RUN_NUMBER, then the
                        git commit count
  --app-smoke           launch and verify the staged release app before zipping
  -h,--help             show this help

Environment:
  APP_VERSION=0.1.0           same as --version
  APP_BUILD=1                 same as --build
  CODESIGN_IDENTITY=<name>    sign with a Developer ID/Application identity
  AD_HOC_SIGN=0               skip default ad hoc signing
  SPARKLE_FEED_URL=<url>       appcast URL to embed for automatic updates
  SPARKLE_PUBLIC_ED_KEY=<key>  public EdDSA key to embed for update checks
  SPARKLE_REQUIRED=1           fail when Sparkle release settings are missing
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

if [[ "$SPARKLE_REQUIRED" == "1" || "$SPARKLE_REQUIRED" == "true" ]]; then
  if [[ -z "$SPARKLE_FEED_URL" || -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    echo "SPARKLE_FEED_URL and SPARKLE_PUBLIC_ED_KEY are required for update-enabled releases." >&2
    exit 2
  fi
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
  SPARKLE_FEED_URL="$SPARKLE_FEED_URL" \
  SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY" \
  SWIFT_WARNINGS_AS_ERRORS=1 \
  "$ROOT_DIR/script/build_and_run.sh" "${build_args[@]}"

if [[ -n "$SIGN_IDENTITY" ]]; then
  /usr/bin/codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
elif [[ "$AD_HOC_SIGN" == "1" ]]; then
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
APPCAST_NOTES_PATH="$RELEASE_DIR/${ZIP_NAME%.zip}.md"

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
  printf 'This build is produced from the SwiftPM release configuration. '
  printf 'Unless the workflow is configured with a Developer ID signing identity '
  printf 'and notarization steps, macOS Gatekeeper may warn before first launch.\n'
} >"$NOTES_PATH"
cp "$NOTES_PATH" "$APPCAST_NOTES_PATH"

printf 'Release package written:\n'
printf '  %s\n' "$ZIP_PATH"
printf '  %s\n' "$CHECKSUM_PATH"
printf '  %s\n' "$NOTES_PATH"
