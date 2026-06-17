#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PROCESS_NAME="CodexKeyring"
RUN_APP_SMOKE=0
CLEAN_BUILD=0
RUN_RELEASE_BUILD=0
SWIFT_WARNING_FLAGS=(-Xswiftc -warnings-as-errors)

usage() {
  cat <<USAGE
usage: $0 [--app] [--clean] [--release]

Runs the standard Codex Keyring verification checks.

Options:
  --app       also build, launch, verify, and cleanly exit the staged app
  --clean     clear SwiftPM build artifacts before running checks
  --release   also compile the SwiftPM release configuration; with --app,
              smoke-test the staged release app bundle
  -h,--help   show this help
USAGE
}

while (($#)); do
  case "$1" in
    --app)
      RUN_APP_SMOKE=1
      ;;
    --clean)
      CLEAN_BUILD=1
      ;;
    --release)
      RUN_RELEASE_BUILD=1
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

run_step() {
  printf '\n==> %s\n' "$*"
  "$@"
}

check_untracked_text_clean() {
  local failed=0
  local file
  while IFS= read -r -d '' file; do
    case "$file" in
      *.swift|*.sh|*.md|*.toml|*.json|*.yml|*.yaml|Package.swift) ;;
      *) continue ;;
    esac

    local line_number=0
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
      ((line_number += 1))
      if [[ "$line" =~ [[:space:]]$ ]]; then
        printf '%s:%d: trailing whitespace.\n' "$file" "$line_number" >&2
        failed=1
      fi
      if [[ "$line" == "<<<<<<<"* || "$line" == "=======" || "$line" == ">>>>>>>"* || "$line" == "|||||||"* ]]; then
        printf '%s:%d: conflict marker.\n' "$file" "$line_number" >&2
        failed=1
      fi
    done < "$file"
  done < <(git -C "$ROOT_DIR" ls-files --others --exclude-standard -z -- .github .githooks Sources Tests script Package.swift README.md ROADMAP.md)

  return "$failed"
}

check_app_not_running() {
  if pgrep -x "$APP_PROCESS_NAME" >/dev/null; then
    echo "$APP_PROCESS_NAME is still running after app smoke verification." >&2
    return 1
  fi
}

if ((CLEAN_BUILD)); then
  run_step swift package clean
fi

run_step swift test "${SWIFT_WARNING_FLAGS[@]}"

if ((RUN_RELEASE_BUILD)); then
  run_step swift build -c release "${SWIFT_WARNING_FLAGS[@]}"
fi

run_step bash -n "$ROOT_DIR/script/build_and_run.sh"
run_step bash -n "$ROOT_DIR/script/package_release.sh"
run_step bash -n "$ROOT_DIR/script/validate_commit_message.sh"
run_step bash -n "$ROOT_DIR/script/verify.sh"
run_step sh -n "$ROOT_DIR/.githooks/commit-msg"
run_step git -C "$ROOT_DIR" diff --check
run_step check_untracked_text_clean

if ((RUN_APP_SMOKE)); then
  app_smoke_args=(--verify)
  if ((RUN_RELEASE_BUILD)); then
    app_smoke_args+=(--release)
  fi
  run_step env SWIFT_WARNINGS_AS_ERRORS=1 "$ROOT_DIR/script/build_and_run.sh" "${app_smoke_args[@]}"
  run_step check_app_not_running
fi
