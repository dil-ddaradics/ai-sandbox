#!/bin/bash
# aws-cred-monitor.sh - Monitors the AWS credential files for changes using fast polling
set -e

CRED_FILE="/host/.ai/env/awsvault_url"
TOKEN_FILE="/host/.ai/env/awsvault_token"
LOG_FILE="/tmp/aws_cred_monitor.log"
POLL_INTERVAL=1  # Check every second

# Function to log messages with timestamps
log_message() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

log_message "AWS credential monitor starting with fast polling..."
log_message "Watching files: $CRED_FILE and $TOKEN_FILE"
log_message "Poll interval: $POLL_INTERVAL seconds"

# Initial setup of credentials
if [[ -f "$CRED_FILE" ]]; then
  /usr/local/bin/aws-setup.sh
  log_message "Initial credentials setup completed"
else
  log_message "WARNING: Credential file not found at startup"
fi

# Function to run when files change
handle_change() {
  local file=$1
  local type=$2
  
  log_message "Detected change in $type file: $file"
  log_message "Running credential setup..."
  /usr/local/bin/aws-setup.sh
}

log_message "Starting polling monitor..."

# Initialize last modified times
LAST_URL_MTIME=""
LAST_TOKEN_MTIME=""

# Monitor loop
while true; do
  # Check URL file changes
  if [[ -f "$CRED_FILE" ]]; then
    # Get file modification time
    CURRENT_URL_MTIME=$(stat -c %Y "$CRED_FILE" 2>/dev/null || stat -f %m "$CRED_FILE" 2>/dev/null)
    
    if [[ -n "$LAST_URL_MTIME" && "$CURRENT_URL_MTIME" != "$LAST_URL_MTIME" ]]; then
      handle_change "$CRED_FILE" "URL"
    fi
    
    LAST_URL_MTIME="$CURRENT_URL_MTIME"
  fi
  
  # Check token file changes
  if [[ -f "$TOKEN_FILE" ]]; then
    # Get file modification time
    CURRENT_TOKEN_MTIME=$(stat -c %Y "$TOKEN_FILE" 2>/dev/null || stat -f %m "$TOKEN_FILE" 2>/dev/null)
    
    if [[ -n "$LAST_TOKEN_MTIME" && "$CURRENT_TOKEN_MTIME" != "$LAST_TOKEN_MTIME" ]]; then
      handle_change "$TOKEN_FILE" "token"
    fi
    
    LAST_TOKEN_MTIME="$CURRENT_TOKEN_MTIME"
  fi
  
  # Sleep for poll interval
  sleep $POLL_INTERVAL
done