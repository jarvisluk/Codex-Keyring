#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PROCESS_NAME="CodexKeyring"
RUN_APP_SMOKE=0
CLEAN_BUILD=0
RUN_RELEASE_BUILD=0
SWIFT_WARNING_FLAGS=(-Xswiftc -warnings-as-errors)
SWIFT_TEST_TIMEOUT_SECONDS="${VERIFY_SWIFT_TEST_TIMEOUT_SECONDS:-600}"

usage() {
  cat <<USAGE
usage: $0 [--app] [--clean] [--release]

Runs the standard Codex Keyring verification checks.

Options:
  --app       also build, launch, verify, and cleanly exit the staged app
  --clean     clear SwiftPM build artifacts before running checks
  --release   also compile and package the SwiftPM release configuration;
              with --app, smoke-test the staged release app bundle
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

check_toolchain_health() {
  swift --version >/dev/null
  xcodebuild -version >/dev/null
  xcrun --sdk macosx --show-sdk-version >/dev/null
}

require_positive_integer() {
  local name="$1"
  local value="$2"

  if [[ ! "$value" =~ ^[0-9]+$ || "$value" == "0" ]]; then
    echo "$name must be a positive integer." >&2
    return 2
  fi
}

terminate_process_tree() {
  local pid="$1"
  local signal="${2:-TERM}"
  local child

  while IFS= read -r child; do
    [[ -n "$child" ]] || continue
    terminate_process_tree "$child" "$signal"
  done < <(pgrep -P "$pid" 2>/dev/null || true)

  kill "-$signal" "$pid" 2>/dev/null || true
}

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  local marker="${TMPDIR:-/tmp}/codex-keyring-verify-timeout-$$-$RANDOM"
  "$@" &
  local command_pid=$!

  (
    sleep "$timeout_seconds"
    if kill -0 "$command_pid" 2>/dev/null; then
      printf 'command timed out after %s seconds: %s\n' "$timeout_seconds" "$*" >&2
      : >"$marker"
      terminate_process_tree "$command_pid" TERM
      sleep 5
      terminate_process_tree "$command_pid" KILL
    fi
  ) &
  local watchdog_pid=$!

  local status=0
  wait "$command_pid" || status=$?
  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true

  if [[ -f "$marker" ]]; then
    rm -f "$marker"
    return 124
  fi

  return "$status"
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

check_tracked_sensitive_files() {
  local failed=0
  local file

  while IFS= read -r -d '' file; do
    case "$file" in
      .env|.env.*|*.env|*.env.*|*.p12|*.pfx|*.pem|*.key|*.keystore|*.jks|*.mobileprovision|*.auth.json|auth.json|id_rsa|id_ed25519)
        case "$file" in
          .env.example|*.env.example|*.example.env) ;;
          *)
            printf '%s: tracked sensitive credential-like file.\n' "$file" >&2
            failed=1
            ;;
        esac
        ;;
    esac
  done < <(git -C "$ROOT_DIR" ls-files -z)

  return "$failed"
}

check_tracked_secret_material() {
  local matches
  local status=0
  matches="$(
    git -C "$ROOT_DIR" grep -nI -E -e \
      '-----BEGIN ((RSA|DSA|EC|OPENSSH) )?PRIVATE KEY-----|sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}' \
      -- . \
      ':(exclude)docs/release.md' \
      ':(exclude)README.md'
  )" || status=$?

  if ((status > 1)); then
    return "$status"
  fi

  if [[ -n "$matches" ]]; then
    printf '%s\n' "$matches" >&2
    return 1
  fi
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

run_step check_toolchain_health
run_step require_positive_integer VERIFY_SWIFT_TEST_TIMEOUT_SECONDS "$SWIFT_TEST_TIMEOUT_SECONDS"
run_step run_with_timeout "$SWIFT_TEST_TIMEOUT_SECONDS" swift test "${SWIFT_WARNING_FLAGS[@]}"

if ((RUN_RELEASE_BUILD)); then
  run_step swift build -c release "${SWIFT_WARNING_FLAGS[@]}"
  run_step bash "$ROOT_DIR/script/package_release.sh" --version 0.0.0 --build 0
fi

run_step bash -n "$ROOT_DIR/script/build_and_run.sh"
run_step bash -n "$ROOT_DIR/script/generate_appcast.sh"
run_step bash -n "$ROOT_DIR/script/package_release.sh"
run_step bash -n "$ROOT_DIR/script/validate_commit_message.sh"
run_step bash -n "$ROOT_DIR/script/verify.sh"
run_step sh -n "$ROOT_DIR/.githooks/commit-msg"
run_step check_tracked_sensitive_files
run_step check_tracked_secret_material
run_step git -C "$ROOT_DIR" diff --check
run_step check_untracked_text_clean

if ((RUN_APP_SMOKE)); then
  app_smoke_args=(--verify)
  if ((RUN_RELEASE_BUILD)); then
    app_smoke_args+=(--release)
  fi
  run_step env SWIFT_WARNINGS_AS_ERRORS=1 bash "$ROOT_DIR/script/build_and_run.sh" "${app_smoke_args[@]}"
  run_step check_app_not_running
fi
