#!/usr/bin/env bash
# aws-cred-validator.sh - Test AWS credential functionality
# This script validates AWS credentials by performing simple read-only operations

set -euo pipefail

# Color output functions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

_red() { printf "${RED}%s${NC}\n" "$*"; }
_green() { printf "${GREEN}%s${NC}\n" "$*"; }
_yellow() { printf "${YELLOW}%s${NC}\n" "$*"; }
_blue() { printf "${BLUE}%s${NC}\n" "$*"; }

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
  _red "Error: AWS CLI is not installed."
  exit 1
fi

# Usage function
usage() {
  echo "Usage: aws-cred-validator.sh [OPTIONS]"
  echo
  echo "Options:"
  echo "  --container NAME     Run tests in a specific container"
  echo "  --url URL            Use a specific IMDS URL"
  echo "  --profile NAME       Use a specific AWS profile"
  echo "  --help               Show this help message"
  echo
  echo "Examples:"
  echo "  aws-cred-validator.sh"
  echo "  aws-cred-validator.sh --container cc-main"
  echo "  aws-cred-validator.sh --url http://host.docker.internal:9099/"
  echo
  exit 1
}

# Parse arguments
CONTAINER_NAME=""
IMDS_URL=""
AWS_PROFILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --container)
      shift
      CONTAINER_NAME="$1"
      shift
      ;;
    --url)
      shift
      IMDS_URL="$1"
      shift
      ;;
    --profile)
      shift
      AWS_PROFILE="$1"
      shift
      ;;
    --help)
      usage
      ;;
    -*)
      _red "Unknown option: $1"
      usage
      ;;
    *)
      _red "Unknown argument: $1"
      usage
      ;;
  esac
done

# Function to determine container name if not provided
determine_container() {
  local cwd
  local container_file
  
  cwd=$(pwd)
  container_file="${cwd}/.cc-container"
  
  if [[ -f "$container_file" ]]; then
    cat "$container_file"
    return 0
  fi
  
  # Look for any running cc- container
  local running_container
  running_container=$(docker ps --format "{{.Names}}" | grep "^cc-" | head -n 1)
  
  if [[ -n "$running_container" ]]; then
    echo "$running_container"
    return 0
  fi
  
  return 1
}

# Function to determine IMDS URL if not provided
determine_imds_url() {
  # Try to get URL from environment or file
  if [[ -n "${IMDS_URL:-}" ]]; then
    echo "$IMDS_URL"
    return 0
  fi
  
  if [[ -f "$HOME/.cc/awsvault_url" ]]; then
    cat "$HOME/.cc/awsvault_url"
    return 0
  fi
  
  return 1
}

# Function to test credentials directly
test_credentials_direct() {
  _blue "Testing AWS credentials directly..."
  
  # First, try AWS STS get-caller-identity
  _blue "Testing sts get-caller-identity..."
  if aws sts get-caller-identity; then
    _green "✓ Successfully authenticated with AWS"
    
    # Extract account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    USER_ARN=$(aws sts get-caller-identity --query "Arn" --output text)
    
    _green "AWS Account: $ACCOUNT_ID"
    _green "IAM User/Role: $USER_ARN"
  else
    _red "✗ Failed to authenticate with AWS"
    return 1
  fi
  
  # Test listing S3 buckets (read-only)
  _blue "Testing S3 bucket listing (read-only)..."
  if aws s3 ls; then
    _green "✓ Successfully listed S3 buckets"
  else
    _yellow "⚠ Could not list S3 buckets - may not have permissions"
  fi
  
  # Test EC2 describe regions (read-only)
  _blue "Testing EC2 region listing (read-only)..."
  if aws ec2 describe-regions --query "Regions[].RegionName" --output text; then
    _green "✓ Successfully listed EC2 regions"
  else
    _yellow "⚠ Could not list EC2 regions - may not have permissions"
  fi
  
  _green "AWS credential validation completed successfully"
  return 0
}

# Function to test credentials in container
test_credentials_container() {
  local container="$1"
  local imds_url="$2"
  
  _blue "Testing AWS credentials in container $container..."
  _blue "Using IMDS URL: $imds_url"
  
  # Check if container is running
  if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
    _red "Error: Container $container is not running"
    return 1
  fi
  
  # Test environment variables
  _blue "Checking AWS environment variables in container..."
  docker exec "$container" env | grep -E "AWS_|IMDS_" || _yellow "⚠ No AWS environment variables found"
  
  # Test AWS STS get-caller-identity in container
  _blue "Testing AWS STS get-caller-identity in container..."
  if docker exec "$container" bash -c "AWS_CONTAINER_CREDENTIALS_FULL_URI=$imds_url aws sts get-caller-identity"; then
    _green "✓ Container successfully authenticated with AWS"
    
    # Extract account info
    ACCOUNT_ID=$(docker exec "$container" bash -c "AWS_CONTAINER_CREDENTIALS_FULL_URI=$imds_url aws sts get-caller-identity --query Account --output text")
    USER_ARN=$(docker exec "$container" bash -c "AWS_CONTAINER_CREDENTIALS_FULL_URI=$imds_url aws sts get-caller-identity --query Arn --output text")
    
    _green "AWS Account: $ACCOUNT_ID"
    _green "IAM User/Role: $USER_ARN"
  else
    _red "✗ Container failed to authenticate with AWS"
    return 1
  fi
  
  # Test listing S3 buckets in container
  _blue "Testing S3 bucket listing in container..."
  if docker exec "$container" bash -c "AWS_CONTAINER_CREDENTIALS_FULL_URI=$imds_url aws s3 ls"; then
    _green "✓ Container successfully listed S3 buckets"
  else
    _yellow "⚠ Container could not list S3 buckets - may not have permissions"
  fi
  
  # Test running Claude in container with AWS access
  _blue "Testing Claude with AWS access in container..."
  if command -v ./cc-prompt &> /dev/null; then
    ./cc-prompt "$container" "What AWS region am I in? Use the AWS CLI to check." --timeout 30 || _yellow "⚠ Claude AWS test failed or timed out"
  else
    _yellow "⚠ cc-prompt script not found, skipping Claude AWS test"
  fi
  
  _green "Container AWS credential validation completed successfully"
  return 0
}

# Main function
main() {
  _blue "AWS Credential Validator"
  
  # If no specific test mode defined, determine what to test
  if [[ -z "$CONTAINER_NAME" && -z "$IMDS_URL" && -z "$AWS_PROFILE" ]]; then
    # Try to determine container and IMDS URL
    CONTAINER_NAME=$(determine_container || true)
    IMDS_URL=$(determine_imds_url || true)
    
    if [[ -n "$CONTAINER_NAME" && -n "$IMDS_URL" ]]; then
      _green "Detected container: $CONTAINER_NAME"
      _green "Detected IMDS URL: $IMDS_URL"
      test_credentials_container "$CONTAINER_NAME" "$IMDS_URL"
    elif [[ -n "$IMDS_URL" ]]; then
      _green "Detected IMDS URL: $IMDS_URL"
      export AWS_CONTAINER_CREDENTIALS_FULL_URI="$IMDS_URL"
      test_credentials_direct
    else
      _yellow "No container or IMDS URL detected, testing direct AWS credentials"
      test_credentials_direct
    fi
  else
    # Specific test mode defined
    if [[ -n "$CONTAINER_NAME" ]]; then
      # Test in container
      if [[ -z "$IMDS_URL" ]]; then
        IMDS_URL=$(determine_imds_url || true)
        
        if [[ -z "$IMDS_URL" ]]; then
          _red "Error: No IMDS URL provided or detected"
          exit 1
        fi
      fi
      
      test_credentials_container "$CONTAINER_NAME" "$IMDS_URL"
    elif [[ -n "$IMDS_URL" ]]; then
      # Test with specific IMDS URL
      export AWS_CONTAINER_CREDENTIALS_FULL_URI="$IMDS_URL"
      test_credentials_direct
    elif [[ -n "$AWS_PROFILE" ]]; then
      # Test with specific AWS profile
      export AWS_PROFILE
      test_credentials_direct
    fi
  fi
}

# Run the main function
main