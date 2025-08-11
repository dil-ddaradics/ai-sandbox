#!/bin/bash
# entrypoint.sh - Container entrypoint script that keeps the container alive
set -e

# Set up bash profile to source credentials
echo "source /usr/local/bin/aws-cred-refresh.sh" > /root/.bashrc

# Initial load of AWS credentials
source /usr/local/bin/aws-cred-refresh.sh

# Start credential monitor in background
/usr/local/bin/aws-cred-monitor.sh &

# Keep container running indefinitely with sleep loop
echo "Container started and running in background mode"
while true; do
  sleep 3600
done