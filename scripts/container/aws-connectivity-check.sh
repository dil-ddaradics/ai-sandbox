#!/bin/bash
# aws-connectivity-check.sh - Tests AWS credential server connectivity and credential validity
set -e

# Function to log messages with timestamps
log_message() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Function to print colored error messages
error_message() {
  echo -e "\e[31mERROR: $1\e[0m"
}

# Function to print colored warning messages
warning_message() {
  echo -e "\e[33mWARNING: $1\e[0m"
}

# Function to print colored success messages
success_message() {
  echo -e "\e[32mSUCCESS: $1\e[0m"
}

# Make sure credentials are refreshed
/usr/local/bin/aws-setup.sh

# Use localhost URL for testing as that's where socat is listening
LOCAL_CRED_URL="http://localhost:55491/"

# Check if socat proxy is running
if ! pgrep -f "socat.*:55491" > /dev/null; then
  error_message "AWS credential proxy not running"
  echo "The AWS credential proxy is not running. Trying to restart it."
  /usr/local/bin/aws-setup.sh
  sleep 1
  
  # Check again after restart attempt
  if ! pgrep -f "socat.*:55491" > /dev/null; then
    error_message "Failed to start AWS credential proxy"
    echo "Please restart the AWS credential server on your host machine:"
    echo "  ai-awsvault <your-aws-profile>"
    exit 1
  fi
fi

# Check if the token file exists and read token
TOKEN_FILE="/host/.ai/env/awsvault_token"
if [[ -f "$TOKEN_FILE" ]]; then
  export AWS_CONTAINER_AUTHORIZATION_TOKEN=$(cat "$TOKEN_FILE")
  log_message "Read authorization token from file (length: ${#AWS_CONTAINER_AUTHORIZATION_TOKEN})"
fi

# Test 1: Check if credential server is reachable
log_message "Testing credential server connectivity to ${LOCAL_CRED_URL}..."

# Read token directly from file
TOKEN_FILE="/host/.ai/env/awsvault_token"
AUTH_TOKEN=""
if [[ -f "$TOKEN_FILE" ]]; then
  AUTH_TOKEN=$(cat "$TOKEN_FILE")
  log_message "Read authorization token from file (length: ${#AUTH_TOKEN})"
fi

# First check with token if available
if [[ -n "$AUTH_TOKEN" ]]; then
  log_message "Using authorization token for connection test"
  if ! curl -s -f -m 5 -o /dev/null -H "Authorization: $AUTH_TOKEN" "${LOCAL_CRED_URL}"; then
    log_message "Connection test with token failed, trying without token"
    if ! curl -s -f -m 5 -o /dev/null "${LOCAL_CRED_URL}"; then
      error_message "Cannot connect to AWS credential server"
      echo "The AWS credential server at ${LOCAL_CRED_URL} is unreachable."
      echo "This often happens after your machine wakes from sleep or hibernation."
      echo "Please restart the AWS credential server on your host machine:"
      echo "  ai-awsvault <your-aws-profile>"
      exit 2
    fi
  fi
else
  # No token available, try without
  if ! curl -s -f -m 5 -o /dev/null "${LOCAL_CRED_URL}"; then
    error_message "Cannot connect to AWS credential server"
    echo "The AWS credential server at ${LOCAL_CRED_URL} is unreachable."
    echo "This often happens after your machine wakes from sleep or hibernation."
    echo "Please restart the AWS credential server on your host machine:"
    echo "  ai-awsvault <your-aws-profile>"
    exit 2
  fi
fi

# Test 2: Check if credentials can be retrieved
log_message "Testing credential retrieval..."
# Use the same token we read above
if [[ -n "$AUTH_TOKEN" ]]; then
  CREDS=$(curl -s -f -m 5 -H "Authorization: $AUTH_TOKEN" "${LOCAL_CRED_URL}")
else
  CREDS=$(curl -s -f -m 5 "${LOCAL_CRED_URL}")
fi

if [[ -z "$CREDS" ]]; then
  error_message "Empty response from credential server"
  echo "The AWS credential server returned an empty response."
  echo "Please restart the AWS credential server on your host machine:"
  echo "  ai-awsvault <your-aws-profile>"
  exit 3
fi

# Test 3: Validate credential format
log_message "Validating credential format..."
ACCESS_KEY=$(echo "$CREDS" | grep -o '"AccessKeyId" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
SECRET_KEY=$(echo "$CREDS" | grep -o '"SecretAccessKey" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')
TOKEN=$(echo "$CREDS" | grep -o '"Token" *: *"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"')

if [[ -z "$ACCESS_KEY" || -z "$SECRET_KEY" || -z "$TOKEN" ]]; then
  error_message "Invalid credential format"
  echo "The AWS credential server returned credentials in an unexpected format."
  echo "Expected JSON with AccessKeyId, SecretAccessKey, and Token."
  echo "Please restart the AWS credential server on your host machine:"
  echo "  ai-awsvault <your-aws-profile>"
  exit 4
fi

# All checks passed
success_message "AWS credential server is available and providing valid credentials"
exit 0