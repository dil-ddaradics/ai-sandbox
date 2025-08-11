#!/bin/bash
# test-cred-refresh.sh - Tests the AWS credential refresh functionality
set -e

echo "========================================"
echo "AWS Credential Refresh Test"
echo "========================================"

# Test 1: Check if credential file is mounted
echo -n "Test 1: Checking if credential file is mounted... "
if [[ -f "/host/.cc/awsvault_url" ]]; then
  echo "PASSED"
  echo "  File exists: $(cat /host/.cc/awsvault_url)"
else
  echo "FAILED"
  echo "  File not found: /host/.cc/awsvault_url"
fi
echo

# Test 2: Source refresh script and check env var
echo -n "Test 2: Running refresh script... "
source /usr/local/bin/aws-cred-refresh.sh
if [[ -n "$AWS_CONTAINER_CREDENTIALS_FULL_URI" ]]; then
  echo "PASSED"
  echo "  IMDS URL: $AWS_CONTAINER_CREDENTIALS_FULL_URI"
else
  echo "FAILED"
  echo "  IMDS URL not set after refresh"
fi
echo

# Test 3: Check if env file was created
echo -n "Test 3: Checking if environment file was created... "
if [[ -f "/tmp/.aws_cred_env" ]]; then
  echo "PASSED"
  echo "  File content: $(cat /tmp/.aws_cred_env)"
else
  echo "FAILED"
  echo "  File not found: /tmp/.aws_cred_env"
fi
echo

# Test 4: Simulating URL change
echo "Test 4: Simulating URL change..."
echo "  Current URL: $AWS_CONTAINER_CREDENTIALS_FULL_URI"
echo "  Changing URL in memory..."
export AWS_CONTAINER_CREDENTIALS_FULL_URI="http://host.docker.internal:9999/"
echo "  New URL: $AWS_CONTAINER_CREDENTIALS_FULL_URI"
echo "  Refreshing from file..."
source /usr/local/bin/aws-cred-refresh.sh
echo "  After refresh: $AWS_CONTAINER_CREDENTIALS_FULL_URI"
echo

# Test 5: Check monitor process
echo -n "Test 5: Checking if monitor process is running... "
if pgrep -f "aws-cred-monitor" > /dev/null; then
  echo "PASSED"
  echo "  Process found: $(pgrep -f "aws-cred-monitor")"
else
  echo "FAILED"
  echo "  Monitor process not found"
fi
echo

# Test 6: Test AWS connectivity
echo -n "Test 6: Testing AWS credential server connectivity... "
if /usr/local/bin/aws-connectivity-check.sh > /tmp/connectivity.log 2>&1; then
  echo "PASSED"
  echo "  Credential server is reachable and providing valid credentials"
else
  echo "FAILED (exit code: $?)"
  echo "  Connectivity test failed. See details below:"
  cat /tmp/connectivity.log
fi
echo

echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Credential file: /host/.cc/awsvault_url"
echo "Environment file: /tmp/.aws_cred_env"
echo "Current IMDS URL: $AWS_CONTAINER_CREDENTIALS_FULL_URI"
echo "========================================"