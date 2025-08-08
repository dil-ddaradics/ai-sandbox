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
source /usr/local/bin/aws-cred-refresh

# Check if AWS_CONTAINER_CREDENTIALS_FULL_URI is set
if [[ -z "${AWS_CONTAINER_CREDENTIALS_FULL_URI:-}" ]]; then
  error_message "AWS credential URL not found"
  echo "The AWS credential URL environment variable is not set."
  echo "Please restart the AWS credential server on your host machine:"
  echo "  cc-awsvault <your-aws-profile>"
  exit 1
fi

# Test 1: Check if credential server is reachable
log_message "Testing credential server connectivity..."
if ! curl -s -f -m 5 -o /dev/null "${AWS_CONTAINER_CREDENTIALS_FULL_URI}"; then
  error_message "Cannot connect to AWS credential server"
  echo "The AWS credential server at ${AWS_CONTAINER_CREDENTIALS_FULL_URI} is unreachable."
  echo "This often happens after your machine wakes from sleep or hibernation."
  echo "Please restart the AWS credential server on your host machine:"
  echo "  cc-awsvault <your-aws-profile>"
  exit 2
fi

# Test 2: Check if credentials can be retrieved
log_message "Testing credential retrieval..."
CREDS=$(curl -s -f -m 5 "${AWS_CONTAINER_CREDENTIALS_FULL_URI}")
if [[ -z "$CREDS" ]]; then
  error_message "Empty response from credential server"
  echo "The AWS credential server returned an empty response."
  echo "Please restart the AWS credential server on your host machine:"
  echo "  cc-awsvault <your-aws-profile>"
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
  echo "  cc-awsvault <your-aws-profile>"
  exit 4
fi

# All checks passed
success_message "AWS credential server is available and providing valid credentials"
exit 0