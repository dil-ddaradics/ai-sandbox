#!/bin/bash
# aws-cred-monitor.sh - Monitors the AWS credential file for changes
set -e

CRED_FILE="/host/.cc/awsvault_url"
LOG_FILE="/tmp/aws_cred_monitor.log"
CHECK_INTERVAL=30  # seconds

# Function to log messages with timestamps
log_message() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

log_message "AWS credential monitor starting..."
log_message "Watching file: $CRED_FILE"
log_message "Check interval: $CHECK_INTERVAL seconds"

# Initial load of credentials
if [[ -f "$CRED_FILE" ]]; then
  source /usr/local/bin/aws-cred-refresh
  log_message "Initial credentials loaded"
else
  log_message "WARNING: Credential file not found at startup"
fi

# Monitor loop
while true; do
  if [[ -f "$CRED_FILE" ]]; then
    # Get file modification time
    CURRENT_MTIME=$(stat -c %Y "$CRED_FILE" 2>/dev/null || stat -f %m "$CRED_FILE" 2>/dev/null)
    
    if [[ -n "$LAST_MTIME" && "$CURRENT_MTIME" != "$LAST_MTIME" ]]; then
      log_message "Credential file changed, refreshing..."
      source /usr/local/bin/aws-cred-refresh
    fi
    
    LAST_MTIME="$CURRENT_MTIME"
  else
    log_message "WARNING: Credential file not found"
  fi
  
  sleep $CHECK_INTERVAL
done