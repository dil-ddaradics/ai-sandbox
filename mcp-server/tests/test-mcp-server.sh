#!/bin/bash
# Simple test script for the MCP server

# Set colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."

# Function to print section headers
print_header() {
  echo -e "\n${BLUE}==== $1 ====${NC}"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_header "Checking prerequisites"

if command_exists "node"; then
  NODE_VERSION=$(node -v)
  echo -e "${GREEN}✓ Node.js is installed: $NODE_VERSION${NC}"
else
  echo -e "${RED}✗ Node.js is not installed${NC}"
  exit 1
fi

if [ -d "$PROJECT_ROOT/node_modules" ]; then
  echo -e "${GREEN}✓ Dependencies are installed${NC}"
else
  echo -e "${RED}✗ Dependencies are not installed${NC}"
  echo -e "  Running npm install..."
  cd "$PROJECT_ROOT" && npm install
  if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to install dependencies${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
fi

# Build the project
print_header "Building the project"
cd "$PROJECT_ROOT" && npm run build
if [ $? -ne 0 ]; then
  echo -e "${RED}✗ Build failed${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Build successful${NC}"

# Test server startup
print_header "Testing server startup"
echo -e "Starting MCP server (will timeout after 5 seconds)..."
timeout 5 node "$PROJECT_ROOT/dist/index.js" > /dev/null 2>&1 &
SERVER_PID=$!

# Wait briefly for server to start
sleep 2

# Check if the process is still running
if kill -0 $SERVER_PID 2>/dev/null; then
  echo -e "${GREEN}✓ Server started successfully${NC}"
  echo -e "Stopping server..."
  kill $SERVER_PID
else
  echo -e "${RED}✗ Server failed to start${NC}"
fi

print_header "Test Completed"
echo -e "${GREEN}All tests completed.${NC}"
echo -e "\nTo use this MCP server with Claude Code, run:"
echo -e "${BLUE}claude mcp add --transport stdio ai-sandbox-mcp -- 'npm start --prefix $PROJECT_ROOT'${NC}"