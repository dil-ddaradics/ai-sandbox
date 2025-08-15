#!/bin/bash
# aws-cred-monitor.sh - Monitors the AWS credential files for changes using inotify
set -e

CRED_FILE="/host/.ai/env/awsvault_url"
TOKEN_FILE="/host/.ai/env/awsvault_token"
LOG_FILE="/tmp/aws_cred_monitor.log"

# Function to log messages with timestamps
log_message() {
  echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

log_message "AWS credential monitor starting with inotify..."
log_message "Watching files: $CRED_FILE and $TOKEN_FILE"

# Make sure inotify-tools is installed
if ! command -v inotifywait >/dev/null 2>&1; then
  log_message "ERROR: inotifywait not found. Please install inotify-tools package."
  exit 1
fi

# Initial setup of credentials
if [[ -f "$CRED_FILE" ]]; then
  /usr/local/bin/aws-setup.sh
  log_message "Initial credentials setup completed"
else
  log_message "WARNING: Credential file not found at startup"
fi

# Create the directory path if it doesn't exist (for monitoring parent directory)
MONITOR_DIR="/host/.ai/env"
if [[ ! -d "$MONITOR_DIR" ]]; then
  log_message "Creating directory path for monitoring: $MONITOR_DIR"
  mkdir -p "$MONITOR_DIR"
fi

# Function to run when files change
handle_change() {
  local file=$1
  local event=$2
  
  log_message "Detected $event on $file"
  log_message "Running credential setup..."
  /usr/local/bin/aws-setup.sh
}

log_message "Starting inotify monitoring..."

# Monitor loop using inotifywait
while true; do
  # Monitor the directory for create, modify, moved_to events
  # Will trigger on file creation, modification, or being moved into the directory
  inotifywait -q -e create,modify,moved_to "$MONITOR_DIR" 2>/dev/null | while read -r directory event filename; do
    # Only act on our target files
    if [[ "$filename" == "awsvault_url" || "$filename" == "awsvault_token" ]]; then
      handle_change "$directory$filename" "$event"
    fi
  done
  
  # Small delay to prevent high CPU usage in case of issues with inotifywait
  sleep 1
done