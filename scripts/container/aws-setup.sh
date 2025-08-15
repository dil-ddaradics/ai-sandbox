#!/bin/bash
# aws-setup.sh - Sets up AWS credential proxy and environment variables
set -e

CRED_FILE="/host/.ai/env/awsvault_url"
TOKEN_FILE="/host/.ai/env/awsvault_token"
ENV_FILE="/etc/profile.d/aws-credentials.sh"
PROXY_PID_FILE="/tmp/socat_proxy.pid"
PROXY_PORT="55491"  # Container-side proxy port
LOG_FILE="/tmp/aws_setup.log"

# Function to log messages with timestamps
log_message() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Function to check if socat is running with correct parameters
check_socat() {
  local target_port=$1
  
  if [[ -f "$PROXY_PID_FILE" ]]; then
    local pid=$(cat "$PROXY_PID_FILE")
    if ps -p "$pid" >/dev/null 2>&1; then
      # Check if the process is socat and connects to the right port
      if ps -o cmd= -p "$pid" | grep -q "host.docker.internal:${target_port}"; then
        log_message "Socat proxy already running with correct configuration (PID: $pid)"
        return 0
      else
        log_message "Socat proxy running (PID: $pid) but with wrong configuration"
        return 1
      fi
    else
      log_message "Socat proxy not running (stale PID file)"
      return 1
    fi
  else
    log_message "No socat proxy PID file found"
    return 1
  fi
}

# Function to start or restart socat proxy
setup_socat_proxy() {
  local host_port=$1
  
  # Kill existing socat if running
  if [[ -f "$PROXY_PID_FILE" ]]; then
    local old_pid=$(cat "$PROXY_PID_FILE")
    if kill -0 "$old_pid" 2>/dev/null; then
      log_message "Stopping existing socat proxy (PID: $old_pid)"
      kill "$old_pid" 2>/dev/null || true
      sleep 1
    fi
    rm -f "$PROXY_PID_FILE"
  fi
  
  # Start new socat proxy
  log_message "Starting socat proxy from localhost:$PROXY_PORT to host.docker.internal:$host_port"
  socat TCP-LISTEN:${PROXY_PORT},bind=127.0.0.1,fork,reuseaddr TCP:host.docker.internal:${host_port} &
  local new_pid=$!
  echo "$new_pid" > "$PROXY_PID_FILE"
  chmod 600 "$PROXY_PID_FILE"
  log_message "Started socat proxy with PID $new_pid"
  
  return 0
}

# Function to update authorization token only
update_auth_token() {
  local auth_token=""
  
  # Read token if available
  if [[ -f "$TOKEN_FILE" ]]; then
    auth_token=$(cat "$TOKEN_FILE")
    log_message "Read authorization token (length: ${#auth_token})"
  else
    log_message "No authorization token file found"
  fi
  
  # Update current environment with token only
  # AWS_CONTAINER_CREDENTIALS_FULL_URI is already set in Dockerfile
  export AWS_CONTAINER_AUTHORIZATION_TOKEN="$auth_token"
  
  # Update profile.d script for new bash sessions
  log_message "Updating profile.d script for new bash sessions"
  cat > "$ENV_FILE" << EOF
# AWS ECS credentials configuration
export AWS_CONTAINER_CREDENTIALS_FULL_URI="http://localhost:${PROXY_PORT}/"
export AWS_CONTAINER_AUTHORIZATION_TOKEN="$auth_token"
EOF
  # Make file executable but also readable by other users
  chmod 644 "$ENV_FILE"
  
  return 0
}

# Function to test if AWS credentials are accessible
test_credentials() {
  log_message "Testing AWS credential access"
  
  if [[ -n "$AWS_CONTAINER_AUTHORIZATION_TOKEN" ]]; then
    # Try with token
    if curl -s -f -m 2 -H "Authorization: $AWS_CONTAINER_AUTHORIZATION_TOKEN" "http://localhost:${PROXY_PORT}/" | grep -q "AccessKeyId"; then
      log_message "AWS credential access successful with token"
      return 0
    else
      log_message "AWS credential access failed with token, trying without"
    fi
  fi
  
  # Try without token
  if curl -s -f -m 2 "http://localhost:${PROXY_PORT}/" | grep -q "AccessKeyId"; then
    log_message "AWS credential access successful without token"
    return 0
  else
    log_message "AWS credential access failed"
    return 1
  fi
}

# Main function to set up AWS credentials
main() {
  log_message "Starting AWS credential setup"
  
  # Check if credential file exists
  if [[ ! -f "$CRED_FILE" ]]; then
    log_message "ERROR: AWS credential URL file not found at $CRED_FILE"
    return 1
  fi
  
  # Read the URL from the file
  HOST_URL=$(cat "$CRED_FILE")
  HOST_PORT_INFO=$(echo "$HOST_URL" | cut -d/ -f3)
  HOST_PORT=$(echo "$HOST_PORT_INFO" | cut -d: -f2)
  
  if [[ -z "$HOST_PORT" ]]; then
    log_message "ERROR: Could not extract port from URL: $HOST_URL"
    return 1
  fi
  
  log_message "Detected host credential server URL: $HOST_URL (port: $HOST_PORT)"
  
  # Check if socat is already running with the correct port
  if ! check_socat "$HOST_PORT"; then
    setup_socat_proxy "$HOST_PORT"
  fi
  
  # Set correct URL regardless of what's in the environment
  export AWS_CONTAINER_CREDENTIALS_FULL_URI="http://localhost:${PROXY_PORT}/"
  
  # Update authorization token
  update_auth_token
  
  # Test if credentials are accessible
  if test_credentials; then
    log_message "AWS credential setup completed successfully"
    return 0
  else
    log_message "WARNING: AWS credential setup completed but credential test failed"
    return 0  # Still return success to continue operation
  fi
}

# Run main function
main "$@"