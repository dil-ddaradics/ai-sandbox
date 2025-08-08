#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:?Usage: uninstall.sh /path/to/repo}
[[ ! -d "$TARGET/.git" ]] && { echo "✖ $TARGET is not a Git repo"; exit 1; }

# Shut down any running containers
echo "Stopping any running containers..."
find "$TARGET" -name .env.compose -print0 | while IFS= read -r -d '' ENVF; do
  docker compose --env-file "$ENVF" down || true
done

# Remove the scripts directory
echo "Removing scripts directory..."
rm -rf "$TARGET/.cc"

# Clean up .envrc if it exists
if [[ -f "$TARGET/.envrc" ]]; then
  echo "Cleaning up PATH in .envrc..."
  if command -v direnv &> /dev/null; then
    # Use platform-specific sed syntax
    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS requires empty string with -i
      sed -i '' '/.cc\/scripts/d' "$TARGET/.envrc" 2>/dev/null || echo "⚠️ Could not modify .envrc, you may need to edit it manually"
    else
      # Linux and others
      sed -i '/.cc\/scripts/d' "$TARGET/.envrc" 2>/dev/null || echo "⚠️ Could not modify .envrc, you may need to edit it manually"
    fi
    echo "✓ Removed AI sandbox scripts from PATH in .envrc"
  else
    echo "⚠️ direnv not installed, but .envrc exists"
    echo "If you manually added AI sandbox scripts to your PATH, you may need to remove them"
  fi
fi

echo "✔ Uninstalled AI sandbox tooling from $TARGET"