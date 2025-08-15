#!/usr/bin/env bash
set -euo pipefail

# AI Sandbox Global Installer
# Makes the AI Sandbox installer globally available on your system

INSTALL_DIR="${1:-/usr/local/bin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_NAME="install-ai-sandbox"

# Check if installation directory exists and is writable
if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "Installation directory $INSTALL_DIR does not exist."
  echo "Please create it or specify a different directory."
  exit 1
fi

if [[ ! -w "$INSTALL_DIR" ]]; then
  echo "You don't have write permissions to $INSTALL_DIR."
  echo "Please run with sudo or specify a different directory."
  exit 1
fi

# Create the symbolic link
ln -sf "$SCRIPT_DIR/install.sh" "$INSTALL_DIR/$GLOBAL_NAME"
chmod +x "$INSTALL_DIR/$GLOBAL_NAME"

echo "✅ AI Sandbox installer is now globally available as '$GLOBAL_NAME'"
echo "You can run it from any directory:"
echo "  $GLOBAL_NAME ~/path/to/your/repo"
echo "  # Or in the current directory:"
echo "  cd ~/path/to/your/repo && $GLOBAL_NAME"