#!/bin/bash
# entrypoint.sh - Container entrypoint script that keeps the container alive
set -e

# Map host.docker.internal to 169.254.170.2 for AWS CLI compatibility (for backward compatibility)
if ! grep -q "169.254.170.2.*host.docker.internal" /etc/hosts; then
  echo "169.254.170.2 host.docker.internal" >> /etc/hosts
  echo "Added host.docker.internal mapping to /etc/hosts"
fi

# Set up AWS credential proxy using the consolidated setup script
echo "Setting up AWS credential proxy..."
# Ensure fixed credential URL is set (should already be set from Dockerfile)
echo "Using fixed credential URL: $AWS_CONTAINER_CREDENTIALS_FULL_URI"

if [[ -f "/host/.ai/env/awsvault_url" ]]; then
  # Run the setup script - now it only manages socat proxy and token
  /usr/local/bin/aws-setup.sh
else
  echo "WARNING: AWS credential file not found at /host/.ai/env/awsvault_url"
fi

# Set up bash profile to create claudy alias and add AWS connectivity check
cat > /root/.bashrc << 'EOF'
# Always run aws-setup.sh to ensure credentials are refreshed
/usr/local/bin/aws-setup.sh >/dev/null 2>&1 || echo "Failed to refresh AWS credentials"

# Source AWS credentials file (will be created by aws-setup.sh)
[[ -f /etc/profile.d/aws-credentials.sh ]] && source /etc/profile.d/aws-credentials.sh

# Claude CLI alias with permissions bypass
alias claudy="claude --dangerously-skip-permissions"

# AWS connectivity check function
aws_check() {
  echo -e "\033[1;34mTesting AWS connectivity...\033[0m"
  if aws sts get-caller-identity &> /dev/null; then
    echo -e "\033[1;32m✓ AWS credentials are working properly!\033[0m"
  else
    echo -e "\033[1;31m✗ AWS credential test failed!\033[0m"
    echo -e "\033[1;33mTroubleshooting steps:\033[0m"
    echo -e "  1. Check if aws-vault is running on your host machine"
    echo -e "  2. Restart credential server: ai-awsvault <profile>"
    echo -e "  3. Restart container: ai-up -y --force"
    echo -e "  4. Check AWS region setting: echo \$AWS_REGION"
    echo -e "  5. Verify network connectivity to AWS services"
  fi
}

# Run AWS check when starting an interactive shell
aws_check
EOF

# Start credential monitor in background
/usr/local/bin/aws-cred-monitor.sh &

# Keep container running indefinitely with sleep loop
echo "Container started and running in background mode - with rebuild test"
while true; do
  sleep 3600
done