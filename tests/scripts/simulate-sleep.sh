#!/usr/bin/env bash
# simulate-sleep.sh - Simulates machine sleep/hibernate by disrupting credential server connectivity
set -euo pipefail

URL_FILE="$HOME/.cc/awsvault_url"
SLEEP_DURATION=${1:-30}

# Check if URL file exists
if [[ ! -f "$URL_FILE" ]]; then
  echo "❌ Error: URL file not found at $URL_FILE"
  echo "Please run cc-awsvault <profile> first to create the URL file"
  exit 1
fi

# Get the current container
CONTAINER_ID=$(docker ps -qf "name=cc-" | head -1)
if [[ -z "$CONTAINER_ID" ]]; then
  echo "❌ Error: No running Claude container found"
  echo "Please run cc-up first to create a container"
  exit 1
fi

# Extract credential server information
CRED_URL=$(cat "$URL_FILE")
CRED_PORT=$(echo "$CRED_URL" | grep -oE 'docker\.internal:([0-9]+)' | cut -d: -f2)

if [[ -z "$CRED_PORT" ]]; then
  echo "❌ Error: Could not extract port from credential URL"
  exit 1
fi

# Get PID of the aws-vault credential server
AWS_VAULT_PID=$(lsof -i :"$CRED_PORT" | grep -E "^[0-9]+" | awk '{print $2}' | head -1)

if [[ -z "$AWS_VAULT_PID" ]]; then
  echo "❌ Error: Could not find running aws-vault credential server on port $CRED_PORT"
  exit 1
fi

echo "🔍 Found aws-vault credential server on port $CRED_PORT (PID: $AWS_VAULT_PID)"
echo "🔄 Simulating machine sleep for $SLEEP_DURATION seconds..."

# Determine OS and appropriate method
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS: Use PF firewall
  echo "1) Creating temporary firewall rule to block credential server..."
  
  # Create temporary rule to block the port
  sudo pfctl -t sleepsim -T add 127.0.0.1/32 || true
  sudo pfctl -E || true
  
  echo "2) Waiting $SLEEP_DURATION seconds to simulate sleep..."
  sleep "$SLEEP_DURATION"
  
  echo "3) Removing temporary firewall rule to simulate wake-up..."
  sudo pfctl -t sleepsim -T delete 127.0.0.1/32 || true
else
  # Linux: Use iptables (requires root)
  echo "1) Creating temporary firewall rule to block credential server..."
  
  # Create temporary rule to block the port
  sudo iptables -A INPUT -p tcp --dport "$CRED_PORT" -j DROP
  
  echo "2) Waiting $SLEEP_DURATION seconds to simulate sleep..."
  sleep "$SLEEP_DURATION"
  
  echo "3) Removing temporary firewall rule to simulate wake-up..."
  sudo iptables -D INPUT -p tcp --dport "$CRED_PORT" -j DROP
fi

echo "4) Running connectivity check to verify simulation impact..."
docker exec "$CONTAINER_ID" /usr/local/bin/aws-connectivity-check || true

echo
echo "✅ Sleep simulation completed!"
echo
echo "Test the following:"
echo "1. Try running cc-chat - should detect connectivity issues"
echo "2. Run aws-connectivity-check in container - should fail or show errors"
echo "3. Restart credential server with: cc-awsvault <profile>"
echo "4. Run aws-connectivity-check again - should now pass"
echo "5. Run cc-chat - should work normally again"