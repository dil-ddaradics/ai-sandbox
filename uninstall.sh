#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:?Usage: uninstall.sh /path/to/repo}
[[ ! -d "$TARGET/.git" ]] && { echo "✖ $TARGET is not a Git repo"; exit 1; }

find "$TARGET" -name .env.compose -print0 | while IFS= read -r -d '' ENVF; do
  docker compose --env-file "$ENVF" down || true
done

rm -rf "$TARGET/.cc"
sed -i '' '/.cc\/scripts/d' "$TARGET/.envrc" 2>/dev/null || true

echo "✔ Uninstalled Claude dev tooling from $TARGET"