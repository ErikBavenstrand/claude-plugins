#!/bin/bash
# PostToolUse hook (Write|Edit): format shell scripts with shfmt, then report
# any lint findings back to Claude (exit 2 sends stderr to the model).
set -u

f=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
[ -n "$f" ] && [ -f "$f" ] || exit 0

case "$f" in
*.sh | *.bash) ;;
*/bin/*) head -n 1 "$f" | grep -qE '^#!.*\b(ba|z)?sh\b' || exit 0 ;;
*) exit 0 ;;
esac

if command -v shfmt >/dev/null 2>&1; then
  if ! err=$(shfmt -w -i 2 "$f" 2>&1); then
    printf 'shfmt could not parse %s:\n%s\n' "$f" "$err" >&2
    exit 2
  fi
fi

if command -v shellcheck >/dev/null 2>&1; then
  if ! out=$(shellcheck -f gcc "$f" 2>&1); then
    printf 'shellcheck findings in %s (fix them):\n%s\n' "$f" "$out" >&2
    exit 2
  fi
fi

exit 0
