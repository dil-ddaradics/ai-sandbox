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

# repo‑local env overrides
[[ -f "$ROOT_REPO/.cc/.ccenv" ]] && source "$ROOT_REPO/.cc/.ccenv"
# user‑global overrides
[[ -f "$HOME/.ccenv" ]] && source "$HOME/.ccenv"

# defaults
USE_DIRENV="${USE_DIRENV:-1}"
WT_ROOT="${WT_ROOT:-$HOME/worktrees}"
CLAUDE_CODE_USE_BEDROCK="${CLAUDE_CODE_USE_BEDROCK:-1}"
ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-us.anthropic.claude-3-sonnet-20250219-v1:0}"
CPU_LIMIT="${CPU_LIMIT:-}"
MEM_LIMIT="${MEM_LIMIT:-}"

# Auto-load IMDS URL if not already in env
if [[ -z "${IMDS_URL:-}" && -f "$HOME/.cc/awsvault_url" ]]; then
  IMDS_URL=$(< "$HOME/.cc/awsvault_url")
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