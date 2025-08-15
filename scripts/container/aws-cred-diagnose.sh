#!/bin/bash
# aws-cred-diagnose.sh - Diagnoses AWS credential issues in the container
set -e

echo "===== AWS Credential Diagnostic Tool ====="
echo

# Check credential files
echo "Checking credential files..."
CRED_FILE="/host/.ai/env/awsvault_url"
TOKEN_FILE="/host/.ai/env/awsvault_token"

if [[ -f "$CRED_FILE" ]]; then
  echo "✓ Credential URL file exists: $CRED_FILE"
  HOST_URL=$(cat "$CRED_FILE")
  HOST_PORT=$(echo "$HOST_URL" | sed -n 's#.*:\([0-9][0-9]*\).*#\1#p')
  echo "  - Host URL: $HOST_URL"
  echo "  - Host Port: $HOST_PORT"
else
  echo "✗ Credential URL file missing: $CRED_FILE"
fi

if [[ -f "$TOKEN_FILE" ]]; then
  echo "✓ Token file exists: $TOKEN_FILE"
  TOKEN_LENGTH=$(wc -c < "$TOKEN_FILE")
  echo "  - Token length: $TOKEN_LENGTH characters"
else
  echo "✗ Token file missing: $TOKEN_FILE"
fi

# Check environment variables
echo
echo "Checking environment variables..."
if [[ -n "$AWS_CONTAINER_CREDENTIALS_FULL_URI" ]]; then
  echo "✓ AWS_CONTAINER_CREDENTIALS_FULL_URI is set: $AWS_CONTAINER_CREDENTIALS_FULL_URI"
  CONTAINER_PORT=$(echo "$AWS_CONTAINER_CREDENTIALS_FULL_URI" | sed -n 's#.*:\([0-9][0-9]*\).*#\1#p')
  echo "  - Container proxy port: $CONTAINER_PORT"
else
  echo "✗ AWS_CONTAINER_CREDENTIALS_FULL_URI is not set"
fi

if [[ -n "$AWS_CONTAINER_AUTHORIZATION_TOKEN" ]]; then
  echo "✓ AWS_CONTAINER_AUTHORIZATION_TOKEN is set (length: ${#AWS_CONTAINER_AUTHORIZATION_TOKEN})"
else
  echo "✗ AWS_CONTAINER_AUTHORIZATION_TOKEN is not set"
fi

# Check profile.d script
PROFILE_SCRIPT="/etc/profile.d/aws-credentials.sh"
echo
echo "Checking profile.d script..."
if [[ -f "$PROFILE_SCRIPT" ]]; then
  echo "✓ AWS credentials profile script exists"
  CRED_URL_IN_SCRIPT=$(grep AWS_CONTAINER_CREDENTIALS_FULL_URI "$PROFILE_SCRIPT" | grep -o 'http://[^"]*')
  TOKEN_IN_SCRIPT=$(grep -q AWS_CONTAINER_AUTHORIZATION_TOKEN "$PROFILE_SCRIPT" && echo "present" || echo "missing")
  echo "  - Credential URL in script: $CRED_URL_IN_SCRIPT"
  echo "  - Authorization token in script: $TOKEN_IN_SCRIPT"
else
  echo "✗ AWS credentials profile script missing: $PROFILE_SCRIPT"
fi

# Check socat proxy
echo
echo "Checking socat proxy process..."
SOCAT_RUNNING=$(ps aux | grep "socat.*TCP-LISTEN" | grep -v grep)
if [[ -n "$SOCAT_RUNNING" ]]; then
  echo "✓ Socat proxy is running:"
  echo "$SOCAT_RUNNING" | awk '{print "  - PID: " $2 ", Command: " $11 " " $12 " " $13 " " $14}'
  LISTEN_PORT=$(echo "$SOCAT_RUNNING" | grep -o "TCP-LISTEN:[0-9]*" | cut -d: -f2)
  TARGET_PORT=$(echo "$SOCAT_RUNNING" | grep -o "TCP:host.docker.internal:[0-9]*" | cut -d: -f3)
  echo "  - Listening on port: $LISTEN_PORT, forwarding to host port: $TARGET_PORT"
  
  if [[ "$HOST_PORT" != "$TARGET_PORT" ]]; then
    echo "✗ ERROR: Host port ($HOST_PORT) and socat target port ($TARGET_PORT) mismatch!"
  fi
else
  echo "✗ Socat proxy is not running"
fi

# Test credential access
echo
echo "Testing credential access..."
if [[ -n "$AWS_CONTAINER_CREDENTIALS_FULL_URI" ]]; then
  if [[ -n "$AWS_CONTAINER_AUTHORIZATION_TOKEN" ]]; then
    echo "Testing with token..."
    if curl -s -f -m 2 -H "Authorization: $AWS_CONTAINER_AUTHORIZATION_TOKEN" "$AWS_CONTAINER_CREDENTIALS_FULL_URI" | grep -q "AccessKeyId"; then
      echo "✓ Credential access successful with token"
    else
      echo "✗ Credential access failed with token"
    fi
  fi
  
  echo "Testing without token..."
  if curl -s -f -m 2 "$AWS_CONTAINER_CREDENTIALS_FULL_URI" | grep -q "AccessKeyId"; then
    echo "✓ Credential access successful without token"
  else
    echo "✗ Credential access failed without token"
  fi
else
  echo "✗ Cannot test credentials: AWS_CONTAINER_CREDENTIALS_FULL_URI not set"
fi

# Test AWS CLI
echo
echo "Testing AWS CLI..."
if aws sts get-caller-identity &>/dev/null; then
  echo "✓ AWS CLI can access credentials and call AWS services"
  aws sts get-caller-identity
else
  echo "✗ AWS CLI failed to access credentials"
  echo "AWS_REGION is set to: ${AWS_REGION:-not set}"
  
  # Check common issues
  if [[ -z "$AWS_REGION" ]]; then
    echo "  - AWS_REGION is not set, which may cause issues with some services"
  fi
  
  if [[ -z "$AWS_CONTAINER_CREDENTIALS_FULL_URI" ]]; then
    echo "  - AWS_CONTAINER_CREDENTIALS_FULL_URI is not set"
  fi
  
  if [[ ! -f "$CRED_FILE" ]]; then
    echo "  - Host credential file is missing"
  fi
fi

echo
echo "===== Diagnostic Complete ====="