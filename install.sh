#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:?Usage: install.sh /path/to/repo}
[[ ! -d "$TARGET/.git" ]] && { echo "✖ $TARGET is not a Git repo"; exit 1; }

mkdir -p "$TARGET/.cc/scripts"
cp -R scripts/* "$TARGET/.cc/scripts/"
cp scripts/templates/.ccenv.example "$TARGET/.cc/.ccenv.example"

echo 'export PATH="$PATH:$(git rev-parse --show-toplevel)/.cc/scripts"' >> "$TARGET/.envrc" || true

echo "✔ Claude dev scripts installed in $TARGET"