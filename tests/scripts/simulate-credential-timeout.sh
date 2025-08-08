#!/usr/bin/env bash
# simulate-credential-timeout.sh - Simulates AWS credential timeout or expiration
set -euo pipefail

URL_FILE="$HOME/.cc/awsvault_url"

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

# Create backup of credential environment file in container
echo "📋 Creating backup of credential environment file in container..."
docker exec "$CONTAINER_ID" cp /tmp/.aws_cred_env /tmp/.aws_cred_env.bak || {
  echo "❌ Error: Could not create backup of credential environment file"
  exit 1
}

# Ask what type of timeout to simulate
echo "Choose timeout simulation type:"
echo "1) Empty credentials (empty file)"
echo "2) Expired credentials (modify expiration time)"
echo "3) Invalid credentials (corrupt access keys)"
echo "4) Temporarily block credential server URL"
read -p "Enter choice (1-4): " timeout_choice

case $timeout_choice in
  1)
    # Empty credentials file
    echo "🔄 Simulating empty credentials..."
    docker exec "$CONTAINER_ID" sh -c 'echo "" > /tmp/.aws_cred_env'
    echo "✅ Simulated timeout: Empty credentials file"
    ;;
  2)
    # Expired credentials
    echo "🔄 Simulating expired credentials..."
    docker exec "$CONTAINER_ID" sh -c '
      sed -i "s/AWS_SESSION_EXPIRATION=.*/AWS_SESSION_EXPIRATION=\"1970-01-01T00:00:00Z\"/" /tmp/.aws_cred_env
    '
    echo "✅ Simulated timeout: Expired credentials"
    ;;
  3)
    # Invalid credentials
    echo "🔄 Simulating invalid credentials..."
    docker exec "$CONTAINER_ID" sh -c '
      sed -i "s/AWS_ACCESS_KEY_ID=.*/AWS_ACCESS_KEY_ID=\"INVALIDXXXXXXXXXXXXXXXX\"/" /tmp/.aws_cred_env
      sed -i "s/AWS_SECRET_ACCESS_KEY=.*/AWS_SECRET_ACCESS_KEY=\"INVALIDSECRETXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\"/" /tmp/.aws_cred_env
    '
    echo "✅ Simulated timeout: Invalid credentials"
    ;;
  4)
    # Block credential server URL temporarily
    CRED_URL=$(cat "$URL_FILE")
    CRED_PORT=$(echo "$CRED_URL" | grep -oE 'docker\.internal:([0-9]+)' | cut -d: -f2)
    
    if [[ -n "$CRED_PORT" ]]; then
      echo "🔄 Temporarily blocking credential server on port $CRED_PORT..."
      
      # Back up the URL file and create a temporary firewall rule (macOS)
      if [[ "$(uname)" == "Darwin" ]]; then
        sudo pfctl -t credblock -T add 127.0.0.1/32 || true
        sudo pfctl -E || true
        echo "✅ Blocked credential server with firewall rule"
        echo "Press Enter to unblock after testing (or wait 60 seconds for auto-unblock)"
        
        # Auto-unblock after 60 seconds in background
        (
          sleep 60
          sudo pfctl -t credblock -T delete 127.0.0.1/32 || true
          echo "🔓 Auto-unblocked credential server after timeout"
        ) &
        
        read -p ""
        sudo pfctl -t credblock -T delete 127.0.0.1/32 || true
        echo "🔓 Unblocked credential server"
      else
        # For Linux
        echo "⚠️ Firewall blocking not implemented for this OS"
        echo "Try one of the other simulation methods instead"
      fi
    else
      echo "❌ Could not extract port from credential URL"
    fi
    ;;
  *)
    echo "❌ Invalid choice, not simulating timeout"
    exit 1
    ;;
esac

echo
echo "🔍 Testing container response to credential timeout..."
echo "Run the following to see how the container handles the timeout:"
echo "  docker exec $CONTAINER_ID /usr/local/bin/aws-connectivity-check"
echo "  cc-chat    # Should show connectivity errors"
echo
echo "To restore the original credentials:"
echo "  docker exec $CONTAINER_ID cp /tmp/.aws_cred_env.bak /tmp/.aws_cred_env"