#!/usr/bin/env bash
set -euo pipefail

APP_NAME="CodexKeyring"
BUNDLE_NAME="Codex Keyring"
BUNDLE_ID="com.junrong.CodexKeyring"
MIN_SYSTEM_VERSION="14.0"
MODE=""
BUILD_CONFIGURATION="debug"
APP_VERSION="${APP_VERSION:-0.1.0}"
APP_BUILD="${APP_BUILD:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$BUNDLE_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON_SOURCE="$ROOT_DIR/Resources/AppIcon.icns"
APP_ICON_NAME="AppIcon"
MENU_BAR_ICON_SOURCE="$ROOT_DIR/Resources/MenuBarIcon.svg"
VERIFY_TIMEOUT_SECONDS="${VERIFY_TIMEOUT_SECONDS:-10}"
VERIFY_KEEP_APP="${VERIFY_KEEP_APP:-0}"
SWIFT_WARNINGS_AS_ERRORS="${SWIFT_WARNINGS_AS_ERRORS:-0}"

cd "$ROOT_DIR"

usage() {
  cat <<USAGE
usage: $0 [run|--stage-only|--debug|--logs|--telemetry|--verify] [--release]

Builds the SwiftPM target, stages dist/Codex Keyring.app, and runs the
requested mode.

Options:
  --release   stage the release build instead of debug
  -h,--help   show this help

Environment:
  SWIFT_WARNINGS_AS_ERRORS=1   compile Swift sources with warnings as errors
  APP_VERSION=0.1.0            set CFBundleShortVersionString
  APP_BUILD=1                  set CFBundleVersion
USAGE
}

while (($#)); do
  case "$1" in
    run|--stage-only|stage|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
      if [[ -n "$MODE" ]]; then
        echo "only one mode can be provided" >&2
        usage >&2
        exit 2
      fi
      MODE="$1"
      ;;
    --release)
      BUILD_CONFIGURATION="release"
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

MODE="${MODE:-run}"

swift_build_args=()
if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  swift_build_args=(-c release)
fi
if [[ "$SWIFT_WARNINGS_AS_ERRORS" == "1" ]]; then
  swift_build_args+=(-Xswiftc -warnings-as-errors)
fi

stop_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

swift build ${swift_build_args[@]+"${swift_build_args[@]}"}
BUILD_BINARY="$(swift build ${swift_build_args[@]+"${swift_build_args[@]}"} --show-bin-path)/$APP_NAME"

stop_app

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$APP_ICON_SOURCE" "$APP_RESOURCES/$APP_ICON_NAME.icns"
cp "$MENU_BAR_ICON_SOURCE" "$APP_RESOURCES/MenuBarIcon.svg"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$BUNDLE_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$APP_ICON_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

wait_for_app() {
  local deadline=$((SECONDS + VERIFY_TIMEOUT_SECONDS))
  while (( SECONDS < deadline )); do
    if pgrep -x "$APP_NAME" >/dev/null; then
      return 0
    fi
    sleep 0.25
  done

  echo "Codex Keyring did not launch within ${VERIFY_TIMEOUT_SECONDS}s." >&2
  return 1
}

wait_for_main_window() {
  if /usr/bin/swift - "$VERIFY_TIMEOUT_SECONDS" <<'SWIFT' >/dev/null 2>&1
import CoreGraphics
import Darwin
import Foundation

let timeout = TimeInterval(CommandLine.arguments.dropFirst().first ?? "10") ?? 10
let deadline = Date().addingTimeInterval(timeout)

func mainWindowCount() -> Int {
  let windows = CGWindowListCopyWindowInfo(
    CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements),
    kCGNullWindowID
  ) as? [[String: Any]] ?? []

  return windows.filter { window in
    guard (window[kCGWindowOwnerName as String] as? String) == "Codex Keyring" else {
      return false
    }
    guard let bounds = window[kCGWindowBounds as String] as? [String: Any] else {
      return true
    }
    let width = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
    let height = (bounds["Height"] as? NSNumber)?.doubleValue ?? 0
    return width >= 600 && height >= 400
  }.count
}

while Date() < deadline {
  if mainWindowCount() == 1 {
    exit(0)
  }
  Thread.sleep(forTimeInterval: 0.25)
}

exit(1)
SWIFT
  then
    return 0
  fi
  echo "Codex Keyring launched, but exactly one main window did not appear within ${VERIFY_TIMEOUT_SECONDS}s." >&2
  return 1
}

case "$MODE" in
  --stage-only|stage)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    if [[ "$VERIFY_KEEP_APP" != "1" ]]; then
      trap stop_app EXIT
    fi
    open_app
    wait_for_app
    wait_for_main_window
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
