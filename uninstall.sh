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
fi

# Get repository name
REPO_NAME=$(basename "$TARGET")

# Stop and remove any containers related to this repo using .env.compose files
find "$TARGET" -name .env.compose -print0 | while IFS= read -r -d '' ENVF; do
  echo "Stopping containers with env file: $ENVF"
  docker compose --env-file "$ENVF" down || true
done

# Check for container file to find container name
if [[ -f "$TARGET/.cc-container" ]]; then
  CONTAINER_NAME=$(cat "$TARGET/.cc-container")
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
    echo "Removing container: $CONTAINER_NAME"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
  fi
fi

# Find and remove any containers with names related to the repo
CONTAINERS=$(docker ps -a --format '{{.Names}}' | grep -E "cc-$REPO_NAME" || true)
if [[ -n "$CONTAINERS" ]]; then
  echo "Found related containers:"
  echo "$CONTAINERS"
  for CONTAINER in $CONTAINERS; do
    echo "Removing container: $CONTAINER"
    docker stop "$CONTAINER" 2>/dev/null || true
    docker rm "$CONTAINER" 2>/dev/null || true
  done
fi

# Find and remove any images related to the repo
IMAGES=$(docker images --format '{{.Repository}}' | grep -E "$REPO_NAME" || true)
if [[ -n "$IMAGES" ]]; then
  echo "Found related images:"
  echo "$IMAGES"
  for IMAGE in $IMAGES; do
    echo "Removing image: $IMAGE"
    docker rmi "$IMAGE" 2>/dev/null || true
  done
fi

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

# Remove the scripts directory (handle both old .cc and new .ai paths)
echo "Removing scripts directory..."
[[ -d "$TARGET/.cc" ]] && rm -rf "$TARGET/.cc" && echo "✓ Removed old .cc directory"
[[ -d "$TARGET/.ai" ]] && rm -rf "$TARGET/.ai" && echo "✓ Removed .ai directory"

# Remove Docker-related files
echo "Removing Docker-related files..."
# Remove container files and env file
[[ -f "$TARGET/.cc-container" ]] && rm -f "$TARGET/.cc-container" && echo "✓ Removed .cc-container"
[[ -f "$TARGET/.ai-container" ]] && rm -f "$TARGET/.ai-container" && echo "✓ Removed .ai-container"
[[ -f "$TARGET/.env.compose" ]] && rm -f "$TARGET/.env.compose" && echo "✓ Removed .env.compose"
# Remove legacy Docker files from root if they exist
[[ -f "$TARGET/Dockerfile" ]] && rm -f "$TARGET/Dockerfile" && echo "✓ Removed legacy Dockerfile"
[[ -f "$TARGET/docker-compose.yml" ]] && rm -f "$TARGET/docker-compose.yml" && echo "✓ Removed legacy docker-compose.yml"
# Remove legacy container scripts if they exist
[[ -d "$TARGET/scripts/container" ]] && rm -rf "$TARGET/scripts/container" && echo "✓ Removed legacy container scripts"

# Clean up .envrc if it exists
if [[ -f "$TARGET/.envrc" ]]; then
  echo "Cleaning up PATH in .envrc..."
  if command -v direnv &> /dev/null; then
    # Use platform-specific sed syntax
    if [[ "$(uname)" == "Darwin" ]]; then
      # macOS requires empty string with -i
      sed -i '' '/.cc\/scripts/d' "$TARGET/.envrc" 2>/dev/null || echo "⚠️ Could not remove old .cc paths from .envrc"
      sed -i '' '/.ai\/scripts/d' "$TARGET/.envrc" 2>/dev/null || echo "⚠️ Could not remove .ai paths from .envrc"
    else
      # Linux and others
      sed -i '/.cc\/scripts/d' "$TARGET/.envrc" 2>/dev/null || echo "⚠️ Could not remove old .cc paths from .envrc"
      sed -i '/.ai\/scripts/d' "$TARGET/.envrc" 2>/dev/null || echo "⚠️ Could not remove .ai paths from .envrc"
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