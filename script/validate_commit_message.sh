#!/bin/bash
set -euo pipefail

usage() {
  cat <<USAGE
usage: $0 <commit-message-file>

Validates Codex Keyring commit messages against AGENTS.md rules.
USAGE
}

if (($# != 1)); then
  usage >&2
  exit 2
fi

message_file="$1"
if [[ ! -f "$message_file" ]]; then
  echo "commit message file not found: $message_file" >&2
  exit 2
fi

allowed_types="feat|fix|refactor|perf|docs|style|test|build|ci|chore|revert"
failed=0
lines=()

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == \#* ]] && continue
  line="${line%$'\r'}"
  lines+=("$line")
done < "$message_file"

fail() {
  echo "invalid commit message: $*" >&2
  failed=1
}

header=""
header_index=-1
for index in "${!lines[@]}"; do
  line="${lines[$index]}"
  if [[ -n "${line//[[:space:]]/}" ]]; then
    header="$line"
    header_index="$index"
    break
  fi
done

if [[ -z "$header" ]]; then
  fail "message is empty"
fi

if printf '%s\n' "${lines[@]}" | perl -ne 'exit 1 if /[^\x09\x0a\x20-\x7e]/'; then
  :
else
  fail "message must be English ASCII text"
fi

if printf '%s\n' "${lines[@]}" | grep -Eiq 'Generated with|Co-Authored-By:'; then
  fail "tool signatures are not allowed"
fi

if [[ -n "$header" ]]; then
  header_pattern="^(${allowed_types})(\\([a-z0-9][a-z0-9-]*\\))?: [a-z0-9]"
  if [[ ! "$header" =~ $header_pattern ]]; then
    fail "header must match '<type>(<scope>): <subject>'"
    echo "allowed types: ${allowed_types//|/, }" >&2
  else
    subject="${header#*: }"

    if ((${#subject} > 72)); then
      fail "subject must be 72 characters or fewer"
    fi

    if [[ "$subject" == *. ]]; then
      fail "subject must not end with a period"
    fi

    case "$subject" in
      "update code"|"fix bug"|"misc changes"|"misc"|"changes"|"update"|"wip"|"work in progress")
        fail "subject is too vague"
        ;;
    esac
  fi

  next_content_index=-1
  for ((index = header_index + 1; index < ${#lines[@]}; index += 1)); do
    if [[ -n "${lines[$index]//[[:space:]]/}" ]]; then
      next_content_index="$index"
      break
    fi
  done

  if ((next_content_index >= 0)) && [[ -n "${lines[$((header_index + 1))]//[[:space:]]/}" ]]; then
    fail "body or footer must be separated from the subject by a blank line"
  fi
fi

for index in "${!lines[@]}"; do
  ((index == header_index)) && continue
  line="${lines[$index]}"
  [[ -z "$line" ]] && continue
  if ((${#line} > 72)); then
    fail "line $((index + 1)) exceeds 72 characters"
  fi
done

if ((failed)); then
  cat >&2 <<'HELP'

Expected format:
  <type>(<scope>): <subject>

Example:
  fix(oauth): handle expired refresh token before switching

Subject rules:
  - lowercase start
  - no trailing period
  - 72 characters or fewer
  - no vague subjects such as "update code", "fix bug", or "misc changes"
HELP
  exit 1
fi
