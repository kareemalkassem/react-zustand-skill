#!/usr/bin/env bash
# PostToolUse hook: run eslint --fix on the file Claude just edited.
#
# This hook MUST NEVER BLOCK. It exits 0 on every path — a formatting tool that
# can fail a tool call turns a cosmetic problem into a stopped session.

set +e

payload=$(cat 2>/dev/null)
[ -z "$payload" ] && exit 0

# Pull file_path out of the hook payload without requiring jq.
file_path=$(printf '%s' "$payload" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -n 1 \
  | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//' \
  | sed 's/\\\\/\//g')

[ -z "$file_path" ] && exit 0
[ -f "$file_path" ] || exit 0

case "$file_path" in
  *.js|*.jsx|*.mjs|*.cjs|*.ts|*.tsx) ;;
  *) exit 0 ;;
esac

# Walk up from the file to find the nearest package.json (monorepo-safe).
dir=$(dirname "$file_path")
project_root=""
while [ "$dir" != "/" ] && [ -n "$dir" ] && [ "$dir" != "." ]; do
  if [ -f "$dir/package.json" ]; then
    project_root="$dir"
    break
  fi
  parent=$(dirname "$dir")
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

[ -z "$project_root" ] && exit 0
[ -d "$project_root/node_modules/.bin" ] || exit 0

if [ -x "$project_root/node_modules/.bin/eslint" ]; then
  (cd "$project_root" && ./node_modules/.bin/eslint --fix "$file_path" >/dev/null 2>&1)
elif [ -x "$project_root/node_modules/.bin/prettier" ]; then
  (cd "$project_root" && ./node_modules/.bin/prettier --write "$file_path" >/dev/null 2>&1)
fi

exit 0
