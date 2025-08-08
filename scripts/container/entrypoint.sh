#!/bin/bash
# entrypoint.sh - Container entrypoint script that starts the credential monitor
set -e

# Set up bash profile to source credentials
echo "source /usr/local/bin/aws-cred-refresh" > /root/.bashrc

# Initial load of AWS credentials
source /usr/local/bin/aws-cred-refresh

# Start credential monitor in background
/usr/local/bin/aws-cred-monitor.sh &

# Execute the CMD
exec "$@"