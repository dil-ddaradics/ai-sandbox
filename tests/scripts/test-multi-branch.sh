#!/usr/bin/env bash
# test-multi-branch.sh - Tests container creation across multiple branches
set -euo pipefail

# Define colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Number of branches to test
BRANCH_COUNT=${1:-3}

# Get the path to scripts directory relative to this script
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
REPO_ROOT="$(git rev-parse --show-toplevel)"
CC_SCRIPTS="$REPO_ROOT/.cc/scripts"

# Check if required commands exist
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo -e "${RED}Error: $1 command not found${NC}"
    exit 1
  fi
}

check_command cc-up
check_command cc-chat
check_command cc-clean

# Function to print status messages
print_step() {
  echo -e "\n${BLUE}=== STEP $1: $2 ===${NC}\n"
}

# Function to run a command with status output
run_command() {
  echo -e "${YELLOW}Running: $*${NC}"
  if "$@"; then
    echo -e "${GREEN}Command succeeded${NC}"
    return 0
  else
    echo -e "${RED}Command failed${NC}"
    return 1
  fi
}

# Function to validate container
validate_container() {
  local container_name="cc-$1"
  local branch_name="$1"
  
  echo -e "${BLUE}Validating container for branch: $branch_name${NC}"
  
  # Check if container is running
  if docker ps | grep -q "$container_name"; then
    echo -e "${GREEN}✓ Container $container_name is running${NC}"
  else
    echo -e "${RED}✗ Container $container_name is not running${NC}"
    return 1
  fi
  
  # Check if worktree exists
  local worktree_path="$(cd "$CC_SCRIPTS/.." && source _common.sh && echo "$WT_ROOT/$branch_name" 2>/dev/null || echo "Unknown")"
  if [[ -d "$worktree_path" ]]; then
    echo -e "${GREEN}✓ Worktree exists at $worktree_path${NC}"
  else
    echo -e "${RED}✗ Worktree does not exist at expected path${NC}"
    return 1
  fi
  
  # Run AWS connectivity check
  echo "Testing AWS credential connectivity..."
  if docker exec "$container_name" /usr/local/bin/aws-connectivity-check; then
    echo -e "${GREEN}✓ AWS credential connectivity check passed${NC}"
  else
    echo -e "${RED}✗ AWS credential connectivity check failed${NC}"
    return 1
  fi
  
  return 0
}

# Start credential server if not already running
print_step "1" "Checking credential server status"
if [[ ! -f "$HOME/.cc/awsvault_url" ]]; then
  echo -e "${YELLOW}Credential server URL file not found. Please start credential server:${NC}"
  echo "cc-awsvault <your-profile>"
  exit 1
fi

echo -e "${GREEN}Credential server appears to be running${NC}"

# Create branches and containers
print_step "2" "Creating $BRANCH_COUNT test branches and containers"

# Track created branches
created_branches=()

for i in $(seq 1 "$BRANCH_COUNT"); do
  branch_name="test-multi-branch-$i"
  created_branches+=("$branch_name")
  
  echo -e "\n${BLUE}Creating container for branch: $branch_name (${i}/${BRANCH_COUNT})${NC}"
  if run_command cc-up "$branch_name"; then
    validate_container "$branch_name"
  fi
done

# Test cc-chat on one container
print_step "3" "Testing cc-chat on first container"
echo -e "${YELLOW}Testing cc-chat on branch ${created_branches[0]}${NC}"
echo -e "${YELLOW}This will open the Claude chat interface. Type 'exit' to continue the test.${NC}"
echo -e "${YELLOW}Press Enter to continue...${NC}"
read -r
run_command cd "${created_branches[0]}" && cc-chat

# Test cleanup
print_step "4" "Cleaning up test containers"
for branch_name in "${created_branches[@]}"; do
  echo -e "\n${BLUE}Cleaning up branch: $branch_name${NC}"
  
  # Find container work-tree path
  container_dir="$(cd "$CC_SCRIPTS/.." && source _common.sh && echo "$WT_ROOT/$branch_name" 2>/dev/null || echo "Unknown")"
  
  # Only clean if directory exists
  if [[ -d "$container_dir" ]]; then
    echo "Cleaning up container at $container_dir"
    (cd "$container_dir" && run_command cc-clean)
  else
    echo -e "${YELLOW}Container directory not found for $branch_name${NC}"
  fi
done

# Final status
print_step "5" "Test summary"
echo -e "${GREEN}Multi-branch test completed${NC}"
echo "The script created and tested $BRANCH_COUNT branches"
echo "All containers should now be cleaned up"

# Check if any containers with cc- prefix are still running
if docker ps | grep -q "cc-"; then
  echo -e "${RED}Warning: Some cc- containers are still running:${NC}"
  docker ps | grep "cc-"
else
  echo -e "${GREEN}No cc- containers are running${NC}"
fi