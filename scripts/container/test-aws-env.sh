#!/bin/bash
# Test script to check AWS environment variables

# Print as root user
echo "As root user:"
echo "AWS_CONTAINER_CREDENTIALS_FULL_URI: ${AWS_CONTAINER_CREDENTIALS_FULL_URI}"
echo "AWS_CONTAINER_AUTHORIZATION_TOKEN: ${AWS_CONTAINER_AUTHORIZATION_TOKEN}"

# Print as claude-user
echo -e "\nAs claude-user:"
gosu claude-user bash -c 'echo "AWS_CONTAINER_CREDENTIALS_FULL_URI: ${AWS_CONTAINER_CREDENTIALS_FULL_URI}"'
gosu claude-user bash -c 'echo "AWS_CONTAINER_AUTHORIZATION_TOKEN: ${AWS_CONTAINER_AUTHORIZATION_TOKEN}"'

# Print after sourcing credentials
echo -e "\nAs claude-user (after sourcing credentials):"
gosu claude-user bash -c 'source /etc/profile.d/aws-credentials.sh && echo "AWS_CONTAINER_CREDENTIALS_FULL_URI: ${AWS_CONTAINER_CREDENTIALS_FULL_URI}"'
gosu claude-user bash -c 'source /etc/profile.d/aws-credentials.sh && echo "AWS_CONTAINER_AUTHORIZATION_TOKEN: ${AWS_CONTAINER_AUTHORIZATION_TOKEN}"'

# Try AWS command
echo -e "\nTesting AWS command:"
gosu claude-user bash -c 'source /etc/profile.d/aws-credentials.sh && aws sts get-caller-identity'