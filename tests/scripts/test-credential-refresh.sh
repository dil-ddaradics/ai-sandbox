#!/usr/bin/env bash
# test-credential-refresh.sh - Tests credential refresh mechanisms in detail
set -euo pipefail

# Define colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

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

# Function to check if we're inside a container
check_container() {
  if [[ ! -f /.dockerenv ]]; then
    echo -e "${RED}Error: This script must be run inside a container${NC}"
    echo -e "${YELLOW}Use 'docker exec -it <container-name> /bin/bash' to enter the container${NC}"
    echo -e "${YELLOW}Then run this script from inside the container${NC}"
    exit 1
  fi
}

# Check if inside container
check_container

print_step "1" "Checking current credential environment"

# Function to extract and display credential details
display_credentials() {
  local cred_file=${1:-/tmp/.aws_cred_env}
  
  if [[ ! -f "$cred_file" ]]; then
    echo -e "${RED}Credential file not found: $cred_file${NC}"
    return 1
  fi
  
  echo -e "${YELLOW}Credential file: $cred_file${NC}"
  
  # Source the file and extract key information
  source "$cred_file"
  
  # Display credential summary
  echo -e "${GREEN}Credential Summary:${NC}"
  echo "Access Key ID: ${AWS_ACCESS_KEY_ID:0:5}...${AWS_ACCESS_KEY_ID: -4}"
  
  if [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    echo "Secret Key: [HIDDEN - EXISTS]"
  else
    echo "Secret Key: [MISSING]"
  fi
  
  if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
    echo "Session Token: [EXISTS]"
  else
    echo "Session Token: [MISSING]"
  fi
  
  if [[ -n "${AWS_SESSION_EXPIRATION:-}" ]]; then
    echo "Expiration: $AWS_SESSION_EXPIRATION"
    
    # Calculate time until expiration
    expiration=$(date -d "$AWS_SESSION_EXPIRATION" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$AWS_SESSION_EXPIRATION" +%s)
    now=$(date +%s)
    seconds_left=$((expiration - now))
    
    if [[ $seconds_left -gt 0 ]]; then
      echo "Time until expiration: $(($seconds_left / 60)) minutes and $(($seconds_left % 60)) seconds"
    else
      echo -e "${RED}EXPIRED: $((-$seconds_left / 60)) minutes and $((-$seconds_left % 60)) seconds ago${NC}"
    fi
  else
    echo "Expiration: [MISSING]"
  fi
  
  echo "Credential URL: $AWS_CONTAINER_CREDENTIALS_FULL_URI"
}

# Display current credentials
display_credentials

print_step "2" "Testing credential refresh script"

# Create backup of credential file
cp /tmp/.aws_cred_env /tmp/.aws_cred_env.bak
echo -e "${GREEN}Created backup of credential file${NC}"

# Test the refresh script
echo -e "${YELLOW}Running credential refresh script...${NC}"
if /usr/local/bin/aws-cred-refresh; then
  echo -e "${GREEN}Credential refresh succeeded${NC}"
else
  echo -e "${RED}Credential refresh failed${NC}"
fi

# Display refreshed credentials
echo -e "\n${YELLOW}Refreshed credentials:${NC}"
display_credentials

print_step "3" "Testing credential fetching from server"

# Directly test credential fetching
echo -e "${YELLOW}Directly fetching credentials from server...${NC}"
if curl -s -f "${AWS_CONTAINER_CREDENTIALS_FULL_URI}" > /tmp/direct_creds.json; then
  echo -e "${GREEN}Direct credential fetch succeeded${NC}"
  echo -e "${YELLOW}Credential response summary:${NC}"
  
  # Parse and display key info from JSON
  TEMP_ACCESS_KEY=$(cat /tmp/direct_creds.json | grep -o '"AccessKeyId" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
  TEMP_SECRET_KEY=$(cat /tmp/direct_creds.json | grep -o '"SecretAccessKey" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
  TEMP_TOKEN=$(cat /tmp/direct_creds.json | grep -o '"Token" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
  TEMP_EXPIRATION=$(cat /tmp/direct_creds.json | grep -o '"Expiration" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
  
  echo "Access Key ID: ${TEMP_ACCESS_KEY:0:5}...${TEMP_ACCESS_KEY: -4}"
  echo "Secret Key: [${#TEMP_SECRET_KEY} characters]"
  echo "Session Token: [${#TEMP_TOKEN} characters]"
  echo "Expiration: $TEMP_EXPIRATION"
  
  # Compare with current credentials
  if [[ "$TEMP_ACCESS_KEY" == "$AWS_ACCESS_KEY_ID" ]]; then
    echo -e "${GREEN}✓ Access key matches current credentials${NC}"
  else
    echo -e "${RED}✗ Access key differs from current credentials${NC}"
  fi
  
  # Clean up
  rm /tmp/direct_creds.json
else
  echo -e "${RED}Direct credential fetch failed${NC}"
fi

print_step "4" "Testing credential monitoring"

# Check if monitor script is running
MONITOR_PID=$(pgrep -f aws-cred-monitor.sh || echo "")
if [[ -n "$MONITOR_PID" ]]; then
  echo -e "${GREEN}Credential monitor is running (PID: $MONITOR_PID)${NC}"
  
  # Check monitor logs
  if [[ -f "/tmp/aws-cred-monitor.log" ]]; then
    echo -e "${YELLOW}Recent monitor log entries:${NC}"
    tail -n 10 /tmp/aws-cred-monitor.log
  else
    echo -e "${YELLOW}No monitor log file found${NC}"
  fi
else
  echo -e "${RED}Credential monitor is not running${NC}"
fi

print_step "5" "Testing credential URL detection"

# Back up original URL file
if [[ -f "/host/.cc/awsvault_url" ]]; then
  cp /host/.cc/awsvault_url /tmp/awsvault_url.bak
  echo -e "${GREEN}Backed up original URL file${NC}"
  
  # Simulate URL change by modifying the file slightly
  echo -e "${YELLOW}Simulating URL change...${NC}"
  ORIGINAL_URL=$(cat /host/.cc/awsvault_url)
  
  # Add a comment to trigger change detection without breaking functionality
  echo "$ORIGINAL_URL # Modified by test" > /tmp/modified_url
  cat /tmp/modified_url > /host/.cc/awsvault_url
  
  echo -e "${YELLOW}Waiting for monitor to detect change (15 seconds)...${NC}"
  sleep 15
  
  # Check if monitor detected and processed the change
  if [[ -f "/tmp/aws-cred-monitor.log" ]]; then
    echo -e "${YELLOW}Recent monitor log entries after URL change:${NC}"
    tail -n 10 /tmp/aws-cred-monitor.log
    
    # Check for refresh triggered by URL change
    if grep -q "URL changed" /tmp/aws-cred-monitor.log; then
      echo -e "${GREEN}✓ Monitor detected URL change${NC}"
    else
      echo -e "${RED}✗ Monitor did not detect URL change${NC}"
    fi
  fi
  
  # Restore original URL file
  cat /tmp/awsvault_url.bak > /host/.cc/awsvault_url
  echo -e "${GREEN}Restored original URL file${NC}"
else
  echo -e "${RED}URL file not found at /host/.cc/awsvault_url${NC}"
fi

print_step "6" "Testing aws-connectivity-check script"

# Run connectivity check
echo -e "${YELLOW}Running AWS connectivity check...${NC}"
if /usr/local/bin/aws-connectivity-check; then
  echo -e "${GREEN}Connectivity check passed${NC}"
else
  echo -e "${RED}Connectivity check failed${NC}"
fi

print_step "7" "Testing AWS CLI with credentials"

# Try a simple AWS command
echo -e "${YELLOW}Testing AWS credentials with STS get-caller-identity...${NC}"
if command -v aws &> /dev/null; then
  if aws sts get-caller-identity; then
    echo -e "${GREEN}AWS CLI test succeeded${NC}"
  else
    echo -e "${RED}AWS CLI test failed${NC}"
  fi
else
  echo -e "${YELLOW}AWS CLI not installed in this container${NC}"
fi

print_step "8" "Restoring original credentials"

# Restore original credentials
if [[ -f "/tmp/.aws_cred_env.bak" ]]; then
  cp /tmp/.aws_cred_env.bak /tmp/.aws_cred_env
  echo -e "${GREEN}Restored original credentials${NC}"
else
  echo -e "${RED}Original credential backup not found${NC}"
fi

print_step "9" "Test summary"

echo -e "${GREEN}Credential refresh test completed${NC}"
echo "This test verified:"
echo "1. Current credential environment"
echo "2. Credential refresh functionality"
echo "3. Direct credential fetching from server"
echo "4. Credential monitoring process"
echo "5. URL change detection"
echo "6. AWS connectivity check"
echo "7. AWS CLI credential usage"

echo -e "\n${YELLOW}Current credentials restored to original state${NC}"