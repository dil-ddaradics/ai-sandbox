#!/usr/bin/env bash
set -euo pipefail

# Process command line arguments
NON_INTERACTIVE=0
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --non-interactive)
      NON_INTERACTIVE=1
      ;;
    --help)
      echo "Usage: uninstall.sh [OPTIONS] /path/to/repo"
      echo
      echo "Options:"
      echo "  --non-interactive   Run in non-interactive mode (no prompts)"
      echo "  --help              Show this help message"
      echo
      exit 0
      ;;
    *)
      if [[ -z "$TARGET" ]]; then
        TARGET="$arg"
      fi
      ;;
  esac
done

# Check if target is provided
if [[ -z "$TARGET" ]]; then
  echo "Usage: uninstall.sh [--non-interactive] /path/to/repo"
  exit 1
fi

# Validate target is a git repo
[[ ! -d "$TARGET/.git" ]] && { echo "✖ $TARGET is not a Git repo"; exit 1; }

# Shut down any running containers
if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
  echo "Automatically stopping any running containers (non-interactive mode)..."
else
  echo "Stopping any running containers..."
find "$TARGET" -name .env.compose -print0 | while IFS= read -r -d '' ENVF; do
  docker compose --env-file "$ENVF" down || true
done

# If interactive, confirm before proceeding
if [[ "$NON_INTERACTIVE" -eq 0 ]]; then
  echo
  read -p "Are you sure you want to remove the AI sandbox from $TARGET? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
  fi
fi

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

# Close the if statement from above
if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
  echo
fi