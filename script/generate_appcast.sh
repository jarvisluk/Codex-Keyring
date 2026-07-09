#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
SPARKLE_PRIVATE_ED_KEY="${SPARKLE_PRIVATE_ED_KEY:-}"
SPARKLE_PRIVATE_ED_KEY_FILE="${SPARKLE_PRIVATE_ED_KEY_FILE:-}"
APPCAST_DOWNLOAD_URL_PREFIX="${APPCAST_DOWNLOAD_URL_PREFIX:-}"

usage() {
  cat <<USAGE
usage: $0

Generates dist/release/appcast.xml for the zip files produced by
script/package_release.sh.

Environment:
  SPARKLE_PRIVATE_ED_KEY=<key>        private EdDSA key exported by Sparkle
  SPARKLE_PRIVATE_ED_KEY_FILE=<path>  private key file to use instead
  APPCAST_DOWNLOAD_URL_PREFIX=<url>   public URL prefix for release assets
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

cd "$ROOT_DIR"

if [[ -z "$APPCAST_DOWNLOAD_URL_PREFIX" ]]; then
  echo "APPCAST_DOWNLOAD_URL_PREFIX is required." >&2
  exit 2
fi

if [[ ! -d "$RELEASE_DIR" ]]; then
  echo "release directory does not exist: $RELEASE_DIR" >&2
  exit 2
fi

find_generate_appcast() {
  find "$ROOT_DIR/.build" \
    -path "*/Sparkle/bin/generate_appcast" \
    -type f \
    -print \
    2>/dev/null | head -n 1
}

generate_appcast="$(find_generate_appcast)"
if [[ -z "$generate_appcast" ]]; then
  echo "Sparkle generate_appcast tool was not found under .build." >&2
  exit 1
fi

private_key_file="$SPARKLE_PRIVATE_ED_KEY_FILE"
temporary_key_file=""
cleanup() {
  if [[ -n "$temporary_key_file" ]]; then
    rm -f "$temporary_key_file"
  fi
}
trap cleanup EXIT

if [[ -z "$private_key_file" ]]; then
  if [[ -z "$SPARKLE_PRIVATE_ED_KEY" ]]; then
    echo "SPARKLE_PRIVATE_ED_KEY or SPARKLE_PRIVATE_ED_KEY_FILE is required." >&2
    exit 2
  fi

  temporary_key_file="$(mktemp)"
  chmod 600 "$temporary_key_file"
  printf '%s' "$SPARKLE_PRIVATE_ED_KEY" >"$temporary_key_file"
  private_key_file="$temporary_key_file"
fi

help_text="$("$generate_appcast" --help 2>&1 || true)"

download_prefix_args=()
if grep -q -- "--download-url-prefix" <<<"$help_text"; then
  download_prefix_args=(--download-url-prefix "$APPCAST_DOWNLOAD_URL_PREFIX")
elif grep -q -- "--download-prefix-url" <<<"$help_text"; then
  download_prefix_args=(--download-prefix-url "$APPCAST_DOWNLOAD_URL_PREFIX")
else
  echo "generate_appcast does not expose a supported download URL prefix option." >&2
  exit 1
fi

key_args=()
if grep -q -- "--ed-key-file" <<<"$help_text"; then
  key_args=(--ed-key-file "$private_key_file")
else
  echo "generate_appcast does not support --ed-key-file; refusing to pass the private key on the command line." >&2
  exit 1
fi

"$generate_appcast" \
  "${key_args[@]}" \
  "${download_prefix_args[@]}" \
  --embed-release-notes \
  "$RELEASE_DIR"

if [[ ! -f "$RELEASE_DIR/appcast.xml" ]]; then
  echo "generate_appcast did not create $RELEASE_DIR/appcast.xml." >&2
  exit 1
fi

printf 'Sparkle appcast written:\n'
printf '  %s\n' "$RELEASE_DIR/appcast.xml"
