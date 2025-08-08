#!/usr/bin/env bash
# tmux-test-helper.sh - Helper script for multi-terminal testing with tmux
# This script manages tmux sessions for parallel testing and command execution

set -euo pipefail

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

_red() { printf "${RED}%s${NC}\n" "$*"; }
_green() { printf "${GREEN}%s${NC}\n" "$*"; }
_yellow() { printf "${YELLOW}%s${NC}\n" "$*"; }
_blue() { printf "${BLUE}%s${NC}\n" "$*"; }

# Check for tmux
if ! command -v tmux &> /dev/null; then
  _red "Error: tmux is not installed. Please install tmux to use this script."
  exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p logs

# Usage function
usage() {
  echo "Usage: tmux-test-helper.sh COMMAND [OPTIONS]"
  echo
  echo "Commands:"
  echo "  start SESSION_NAME COMMAND    Start a new tmux session with the given name and command"
  echo "  stop SESSION_NAME             Stop a tmux session"
  echo "  send SESSION_NAME COMMAND     Send a command to an existing session"
  echo "  list                         List all test sessions"
  echo "  log SESSION_NAME              Show logs from a session"
  echo "  status SESSION_NAME           Show status of a session"
  echo "  wait SESSION_NAME [SECONDS]   Wait for a session to complete (timeout in seconds)"
  echo
  echo "Options:"
  echo "  --help                        Show this help message"
  echo
  echo "Examples:"
  echo "  tmux-test-helper.sh start aws-test \"cc-awsvault dev-profile\""
  echo "  tmux-test-helper.sh log aws-test"
  echo "  tmux-test-helper.sh send aws-test \"echo Still running\""
  echo "  tmux-test-helper.sh stop aws-test"
  echo
  exit 1
}

# Parse arguments
if [[ $# -eq 0 ]]; then
  usage
fi

COMMAND="$1"
shift

case "$COMMAND" in
  start)
    # Start a new session
    if [[ $# -lt 2 ]]; then
      _red "Error: start command requires SESSION_NAME and COMMAND"
      usage
    fi
    
    SESSION_NAME="$1"
    shift
    RUN_COMMAND="$*"
    
    # Check if session already exists
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      _red "Error: session $SESSION_NAME already exists"
      exit 1
    fi
    
    # Generate log file name with timestamp
    LOG_FILE="logs/${SESSION_NAME}-$(date +%F-%H%M%S).log"
    
    # Create a new detached tmux session
    _blue "Starting tmux session '$SESSION_NAME' with command: $RUN_COMMAND"
    tmux new-session -d -s "$SESSION_NAME" "$RUN_COMMAND |& tee -a $LOG_FILE"
    
    # Set up automatic logging
    tmux pipe-pane -o -t "$SESSION_NAME" "cat >> $LOG_FILE"
    
    _green "✓ Session started with log file: $LOG_FILE"
    ;;
    
  stop)
    # Stop a session
    if [[ $# -lt 1 ]]; then
      _red "Error: stop command requires SESSION_NAME"
      usage
    fi
    
    SESSION_NAME="$1"
    
    # Check if session exists
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      _red "Error: session $SESSION_NAME not found"
      exit 1
    fi
    
    # Kill the tmux session
    tmux kill-session -t "$SESSION_NAME"
    _green "✓ Session $SESSION_NAME stopped"
    ;;
    
  send)
    # Send a command to a session
    if [[ $# -lt 2 ]]; then
      _red "Error: send command requires SESSION_NAME and COMMAND"
      usage
    fi
    
    SESSION_NAME="$1"
    shift
    SEND_COMMAND="$*"
    
    # Check if session exists
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      _red "Error: session $SESSION_NAME not found"
      exit 1
    fi
    
    # Send the command to the session
    tmux send-keys -t "$SESSION_NAME" "$SEND_COMMAND" C-m
    _green "✓ Command sent to session $SESSION_NAME: $SEND_COMMAND"
    ;;
    
  list)
    # List all test sessions
    _blue "Active test sessions:"
    
    # Get list of tmux sessions
    SESSIONS=$(tmux list-sessions 2>/dev/null | cut -d ':' -f 1 || echo "")
    
    if [[ -z "$SESSIONS" ]]; then
      _yellow "No active sessions found"
    else
      for session in $SESSIONS; do
        _green "- $session"
      done
    fi
    ;;
    
  log)
    # Show logs from a session
    if [[ $# -lt 1 ]]; then
      _red "Error: log command requires SESSION_NAME"
      usage
    fi
    
    SESSION_NAME="$1"
    
    # Find the most recent log file for this session
    LOG_FILE=$(ls -t logs/${SESSION_NAME}-*.log 2>/dev/null | head -n 1)
    
    if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
      _red "Error: no log file found for session $SESSION_NAME"
      exit 1
    fi
    
    _blue "Showing log for session $SESSION_NAME from $LOG_FILE:"
    echo "----------------------------------------"
    cat "$LOG_FILE"
    echo "----------------------------------------"
    ;;
    
  status)
    # Show status of a session
    if [[ $# -lt 1 ]]; then
      _red "Error: status command requires SESSION_NAME"
      usage
    fi
    
    SESSION_NAME="$1"
    
    # Check if session exists
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
      _red "Session $SESSION_NAME is not running"
      exit 1
    else
      _green "Session $SESSION_NAME is running"
      
      # Find the most recent log file
      LOG_FILE=$(ls -t logs/${SESSION_NAME}-*.log 2>/dev/null | head -n 1)
      
      if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        _blue "Last 5 lines from log file $LOG_FILE:"
        echo "----------------------------------------"
        tail -n 5 "$LOG_FILE"
        echo "----------------------------------------"
      fi
    fi
    ;;
    
  wait)
    # Wait for a session to complete with optional timeout
    if [[ $# -lt 1 ]]; then
      _red "Error: wait command requires SESSION_NAME"
      usage
    fi
    
    SESSION_NAME="$1"
    TIMEOUT=${2:-300}  # Default timeout: 300 seconds
    
    _blue "Waiting for session $SESSION_NAME to complete (timeout: ${TIMEOUT}s)..."
    
    # Start timer
    START_TIME=$(date +%s)
    END_TIME=$((START_TIME + TIMEOUT))
    
    # Check session status in a loop
    while [[ $(date +%s) -lt $END_TIME ]]; do
      if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        _green "✓ Session $SESSION_NAME has completed"
        exit 0
      fi
      sleep 1
    done
    
    _yellow "Timeout reached waiting for session $SESSION_NAME"
    exit 1
    ;;
    
  --help)
    usage
    ;;
    
  *)
    _red "Unknown command: $COMMAND"
    usage
    ;;
esac