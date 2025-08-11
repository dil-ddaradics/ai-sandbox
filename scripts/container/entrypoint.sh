#!/bin/bash
# entrypoint.sh - Container entrypoint script that keeps the container alive
set -e

# Set up bash profile to source credentials
echo "source /usr/local/bin/aws-cred-refresh.sh" > /root/.bashrc

# Initial load of AWS credentials
source /usr/local/bin/aws-cred-refresh.sh

# Run credential monitor in foreground to keep container alive
# This keeps the container running indefinitely
exec /usr/local/bin/aws-cred-monitor.sh