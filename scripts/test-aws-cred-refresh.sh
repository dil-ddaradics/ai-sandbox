#!/usr/bin/env bash
# test-aws-cred-refresh.sh - Test script for AWS credential refresh functionality
set -eo pipefail
source "$(dirname "$0")/_common.sh"

# Configuration
TEST_PROFILE="${1:-default}"
CTR_FILE="$(pwd)/.ai-container"
LOG_FILE="/tmp/aws_cred_test.log"

# Ensure container is running
[[ ! -f "$CTR_FILE" ]] && _die "Run ai-up first."
CTR="$(cat "$CTR_FILE")"

# Check if container is running
if ! docker ps --format "{{.Names}}" | grep -q "^$CTR$"; then
  _die "Container $CTR is not running. Start it with ai-up first."
fi

# Function to log messages
log_message() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
  
  case "$level" in
    INFO)  _green "$message" ;;
    WARN)  _yellow "$message" ;;
    ERROR) _red "$message" ;;
    *)     echo "$message" ;;
  esac
}

# Function to check if AWS is working in container
check_aws_in_container() {
  log_message "INFO" "Testing AWS in container..."
  if docker exec "$CTR" aws sts get-caller-identity &>/dev/null; then
    log_message "INFO" "✅ AWS credentials are working in container"
    docker exec "$CTR" aws sts get-caller-identity
    return 0
  else
    log_message "WARN" "❌ AWS credentials are NOT working in container"
    return 1
  fi
}

# Function to check socat proxy in container
check_socat_in_container() {
  log_message "INFO" "Checking socat proxy in container..."
  local socat_info=$(docker exec "$CTR" ps aux | grep "socat.*TCP-LISTEN" | grep -v grep || echo "")
  
  if [[ -n "$socat_info" ]]; then
    log_message "INFO" "✅ Socat proxy is running in container"
    local listen_port=$(echo "$socat_info" | grep -o "TCP-LISTEN:[0-9]*" | cut -d: -f2)
    local target_port=$(echo "$socat_info" | grep -o "TCP:host.docker.internal:[0-9]*" | cut -d: -f3)
    log_message "INFO" "Socat listening on port $listen_port, forwarding to host port $target_port"
    return 0
  else
    log_message "WARN" "❌ Socat proxy is NOT running in container"
    return 1
  fi
}

# Function to run diagnostic tool in container
run_diagnostics() {
  log_message "INFO" "Running AWS credential diagnostics in container..."
  docker exec "$CTR" /usr/local/bin/aws-cred-diagnose.sh
}

# Function to get current aws-vault port
get_awsvault_port() {
  if [[ -f "$HOME/.ai/env/awsvault_url" ]]; then
    local port=$(grep -o ":[0-9]*" "$HOME/.ai/env/awsvault_url" | tr -d ":")
    echo "$port"
  else
    echo ""
  fi
}

# Step 1: Check initial state
log_message "INFO" "==== STEP 1: CHECKING INITIAL STATE ===="
check_aws_in_container || _die "AWS is not working in container before test. Cannot proceed."
check_socat_in_container || _die "Socat proxy is not running in container before test. Cannot proceed."
run_diagnostics

# Step 2: Stop existing aws-vault if any
log_message "INFO" "==== STEP 2: STOPPING EXISTING AWS-VAULT ===="
log_message "INFO" "Stopping any running aws-vault instances..."
pkill -f "aws-vault.*--ecs-server" || true
screen -X -S aws-vault-creds quit >/dev/null 2>&1 || true
sleep 2

# Step 3: Check if credentials are no longer available
log_message "INFO" "==== STEP 3: CHECKING CREDENTIAL REMOVAL ===="
log_message "INFO" "Waiting for credentials to become unavailable..."
sleep 5
if ! check_aws_in_container; then
  log_message "INFO" "✅ AWS credentials are correctly unavailable after stopping aws-vault"
else
  log_message "ERROR" "❌ AWS credentials are still working after stopping aws-vault"
  log_message "INFO" "This might indicate a problem with credential expiration or refresh"
fi

check_socat_in_container
log_message "INFO" "Container state after aws-vault stopped:"
run_diagnostics

# Step 4: Start aws-vault with profile
log_message "INFO" "==== STEP 4: STARTING AWS-VAULT WITH PROFILE $TEST_PROFILE ===="
log_message "INFO" "Starting aws-vault with profile $TEST_PROFILE..."
"$(dirname "$0")/ai-awsvault" "$TEST_PROFILE" || _die "Failed to start aws-vault"
sleep 2

# Get new port
NEW_PORT=$(get_awsvault_port)
log_message "INFO" "aws-vault started with port $NEW_PORT"

# Step 5: Check if credentials are available again
log_message "INFO" "==== STEP 5: CHECKING CREDENTIAL RESTORATION ===="
log_message "INFO" "Waiting for credentials to be detected and processed..."
sleep 10

if check_aws_in_container; then
  log_message "INFO" "✅ AWS credentials are working again after restarting aws-vault"
else
  log_message "ERROR" "❌ AWS credentials are still NOT working after restarting aws-vault"
  log_message "INFO" "This indicates a problem with credential refresh"
fi

check_socat_in_container
log_message "INFO" "Final container state:"
run_diagnostics

log_message "INFO" "==== AWS CREDENTIAL REFRESH TEST COMPLETED ===="