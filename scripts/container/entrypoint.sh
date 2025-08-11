#!/bin/bash
# entrypoint.sh - Container entrypoint script that keeps the container alive
set -e

# Map host.docker.internal to 169.254.170.2 for AWS CLI compatibility (for backward compatibility)
if ! grep -q "169.254.170.2.*host.docker.internal" /etc/hosts; then
  echo "169.254.170.2 host.docker.internal" >> /etc/hosts
  echo "Added host.docker.internal mapping to /etc/hosts"
fi

# Set up socat proxy for AWS credential server
# Read host aws-vault port from the mounted file
echo "Setting up AWS credential proxy..."
CRED_FILE="/host/.cc/env/awsvault_url"
if [[ -f "$CRED_FILE" ]]; then
  PORT=$(sed -n 's#.*:\([0-9][0-9]*\).*#\1#p' "$CRED_FILE")
  : "${PORT:=54491}"
  
  # Choose a container-side proxy port
  : "${PROXY_PORT:=55491}"
  
  echo "Detected credential server port: $PORT, using proxy port: $PROXY_PORT"
  
  # Forward container loopback -> host loopback via host.docker.internal
  socat TCP-LISTEN:${PROXY_PORT},bind=127.0.0.1,fork,reuseaddr TCP:host.docker.internal:${PORT} &
  SOCAT_PID=$!
  echo "Started socat proxy with PID $SOCAT_PID"
  
  # Point AWS CLI/SDK to loopback (use localhost to satisfy strict host checks)
  export AWS_CONTAINER_CREDENTIALS_FULL_URI="http://localhost:${PROXY_PORT}/"
  
  # Read the authorization token
  AUTH_TOKEN_FILE="/host/.cc/env/awsvault_token"
  if [[ -f "$AUTH_TOKEN_FILE" ]]; then
    export AWS_CONTAINER_AUTHORIZATION_TOKEN=$(cat "$AUTH_TOKEN_FILE")
    echo "Read authorization token from $AUTH_TOKEN_FILE"
  fi
  
  # Override any environment variables that might have been set
  echo "export AWS_CONTAINER_CREDENTIALS_FULL_URI=\"http://localhost:${PROXY_PORT}/\"" > /etc/profile.d/aws-credentials.sh
  if [[ -n "$AWS_CONTAINER_AUTHORIZATION_TOKEN" ]]; then
    echo "export AWS_CONTAINER_AUTHORIZATION_TOKEN=\"$AWS_CONTAINER_AUTHORIZATION_TOKEN\"" >> /etc/profile.d/aws-credentials.sh
  fi
  chmod +x /etc/profile.d/aws-credentials.sh
  
  # Smoke test
  echo "Testing AWS credential proxy..."
  if [[ -n "$AWS_CONTAINER_AUTHORIZATION_TOKEN" ]]; then
    if curl -s -H "Authorization: $AWS_CONTAINER_AUTHORIZATION_TOKEN" "http://localhost:${PROXY_PORT}/" | grep -q "AccessKeyId"; then
      echo "AWS credential proxy is working properly with token!"
    else
      echo "WARNING: AWS credential proxy test failed with token. Trying without token..."
      if curl -s "http://localhost:${PROXY_PORT}/" | grep -q "AccessKeyId"; then
        echo "AWS credential proxy is working without token!"
      else
        echo "WARNING: AWS credential proxy test failed. AWS operations may not work."
      fi
    fi
  else
    if curl -s "http://localhost:${PROXY_PORT}/" | grep -q "AccessKeyId"; then
      echo "AWS credential proxy is working without token!"
    else
      echo "WARNING: AWS credential proxy test failed. AWS operations may not work."
    fi
  fi
else
  echo "WARNING: AWS credential file not found at $CRED_FILE"
fi

# Set up bash profile to source credentials
echo "source /usr/local/bin/aws-cred-refresh.sh" > /root/.bashrc

# Initial load of AWS credentials
source /usr/local/bin/aws-cred-refresh.sh

# Start credential monitor in background
/usr/local/bin/aws-cred-monitor.sh &

# Keep container running indefinitely with sleep loop
echo "Container started and running in background mode - with rebuild test"
while true; do
  sleep 3600
done