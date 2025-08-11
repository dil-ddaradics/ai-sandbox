#!/bin/bash
# aws-cred-refresh.sh - Refreshes AWS credentials from mounted host file
set -e

CRED_FILE="/host/.ai/env/awsvault_url"
ENV_FILE="/tmp/.aws_cred_env"
PROXY_PORT="${PROXY_PORT:-55491}"

# Function to log messages with timestamps
log_message() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1"
}

# If we already have the proxy environment variable set, use that
if [[ -n "$AWS_CONTAINER_CREDENTIALS_FULL_URI" && "$AWS_CONTAINER_CREDENTIALS_FULL_URI" == "http://localhost:"* ]]; then
  log_message "Using existing proxy URL: $AWS_CONTAINER_CREDENTIALS_FULL_URI"
  NEW_URL="$AWS_CONTAINER_CREDENTIALS_FULL_URI"
else
  # Check if credential file exists in new location
  if [[ ! -f "$CRED_FILE" ]]; then
    # Try the legacy location as fallback
    OLD_CRED_FILE="/host/.cc/env/awsvault_url"
    if [[ -f "$OLD_CRED_FILE" ]]; then
      log_message "Using legacy credential file at $OLD_CRED_FILE"
      CRED_FILE="$OLD_CRED_FILE"
    else
      log_message "ERROR: AWS credential file not found at $CRED_FILE"
      return 1
    fi
  fi

  # Read the URL from the file
  HOST_URL=$(cat "$CRED_FILE")

  # Validate URL format (basic check)
  if [[ ! "$HOST_URL" =~ ^http://(host.docker.internal|127.0.0.1):[0-9]+/?$ ]]; then
    log_message "WARNING: URL in credential file does not match expected format: $HOST_URL"
    # Continue anyway as the format might change
  fi

  # Use localhost proxy URL instead
  NEW_URL="http://localhost:${PROXY_PORT}/"
  log_message "Using local proxy URL: $NEW_URL"
fi

# Always use the proxy URL, ignoring any previously set value
log_message "Enforcing proxy URL: $NEW_URL"

# Read the authorization token if needed
if [[ -z "$AWS_CONTAINER_AUTHORIZATION_TOKEN" ]]; then
  AUTH_TOKEN_FILE="/host/.ai/env/awsvault_token"
  if [[ -f "$AUTH_TOKEN_FILE" ]]; then
    export AWS_CONTAINER_AUTHORIZATION_TOKEN=$(cat "$AUTH_TOKEN_FILE")
    log_message "Read authorization token from file"
  else
    # Try the legacy location as fallback
    OLD_AUTH_TOKEN_FILE="/host/.cc/env/awsvault_token"
    if [[ -f "$OLD_AUTH_TOKEN_FILE" ]]; then
      export AWS_CONTAINER_AUTHORIZATION_TOKEN=$(cat "$OLD_AUTH_TOKEN_FILE")
      log_message "Read authorization token from legacy file"
    fi
  fi
fi

# Update environment file
echo "export AWS_CONTAINER_CREDENTIALS_FULL_URI=\"$NEW_URL\"" > "$ENV_FILE"
if [[ -n "$AWS_CONTAINER_AUTHORIZATION_TOKEN" ]]; then
  echo "export AWS_CONTAINER_AUTHORIZATION_TOKEN=\"$AWS_CONTAINER_AUTHORIZATION_TOKEN\"" >> "$ENV_FILE"
fi

# Export variables for current session
export AWS_CONTAINER_CREDENTIALS_FULL_URI="$NEW_URL"

# Print current settings for debugging
log_message "Current credential URL: $AWS_CONTAINER_CREDENTIALS_FULL_URI"
log_message "Authorization token present: $([[ -n "$AWS_CONTAINER_AUTHORIZATION_TOKEN" ]] && echo "Yes" || echo "No")"

return 0