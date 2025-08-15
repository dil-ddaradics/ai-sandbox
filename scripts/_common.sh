#!/usr/bin/env bash
set -euo pipefail

# -------- util helpers ----------
_red()  { printf "\\e[31m%s\\e[0m\\n" "$*"; }
_green(){ printf "\\e[32m%s\\e[0m\\n" "$*"; }
_yellow(){ printf "\\e[33m%s\\e[0m\\n" "$*"; }
_die()  { _red "✖ $*"; exit 1; }

_need() {
  command -v "$1" >/dev/null 2>&1 || _die "Missing dependency: $1"
}

# -------- load config -----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_REPO="$(git -C "$SCRIPT_DIR/../.." rev-parse --show-toplevel 2>/dev/null || true)"

# repo‑local env overrides - try new location first, fallback to legacy
if [[ -f "$ROOT_REPO/.ai/.aienv" ]]; then
  source "$ROOT_REPO/.ai/.aienv"
# Legacy path, no longer needed
# elif [[ -f "$ROOT_REPO/.cc/.ccenv" ]]; then
#   source "$ROOT_REPO/.cc/.ccenv"
fi

# user‑global overrides - try new location first, fallback to legacy
if [[ -f "$HOME/.aienv" ]]; then
  source "$HOME/.aienv"
# Legacy path, no longer needed
# elif [[ -f "$HOME/.ccenv" ]]; then
#   source "$HOME/.ccenv"
fi

# defaults
USE_DIRENV="${USE_DIRENV:-1}"
WT_ROOT="${WT_ROOT:-$HOME/worktrees}"
CLAUDE_CODE_USE_BEDROCK="${CLAUDE_CODE_USE_BEDROCK:-1}"
AWS_REGION="${AWS_REGION:-us-west-2}"
CPU_LIMIT="${CPU_LIMIT:-}"
MEM_LIMIT="${MEM_LIMIT:-}"

# Auto-load IMDS URL if not already in env
if [[ -z "${IMDS_URL:-}" ]]; then
  # Try new location first, fallback to legacy/
  if [[ -f "$HOME/.ai/awsvault_url" ]]; then
    IMDS_URL=$(< "$HOME/.ai/awsvault_url")
  # Legacy path, no longer needed
  # elif [[ -f "$HOME/.cc/awsvault_url" ]]; then
  #   IMDS_URL=$(< "$HOME/.cc/awsvault_url")
  fi
fi

# Handle PATH management for non-direnv mode
if [[ "$USE_DIRENV" -eq 0 ]]; then
  # Check if scripts directory is already in PATH
  if ! echo "$PATH" | tr ':' '\n' | grep -q "^$SCRIPT_DIR$"; then
    # Add scripts directory to PATH for this session if not already there
    export PATH="$PATH:$SCRIPT_DIR"
    _yellow "Added scripts to PATH for this session (non-direnv mode)"
    _yellow "For permanent use, add to your shell profile: export PATH=\"\$PATH:$SCRIPT_DIR\""
  fi
fi