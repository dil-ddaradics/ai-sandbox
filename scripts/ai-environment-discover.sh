#!/usr/bin/env bash
# ai-environment-discover.sh - Find all AI Sandbox environments
set -euo pipefail
source "$(dirname "$0")/_common.sh"
_need docker

# Parse arguments
JSON_OUTPUT=false
INCLUDE_STOPPED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --all)
      INCLUDE_STOPPED=true
      shift
      ;;
    -h|--help)
      echo "Usage: ai-environment-discover.sh [OPTIONS]"
      echo
      echo "Options:"
      echo "  --json        Output in JSON format for MCP integration"
      echo "  --all         Include stopped containers in the output"
      echo "  -h, --help    Show this help message"
      echo
      exit 0
      ;;
    *)
      _red "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Function to convert Docker timestamp to human-readable format
format_timestamp() {
  local timestamp=$1
  date -r $(date -j -f "%Y-%m-%dT%H:%M:%S" "${timestamp%.*}" "+%s") "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$timestamp"
}

# Fetch all AI Sandbox containers
if $INCLUDE_STOPPED; then
  FILTER_ARG="--all"
else
  FILTER_ARG=""
fi

# Get the list of containers with their details
CONTAINERS=$(docker ps $FILTER_ARG --filter "name=ai-" --format '{{json .}}')

# Process containers and gather details
ENVIRONMENTS=()
while IFS= read -r container_json; do
  # Skip empty lines
  [[ -z "$container_json" ]] && continue
  
  CONTAINER_ID=$(echo "$container_json" | sed -E 's/.*"ID":"([^"]+)".*/\1/')
  CONTAINER_NAME=$(echo "$container_json" | sed -E 's/.*"Names":"([^"]+)".*/\1/')
  STATUS=$(echo "$container_json" | sed -E 's/.*"State":"([^"]+)".*/\1/')
  CREATED=$(echo "$container_json" | sed -E 's/.*"CreatedAt":"([^"]+)".*/\1/')
  
  # Extract repo name and branch name from container name
  # Expected format: ai-{repo}-{branch}
  REPO_NAME=$(echo "$CONTAINER_NAME" | sed -E 's/^ai-([^-]+).*/\1/')
  BRANCH_NAME=$(echo "$CONTAINER_NAME" | sed -E 's/^ai-[^-]+-(.+)/\1/' | sed 's/-/\//g')
  
  # Get Docker container labels for metadata
  LABELS_JSON=$(docker inspect --format '{{json .Config.Labels}}' "$CONTAINER_ID" 2>/dev/null || echo "{}")
  
  # Extract metadata from labels
  REPO_PATH=$(echo "$LABELS_JSON" | grep -o '"ai.sandbox.repo_path":"[^"]*"' | cut -d'"' -f4)
  IS_WORKTREE=$(echo "$LABELS_JSON" | grep -o '"ai.sandbox.is_worktree":"[^"]*"' | cut -d'"' -f4)
  CREATED_LABEL=$(echo "$LABELS_JSON" | grep -o '"ai.sandbox.created":"[^"]*"' | cut -d'"' -f4)
  
  # If required labels are missing, exit with error
  if [[ -z "$REPO_PATH" || -z "$IS_WORKTREE" ]]; then
    if $JSON_OUTPUT; then
      printf '{"error": "Required Docker labels missing for container %s. Container may have been created with an older version."}\n' "$CONTAINER_NAME"
    else
      _red "Error: Required Docker labels missing for container $CONTAINER_NAME"
      _red "Container may have been created with an older version."
    fi
    exit 1
  fi
  
  # Use the creation timestamp from label
  if [[ -z "$CREATED_LABEL" ]]; then
    if $JSON_OUTPUT; then
      printf '{"error": "Creation timestamp label missing for container %s. Container may have been created with an older version."}\n' "$CONTAINER_NAME"
    else
      _red "Error: Creation timestamp label missing for container $CONTAINER_NAME"
      _red "Container may have been created with an older version."
    fi
    exit 1
  fi
  CREATED_DISPLAY="$CREATED_LABEL"
  
  # Get credential status
  CREDENTIAL_STATUS="unknown"
  if docker exec -it "$CONTAINER_ID" test -f /tmp/.aws_cred_env 2>/dev/null; then
    # Check if credentials are expired by trying to read expiration
    if docker exec -it "$CONTAINER_ID" grep -q "expires" /tmp/.aws_cred_env 2>/dev/null; then
      EXPIRATION=$(docker exec -it "$CONTAINER_ID" grep "expires" /tmp/.aws_cred_env 2>/dev/null | cut -d '=' -f2 || echo "unknown")
      
      # Check if expiration is in the future
      if [[ "$EXPIRATION" != "unknown" ]]; then
        EXPIRATION_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${EXPIRATION%Z}" "+%s" 2>/dev/null || echo "0")
        NOW=$(date +%s)
        
        if [[ $EXPIRATION_EPOCH -gt $NOW ]]; then
          CREDENTIAL_STATUS="valid"
        else
          CREDENTIAL_STATUS="expired"
        fi
      fi
    else
      CREDENTIAL_STATUS="missing"
    fi
  fi
  
  # Format human-readable creation time
  CREATED_HUMAN=$(format_timestamp "$CREATED_DISPLAY")
  
  # Add to the environments array
  ENVIRONMENTS+=("$(cat <<EOJ
{
  "container_id": "$CONTAINER_ID",
  "container_name": "$CONTAINER_NAME",
  "repo_name": "$REPO_NAME",
  "branch_name": "$BRANCH_NAME",
  "status": "$STATUS",
  "created": "$CREATED_DISPLAY",
  "created_human": "$CREATED_HUMAN",
  "credential_status": "$CREDENTIAL_STATUS",
  "workspace_dir": "$REPO_PATH",
  "is_worktree": $IS_WORKTREE
}
EOJ
)")
done <<< "$CONTAINERS"

# Output results based on format
if $JSON_OUTPUT; then
  # Format as JSON array
  printf '{"environments": [\n'
  for i in "${!ENVIRONMENTS[@]}"; do
    printf '%s' "${ENVIRONMENTS[$i]}"
    if [[ $i -lt $((${#ENVIRONMENTS[@]} - 1)) ]]; then
      printf ',\n'
    else
      printf '\n'
    fi
  done
  printf ']}\n'
else
  # Human-readable output
  _green "AI Sandbox Environments:"
  
  # Group environments by repository
  declare -A REPOS
  for env in "${ENVIRONMENTS[@]}"; do
    REPO=$(echo "$env" | grep -o '"repo_name":"[^"]*"' | cut -d'"' -f4)
    REPOS["$REPO"]+="$env"$'\n'
  done
  
  # Print environments grouped by repository
  for repo in "${!REPOS[@]}"; do
    echo ""
    _green "Repository: $repo"
    printf "  %-25s %-15s %-20s %-15s %s\n" "BRANCH" "STATUS" "CREATED" "CREDS" "WORKSPACE"
    printf "  %-25s %-15s %-20s %-15s %s\n" "-------------------------" "---------------" "--------------------" "---------------" "-------------------------"
    
    IFS=$'\n'
    for env in ${REPOS["$repo"]}; do
      BRANCH=$(echo "$env" | grep -o '"branch_name":"[^"]*"' | cut -d'"' -f4)
      STATUS=$(echo "$env" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
      CREATED=$(echo "$env" | grep -o '"created_human":"[^"]*"' | cut -d'"' -f4)
      CREDS=$(echo "$env" | grep -o '"credential_status":"[^"]*"' | cut -d'"' -f4)
      WORKSPACE=$(echo "$env" | grep -o '"workspace_dir":"[^"]*"' | cut -d'"' -f4)
      IS_WORKTREE=$(echo "$env" | grep -o '"is_worktree":[^,}]*' | cut -d':' -f2 | tr -d ' ')
      
      # Format status for display
      case "$STATUS" in
        running) STATUS="\e[32mrunning\e[0m" ;;
        exited|stopped) STATUS="\e[31mstopped\e[0m" ;;
        *) ;;
      esac
      
      # Format credential status for display
      case "$CREDS" in
        valid) CREDS="\e[32mvalid\e[0m" ;;
        expired) CREDS="\e[31mexpired\e[0m" ;;
        missing) CREDS="\e[33mmissing\e[0m" ;;
        *) CREDS="\e[33munknown\e[0m" ;;
      esac
      
      # Add worktree indicator
      BRANCH_DISPLAY="$BRANCH"
      if [[ "$IS_WORKTREE" == "true" ]]; then
        BRANCH_DISPLAY="$BRANCH (worktree)"
      fi
      
      printf "  %-25s %-15b %-20s %-15b %s\n" "$BRANCH_DISPLAY" "$STATUS" "$CREATED" "$CREDS" "$WORKSPACE"
    done
  done
  
  echo ""
  _green "Management commands:"
  echo "  ai-up [branch]         # Create/start sandbox environment"
  echo "  ai-stop                # Stop the container"
  echo "  ai-clean [--all]       # Clean up the worktree and container"
  echo "  ai-awsvault <profile>  # Start credential server"
fi

exit 0