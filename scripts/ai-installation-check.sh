#!/usr/bin/env bash
# ai-installation-check.sh - Check if AI Sandbox is globally installed
set -euo pipefail

# Parse arguments
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    -h|--help)
      echo "Usage: ai-installation-check.sh [OPTIONS]"
      echo
      echo "Options:"
      echo "  --json          Output in JSON format for MCP integration"
      echo "  -h, --help      Show this help message"
      echo
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Define colors for human-readable output
if ! $JSON_OUTPUT; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  NC='\033[0m' # No Color
fi

# Check if install-ai-sandbox command is in PATH
CHECK_GLOBAL=$(command -v install-ai-sandbox 2>/dev/null || echo "")

# Determine installation status
INSTALLED=false
INSTALL_PATH=""
if [[ -n "$CHECK_GLOBAL" ]]; then
  INSTALLED=true
  INSTALL_PATH="$CHECK_GLOBAL"
fi

# Generate installation instructions
INSTALL_INSTRUCTIONS="To globally install AI Sandbox:

1. Clone the repository:
   git clone https://github.com/dil-ddaradics/ai-sandbox.git

2. Run the global installation script:
   sudo ./ai-sandbox/global-install.sh

3. Verify installation:
   install-ai-sandbox --help
"

# Output results
if $JSON_OUTPUT; then
  cat <<EOF
{
  "installed": $INSTALLED,
  "install_path": $(if [[ -n "$INSTALL_PATH" ]]; then echo "\"$INSTALL_PATH\""; else echo "null"; fi),
  "instructions": "To globally install AI Sandbox:\\n\\n1. Clone the repository:\\n   git clone https://github.com/dil-ddaradics/ai-sandbox.git\\n\\n2. Run the global installation script:\\n   sudo ./ai-sandbox/global-install.sh\\n\\n3. Verify installation:\\n   install-ai-sandbox --help"
}
EOF
else
  if [[ "$INSTALLED" == "true" ]]; then
    echo -e "${GREEN}✓ AI Sandbox is globally installed${NC}"
    echo -e "Installation path: $INSTALL_PATH"
  else
    echo -e "${YELLOW}⚠ AI Sandbox is NOT globally installed${NC}"
    echo
    echo -e "${YELLOW}Global installation is required for MCP tools to work correctly.${NC}"
    echo
    echo -e "$INSTALL_INSTRUCTIONS"
  fi
fi

# Exit with status code 0 if installed, 1 if not installed
if [[ "$INSTALLED" == "true" ]]; then
  exit 0
else
  exit 1
fi