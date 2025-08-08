# AI Sandbox - AI Test Plan

This document outlines a comprehensive test plan for using AI to test the AI Sandbox system. It includes automated tests that can be performed by AI, as well as sections that require manual testing.

## Table of Contents

1. [Test Environment Setup](#1-test-environment-setup)
2. [Installation and Configuration Testing](#2-installation-and-configuration-testing)
3. [AWS Credential Handling Tests](#3-aws-credential-handling-tests)
4. [Container Management Tests](#4-container-management-tests)
5. [Claude Integration Testing](#5-claude-integration-testing)
6. [Error Handling Tests](#6-error-handling-tests)
7. [Configuration Testing](#7-configuration-testing)
8. [Manual Testing Requirements](#8-manual-testing-requirements)
9. [End-to-End Manual Test Procedure](#9-end-to-end-manual-test-procedure)
10. [Helper Scripts Reference](#10-helper-scripts-reference)

## Status Tracking

Each major test section includes a status marker to track progress:
- `[ ]` or `[TODO]` - Test not yet started
- `[IN PROGRESS]` - Test currently being executed
- `[DONE]` - Test completed successfully

When you find issues that require fixes, modify the code in the AI Sandbox repository and commit the changes before continuing testing.

## 1. Test Environment Setup

**Status: [ ]**

### 1.1 Prepare Test Directory

**Status: [ ]**

1. Create the test directory structure:
   ```bash
   mkdir -p test/sandbox-test
   cd test
   ```

2. Clone the AI Sandbox repository:
   ```bash
   git clone https://github.com/dil-ddaradics/ai-sandbox.git
   ```

3. Verify that Docker/Colima is running:
   ```bash
   docker ps
   ```
   If it's not running, request human intervention to start it.

### 1.2 Prepare Test Repository

**Status: [ ]**

1. Initialize a git repository in the test directory:
   ```bash
   cd sandbox-test
   git init
   echo "# Test Repository" > README.md
   git add README.md
   git commit -m "Initial commit"
   ```

2. Return to the parent directory:
   ```bash
   cd ..
   ```

## 2. Installation and Configuration Testing

**Status: [ ]**

### 2.1 Basic Installation Test

**Status: [ ]**

1. Install the sandbox in test repository:
   ```bash
   ./ai-sandbox/install.sh --non-interactive sandbox-test
   ```

2. Wait 3 seconds for installation to complete:
   ```bash
   echo "Waiting 3 seconds for installation to complete..."
   sleep 3
   ```

3. Verify installation success:
   ```bash
   ls -la sandbox-test/.cc
   ```

3. Check that scripts were installed:
   ```bash
   ls -la sandbox-test/.cc/scripts/
   ```

### 2.2 Installation without Direnv

**Status: [ ]**

1. Clean up the previous installation:
   ```bash
   rm -rf sandbox-test/.cc
   rm -f sandbox-test/.envrc
   ```

2. Run installation with no-direnv flag:
   ```bash
   ./ai-sandbox/install.sh --non-interactive --no-direnv sandbox-test
   ```

3. Wait 3 seconds for installation to complete:
   ```bash
   echo "Waiting 3 seconds for installation to complete..."
   sleep 3
   ```

4. Verify configuration:
   ```bash
   cat sandbox-test/.cc/.ccenv | grep USE_DIRENV
   ```

### 2.3 Re-installation Test

**Status: [ ]**

1. Make a change to the example config:
   ```bash
   echo "TEST_VAR=test_value" >> sandbox-test/.cc/.ccenv
   ```

2. Re-run the installation:
   ```bash
   ./ai-sandbox/install.sh --non-interactive sandbox-test
   ```

3. Verify that the installation preserved custom settings:
   ```bash
   cat sandbox-test/.cc/.ccenv | grep TEST_VAR
   ```

### 2.4 Installation Error Handling

**Status: [ ]**

1. Test installation in a non-git directory:
   ```bash
   mkdir -p test-not-git
   ./ai-sandbox/install.sh --non-interactive test-not-git 2>&1 || true
   ```

2. Test with missing parameters:
   ```bash
   ./ai-sandbox/install.sh --non-interactive 2>&1 || true
   ```

## 3. AWS Credential Handling Tests

**Status: [ ]**

### 3.1 Starting Credential Server

**Status: [ ]**

1. Start the credential server with the test profile:
   ```bash
   cd sandbox-test
   export PATH="$PATH:$(pwd)/.cc/scripts"
   cc-awsvault dil-rc-issuemanager-dev
   ```

2. Verify the credential server is running:
   ```bash
   lsof -i :9099 | grep aws-vault
   ```

3. Check that the URL file was created:
   ```bash
   cat $HOME/.cc/awsvault_url
   ```

### 3.2 Credential Server Status

**Status: [ ]**

1. Create a tmux session for credential monitoring:
   ```bash
   mkdir -p logs
   tmux new-session -d -s cred-test "watch -n 2 'lsof -i :9099; ps aux | grep aws-vault'" 
   tmux pipe-pane -o -t cred-test 'cat >> logs/cred-test.log'
   ```

2. Let it run for a minute, then check the logs:
   ```bash
   cat logs/cred-test.log
   ```

3. Kill the tmux session when done:
   ```bash
   tmux kill-session -t cred-test
   ```

### 3.3 AWS Credential Validation

**Status: [ ]**

1. Run the AWS credential validator script:
   ```bash
   ./ai-sandbox/tests/scripts/aws-cred-validator.sh
   ```
   
2. Wait 5 seconds for credential validation to complete:
   ```bash
   echo "Waiting 5 seconds for credential validation to complete..."
   sleep 5
   ```

2. Verify that AWS credentials are working:
   ```bash
   export IMDS_URL=$(cat $HOME/.cc/awsvault_url)
   AWS_CONTAINER_CREDENTIALS_FULL_URI=$IMDS_URL aws s3 ls
   ```

## 4. Container Management Tests

**Status: [ ]**

### 4.1 Container Creation

**Status: [ ]**

1. Create a container for the main branch:
   ```bash
   cd sandbox-test
   cc-up -y
   ```

2. Verify container creation:
   ```bash
   docker ps | grep cc-
   cat .cc-container
   ```

### 4.2 Container Creation - Specific Branch

**Status: [ ]**

1. Create a container for a specific branch:
   ```bash
   cc-up -y feature/test-branch
   ```

2. Verify the container and worktree:
   ```bash
   docker ps | grep cc-feature-test-branch
   ls -la $HOME/worktrees/sandbox-test/feature/test-branch
   ```

### 4.3 Container Environment

**Status: [ ]**

1. Check environment variables in the container:
   ```bash
   CONTAINER=$(cat .cc-container)
   docker exec $CONTAINER env | grep -E 'AWS_|CLAUDE_|ANTHROPIC_'
   ```

2. Verify workspace mount:
   ```bash
   docker exec $CONTAINER ls -la /workspace
   ```

### 4.4 AWS Credential Verification in Container

**Status: [ ]**

1. Verify AWS credentials work in the container using get-caller-identity:
   ```bash
   CONTAINER=$(cat .cc-container)
   IMDS_URL=$(cat $HOME/.cc/awsvault_url)
   docker exec $CONTAINER bash -c "AWS_CONTAINER_CREDENTIALS_FULL_URI=$IMDS_URL aws sts get-caller-identity"
   ```

2. Wait 3 seconds for credential validation to complete:
   ```bash
   echo "Waiting 3 seconds after credential validation..."
   sleep 3
   ```

## 5. Claude Integration Testing

**Status: [ ]**

### 5.1 Claude Installation Check

**Status: [ ]**

1. Verify Claude is installed in the container:
   ```bash
   CONTAINER=$(cat .cc-container)
   docker exec $CONTAINER which claude
   ```

### 5.2 Simple Prompt Testing

**Status: [ ]**

1. Test a basic prompt with an explicit timeout:
   ```bash
   ./ai-sandbox/tests/scripts/cc-prompt --timeout 45 $CONTAINER "Explain what Git worktrees are in one paragraph."
   ```

### 5.3 Claude AWS Access Test

**Status: [ ]**

1. Test Claude's ability to access AWS information with an explicit timeout:
   ```bash
   ./ai-sandbox/tests/scripts/cc-prompt --timeout 90 $CONTAINER "What AWS account am I currently using? Use the AWS CLI to run 'aws sts get-caller-identity' and explain the output."
   ```

## 6. Error Handling Tests

**Status: [ ]**

### 6.1 AWS Profile Validation

**Status: [ ]**

1. Test with an invalid AWS profile:
   ```bash
   cc-awsvault nonexistent-profile 2>&1 || true
   ```

2. Wait 2 seconds for error output to complete:
   ```bash
   sleep 2
   ```

3. Check error handling:
   ```bash
   echo $?
   ```

### 6.2 Container Error Handling

**Status: [ ]**

1. Test container creation without credential server:
   ```bash
   cc-awsvault-stop
   mkdir -p test-error
   cd test-error
   git init
   touch README.md
   git add README.md
   git commit -m "Initial commit"
   ../ai-sandbox/install.sh --non-interactive .
   export PATH="$PATH:$(pwd)/.cc/scripts"
   cc-up -y 2>&1 || true
   ```

2. Check error messages:
   ```bash
   echo $?
   ```

## 7. Configuration Testing

**Status: [ ]**

### 7.1 Configuration File Validation

**Status: [ ]**

1. Check the default configuration:
   ```bash
   cat sandbox-test/.cc/.ccenv.example
   ```

2. Test custom configuration:
   ```bash
   cd sandbox-test
   echo "CPU_LIMIT=2" > .cc/.ccenv
   echo "MEM_LIMIT=4g" >> .cc/.ccenv
   cc-up -y custom-config-test
   ```

3. Wait 10 seconds for container to apply resource limits:
   ```bash
   echo "Waiting 10 seconds for container to apply resource limits..."
   sleep 10
   ```

4. Verify resource limits:
   ```bash
   docker inspect cc-custom-config-test | grep -A10 "HostConfig"
   ```

### 7.2 Environment Variable Propagation

**Status: [ ]**

1. Set custom environment variables:
   ```bash
   echo "TEST_ENV_VAR=hello_world" >> .cc/.ccenv
   cc-up -y env-test
   ```

2. Wait 8 seconds for container environment to initialize:
   ```bash
   echo "Waiting 8 seconds for container environment to initialize..."
   sleep 8
   ```

3. Verify the variables are passed to the container:
   ```bash
   docker exec cc-env-test env | grep TEST_ENV_VAR
   ```

## 8. Manual Testing Requirements

**Status: [ ]**

The following tests require manual intervention and cannot be fully automated with AI:

### 8.1 Interactive Claude Sessions

**Status: [ ]**

- Launch and interact with the full Claude interface using `cc-chat`
- Test multi-turn conversations and context retention
- Verify code editing capabilities in interactive mode

### 8.2 Long-Running Credential Tests

**Status: [ ]**

- Test credential expiration and renewal after extended periods
- Verify behavior when credentials expire during active use
- Test session persistence across multiple days

### 8.3 Sleep/Wake Cycle Testing

**Status: [ ]**

- Test system behavior when host machine sleeps and wakes up
- Verify credential server reconnection after sleep
- Test container state preservation across sleep cycles

### 8.4 Multi-User Scenarios

**Status: [ ]**

- Test with multiple users accessing the same repository
- Verify credential isolation between users
- Test behavior with conflicting container operations

### 8.5 Network Interruption Recovery

**Status: [ ]**

- Test behavior during network outages
- Verify recovery when network connectivity is restored
- Test credential server recovery after network issues

## 9. End-to-End Manual Test Procedure

**Status: [ ]**

This comprehensive manual test verifies the complete workflow of the AI Sandbox system:

### 9.1 Setup

**Status: [ ]**

1. Clone the AI Sandbox repository
   ```bash
   git clone https://github.com/dil-ddaradics/ai-sandbox.git
   ```

2. Prepare a test repository
   ```bash
   mkdir -p test-manual
   cd test-manual
   git init
   echo "# Manual Test Repository" > README.md
   git add README.md
   git commit -m "Initial commit"
   ```

### 9.2 Installation

**Status: [ ]**

1. Install the AI Sandbox
   ```bash
   ../ai-sandbox/install.sh .
   ```

2. Wait 3 seconds for installation to complete:
   ```bash
   echo "Waiting 3 seconds for installation to complete..."
   sleep 3
   ```

3. Verify installation
   ```bash
   ls -la .cc
   cat .cc/.ccenv
   ```

### 9.3 AWS Credential Setup

**Status: [ ]**

1. Start the credential server
   ```bash
   export PATH="$PATH:$(pwd)/.cc/scripts"
   cc-awsvault your-aws-profile
   ```

2. Wait 5 seconds for credential server to initialize:
   ```bash
   echo "Waiting 5 seconds for credential server to initialize..."
   sleep 5
   ```

3. Verify credential server is running
   ```bash
   lsof -i :9099
   ```

### 9.4 Container Creation

**Status: [ ]**

1. Create a container for the main branch
   ```bash
   cc-up
   ```

2. Wait 10 seconds for container to initialize:
   ```bash
   echo "Waiting 10 seconds for container to initialize..."
   sleep 10
   ```

3. Verify container creation
   ```bash
   docker ps
   ```

### 9.5 Claude Interaction

**Status: [ ]**

1. Launch Claude
   ```bash
   cc-chat
   ```

2. Test basic interactions:
   - Ask "What is Docker?"
   - Ask "What files are in this directory?"
   - Test code generation

### 9.6 Branch Testing

**Status: [ ]**

1. Create a new branch
   ```bash
   git checkout -b feature/test
   ```

2. Create a container for the new branch
   ```bash
   cc-up
   ```

3. Wait 10 seconds for container to initialize:
   ```bash
   echo "Waiting 10 seconds for container to initialize..."
   sleep 10
   ```

4. Verify containers for both branches
   ```bash
   docker ps
   ```

### 9.7 Cleanup

**Status: [ ]**

1. Stop containers
   ```bash
   cc-clean
   ```

2. Stop credential server
   ```bash
   cc-awsvault-stop
   ```

3. Uninstall AI Sandbox
   ```bash
   ../ai-sandbox/uninstall.sh .
   ```

4. Verify cleanup
   ```bash
   ls -la | grep .cc
   docker ps | grep cc-
   ```

## 10. Helper Scripts Reference

The following helper scripts are available in the `tests/scripts/` directory to assist with AI testing:

### 10.1 cc-prompt

A wrapper script for non-interactive Claude commands that capture output:
```bash
cc-prompt [CONTAINER_NAME] "Your prompt here"
```

### 10.2 aws-cred-validator.sh

A script to validate AWS credentials:
```bash
aws-cred-validator.sh
```

### 10.3 tmux-test-helper.sh

A script for managing tmux sessions for multi-terminal testing:
```bash
tmux-test-helper.sh [start|stop|log] SESSION_NAME COMMAND
```