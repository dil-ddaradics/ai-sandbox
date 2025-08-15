#!/bin/bash
# aws-setup.sh - Sets up AWS credential proxy and environment variables
set -e

CRED_FILE_ENV="/host/.ai/env/awsvault_url"
CRED_FILE_LEGACY="/host/.ai/awsvault_url"
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
  local target_host=$1
  local target_port=$2
  
  if [[ -f "$PROXY_PID_FILE" ]]; then
    local pid=$(cat "$PROXY_PID_FILE")
    if ps -p "$pid" >/dev/null 2>&1; then
      # Check if the process is socat and connects to the right host:port
      if ps -o cmd= -p "$pid" | grep -q "${target_host}:${target_port}"; then
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
  local host_address=$1
  local host_port=$2
  
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
  log_message "Starting socat proxy from localhost:$PROXY_PORT to ${host_address}:${host_port}"
  socat TCP-LISTEN:${PROXY_PORT},bind=127.0.0.1,fork,reuseaddr TCP:${host_address}:${host_port} &
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
  
  # Read URL directly from host files, never use environment variables
  local host_url=""
  
  # Try env subdirectory first (preferred location)
  if [[ -f "$CRED_FILE_ENV" ]]; then
    host_url=$(cat "$CRED_FILE_ENV")
    log_message "Read URL from $CRED_FILE_ENV"
  # Fall back to legacy location
  elif [[ -f "$CRED_FILE_LEGACY" ]]; then
    host_url=$(cat "$CRED_FILE_LEGACY")
    log_message "Read URL from $CRED_FILE_LEGACY"
  else
    log_message "ERROR: AWS credential URL file not found"
    return 1
  fi
  
  # Extract the host and port
  local host_part=$(echo "$host_url" | cut -d/ -f3)
  local host_address=$(echo "$host_part" | cut -d: -f1)
  local host_port=$(echo "$host_part" | cut -d: -f2)
  
  if [[ -z "$host_port" ]]; then
    log_message "ERROR: Could not extract port from URL: $host_url"
    return 1
  fi
  
  # Always transform 127.0.0.1 or localhost to host.docker.internal
  local docker_host_address="$host_address"
  if [[ "$host_address" == "127.0.0.1" || "$host_address" == "localhost" ]]; then
    docker_host_address="host.docker.internal"
    log_message "Translated $host_address to $docker_host_address for container access"
  fi
  
  log_message "Detected host credential server URL: $host_url (port: $host_port)"
  
  # Check if socat is already running with the correct configuration
  if ! check_socat "$docker_host_address" "$host_port"; then
    setup_socat_proxy "$docker_host_address" "$host_port"
  fi
  
  # Set correct URL for credential access
  export AWS_CONTAINER_CREDENTIALS_FULL_URI="http://localhost:${PROXY_PORT}/"
  
  # Update authorization token
  update_auth_token
  
  # Test if credentials are accessible
  if test_credentials; then
    log_message "AWS credential setup completed successfully"
    return 0
  else
    log_message "ERROR: AWS credential setup failed - credentials not accessible"
    return 1
  fi
}

# Run main function
main "$@"