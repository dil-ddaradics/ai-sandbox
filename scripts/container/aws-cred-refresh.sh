#!/bin/bash
# aws-cred-refresh.sh - Refreshes AWS credentials from mounted host file
set -e

CRED_FILE="/host/.cc/awsvault_url"
ENV_FILE="/tmp/.aws_cred_env"

# Function to log messages with timestamps
log_message() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# Check if credential file exists
if [[ ! -f "$CRED_FILE" ]]; then
  log_message "ERROR: AWS credential file not found at $CRED_FILE"
  return 1
fi

# Read the URL from the file
NEW_URL=$(cat "$CRED_FILE")

# Validate URL format (basic check)
if [[ ! "$NEW_URL" =~ ^http://host.docker.internal:[0-9]+/$ ]]; then
  log_message "WARNING: URL in credential file does not match expected format: $NEW_URL"
  # Continue anyway as the format might change
fi

# Check if URL has changed
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
  if [[ "$AWS_CONTAINER_CREDENTIALS_FULL_URI" == "$NEW_URL" ]]; then
    # URL hasn't changed, do nothing
    return 0
  fi
fi

# URL has changed or env file doesn't exist - update it
log_message "Updating AWS credential URL to: $NEW_URL"
echo "export AWS_CONTAINER_CREDENTIALS_FULL_URI=\"$NEW_URL\"" > "$ENV_FILE"

# Export the variable for the current session
export AWS_CONTAINER_CREDENTIALS_FULL_URI="$NEW_URL"

return 0