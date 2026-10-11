#!/bin/bash
# PostToolUse hook (Write|Edit): format Python files with ruff, preferring the
# project's pinned ruff so its version and config apply. Parse errors go back
# to Claude (exit 2 sends stderr to the model).
set -u

f=$(jq -r '.tool_input.file_path // .tool_response.filePath // empty')
[ -n "$f" ] && [ -f "$f" ] || exit 0

case "$f" in
*.py | *.pyi) ;;
*) exit 0 ;;
esac

ruff=()
d=$(dirname "$f")
while [ "$d" != "/" ]; do
  if [ -x "$d/.venv/bin/ruff" ]; then
    ruff=("$d/.venv/bin/ruff")
    break
  fi
  d=$(dirname "$d")
done
if [ ${#ruff[@]} -eq 0 ]; then
  if command -v ruff >/dev/null 2>&1; then
    ruff=(ruff)
  elif command -v uvx >/dev/null 2>&1; then
    ruff=(uvx ruff)
  else
    exit 0
  fi
fi

if ! err=$("${ruff[@]}" format --no-cache "$f" 2>&1); then
  printf 'ruff format could not parse %s:\n%s\n' "$f" "$err" >&2
  exit 2
fi

exit 0
