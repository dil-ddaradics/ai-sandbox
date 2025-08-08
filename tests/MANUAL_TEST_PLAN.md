# AI Sandbox Manual Test Plan

This document outlines a comprehensive set of manual tests to verify the functionality of the AI Sandbox system, including edge cases and error handling. Follow these steps to ensure the system works correctly across various scenarios.

## Table of Contents
1. [Installation and Setup Tests](#1-installation-and-setup-tests)
2. [Credential Management Tests](#2-credential-management-tests)
3. [Container Management Tests](#3-container-management-tests)
4. [AWS Credential Handling Tests](#4-aws-credential-handling-tests)
5. [Edge Case Tests](#5-edge-case-tests)
6. [Helper Scripts](#6-helper-scripts)

## Test Environment Prerequisites
- macOS (Ventura or Sonoma)
- Homebrew
- Docker & Colima
- AWS CLI and AWS SSO access
- Git repository for testing

## 1. Installation and Setup Tests

### 1.1 Fresh Installation Test
**Purpose:** Verify that the system can be installed fresh on a clean repository.

**Steps:**
1. Clone a fresh Git repository for testing
   ```bash
   git clone https://github.com/your/test-repo.git test-fresh
   cd test-fresh
   ```
2. Clone the AI Sandbox repository
   ```bash
   git clone https://github.com/dil-ddaradics/ai-sandbox.git
   ```
3. Run the installation script
   ```bash
   ./ai-sandbox/install.sh $(pwd)
   ```

**Expected Results:**
- Installation completes without errors
- `.cc` directory created with scripts
- If direnv is installed, `.envrc` file is updated
- Confirmation message displayed

### 1.2 Installation Without Direnv
**Purpose:** Verify installation works correctly without direnv.

**Steps:**
1. Clone a fresh Git repository for testing
   ```bash
   git clone https://github.com/your/test-repo.git test-no-direnv
   cd test-no-direnv
   ```
2. Run the installation script with the no-direnv flag
   ```bash
   ./ai-sandbox/install.sh --no-direnv $(pwd)
   ```

**Expected Results:**
- Installation completes without errors
- USE_DIRENV=0 set in the .cc/.ccenv file
- Clear instructions shown about how to manually add scripts to PATH
- `.envrc` file not modified or not using direnv integration

### 1.3 Re-installation Test
**Purpose:** Verify that the system can be re-installed over an existing installation.

**Steps:**
1. Clone a Git repository where AI Sandbox is already installed
   ```bash
   git clone https://github.com/your/existing-repo.git test-reinstall
   cd test-reinstall
   ```
2. Verify the existing installation
   ```bash
   ls -la .cc
   cat .cc/.ccenv
   ```
3. Re-run the installation script (with or without --no-direnv flag)
   ```bash
   # To keep existing direnv setting:
   ./ai-sandbox/install.sh $(pwd)
   
   # Or to change to no-direnv mode:
   ./ai-sandbox/install.sh --no-direnv $(pwd)
   ```

**Expected Results:**
- Re-installation completes without errors
- Existing files overwritten cleanly
- No duplicate entries in `.envrc` if direnv is installed
- USE_DIRENV setting in .ccenv file updated correctly if --no-direnv flag used

### 1.4 Installation Error Handling
**Purpose:** Verify that the installation handles error cases correctly.

**Steps:**
1. Create a non-Git directory
   ```bash
   mkdir test-not-git
   cd test-not-git
   ```
2. Run the installation script
   ```bash
   ./ai-sandbox/install.sh $(pwd)
   ```

**Expected Results:**
- Clear error message indicating the directory is not a Git repository
- Script exits with non-zero status
- No files created or modified

## 2. Credential Management Tests

### 2.1 AWS Profile Validation
**Purpose:** Verify that the system correctly validates AWS profiles.

**Steps:**
1. Try starting the credential server with a valid AWS profile
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Try starting the credential server with an invalid AWS profile
   ```bash
   cc-awsvault nonexistent-profile
   ```

**Expected Results:**
- Valid profile: Credential server starts successfully
- Invalid profile: Clear error message, no credential server started
- URL file not created/updated for invalid profile

### 2.2 Credential Server Persistence
**Purpose:** Verify that credential server persists across terminal sessions.

**Steps:**
1. Start the credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Open a new terminal window/tab
3. Run the credential listing command
   ```bash
   cc-list-creds
   ```

**Expected Results:**
- New terminal shows the running credential server
- URL file still exists and points to the correct server

### 2.3 Credential Listing
**Purpose:** Verify that the credential listing command works correctly.

**Steps:**
1. Start the credential server if not already running
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Run the credential listing command
   ```bash
   cc-list-creds
   ```

**Expected Results:**
- Command shows the running credential server
- Displays PID, port, age, and command details
- Status shows as "RUNNING"

### 2.4 Credential Server Stopping
**Purpose:** Verify that the credential server can be stopped properly.

**Steps:**
1. Start the credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Stop the credential server
   ```bash
   cc-awsvault-stop
   ```
3. Run the credential listing command
   ```bash
   cc-list-creds
   ```
4. Try stopping when no server is running
   ```bash
   cc-awsvault-stop
   ```

**Expected Results:**
- Server stops successfully
- Listing shows no running servers after stopping
- Stopping non-existent server handles gracefully with appropriate message

### 2.5 Credential Testing
**Purpose:** Verify that credential testing works correctly.

**Steps:**
1. Start the credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Run the credential test
   ```bash
   cc-test-creds
   ```

**Expected Results:**
- All credential tests pass
- Shows successful credential retrieval and validation
- No error messages

## 3. Container Management Tests

### 3.1 Container Creation - Current Branch
**Purpose:** Verify containers can be created for the current branch.

**Steps:**
1. Checkout your main branch
   ```bash
   git checkout main
   ```
2. Create a container
   ```bash
   cc-up
   ```

**Expected Results:**
- Container created successfully
- Worktree set up for main branch
- Container running with the correct mounts

### 3.2 Container Creation - Specific Branch
**Purpose:** Verify containers can be created for a specific branch.

**Steps:**
1. Create a container for a specific branch
   ```bash
   cc-up feature/test-branch
   ```

**Expected Results:**
- Branch created if it doesn't exist
- Container created successfully
- Worktree set up for specified branch
- Container running with the correct mounts

### 3.3 Container Resource Limits
**Purpose:** Verify container resource limits can be customized.

**Steps:**
1. Create a `.cc/.ccenv` file with custom resource limits
   ```bash
   echo "CPU_LIMIT=2" > .cc/.ccenv
   echo "MEM_LIMIT=4g" >> .cc/.ccenv
   ```
2. Create a container
   ```bash
   cc-up test-resources
   ```
3. Verify resource limits
   ```bash
   docker inspect cc-test-resources | grep -A10 "HostConfig"
   ```

**Expected Results:**
- Container created with specified resource limits
- Docker inspect shows the correct CPU and memory limits

### 3.4 Claude Chat Interface
**Purpose:** Verify the Claude chat interface works correctly.

**Steps:**
1. Create a container if not already running
   ```bash
   cc-up
   ```
2. Open the Claude chat interface
   ```bash
   cc-chat
   ```

**Expected Results:**
- Claude Code interface opens successfully
- AWS credentials work within the container
- No connection errors

### 3.5 Container Stopping
**Purpose:** Verify container can be stopped correctly.

**Steps:**
1. Create a container
   ```bash
   cc-up
   ```
2. Stop the container
   ```bash
   cc-stop
   ```
3. Verify the container is stopped
   ```bash
   docker ps | grep cc-
   ```

**Expected Results:**
- Container stops successfully
- No running containers with cc- prefix
- Worktree still exists

### 3.6 Cleanup
**Purpose:** Verify cleanup works correctly.

**Steps:**
1. Create a container
   ```bash
   cc-up
   ```
2. Clean up the worktree and container
   ```bash
   cc-clean
   ```
3. Try full cleanup including credential server
   ```bash
   cc-up
   cc-clean --all
   ```

**Expected Results:**
- Regular cleanup: Container removed, worktree removed
- Full cleanup: Container removed, worktree removed, credential server stopped
- Directory structure cleaned up

## 4. AWS Credential Handling Tests

### 4.1 Initial Credential Loading
**Purpose:** Verify initial credential loading works correctly.

**Steps:**
1. Start the credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Create a container
   ```bash
   cc-up
   ```
3. Check the environment inside the container
   ```bash
   docker exec -it $(docker ps -qf "name=cc-") env | grep AWS
   ```

**Expected Results:**
- AWS environment variables set correctly in container
- AWS_CONTAINER_CREDENTIALS_FULL_URI points to credential server
- Credentials can be used for AWS operations

### 4.2 Credential Refresh
**Purpose:** Verify credential refresh works when URL changes.

**Steps:**
1. Start the credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Create a container
   ```bash
   cc-up
   ```
3. Stop and restart the credential server with same profile
   ```bash
   cc-awsvault-stop
   cc-awsvault your-valid-profile
   ```
4. Wait for the monitor refresh interval (default 5 seconds)
5. Check the environment inside the container
   ```bash
   docker exec -it $(docker ps -qf "name=cc-") env | grep AWS
   ```

**Expected Results:**
- Container automatically detects the changed credential URL
- Environment variables updated with new credential information
- No container restart required

### 4.3 Connectivity Check
**Purpose:** Verify AWS credential connectivity checks work correctly.

**Steps:**
1. Start the credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Run the AWS connectivity check script directly
   ```bash
   docker exec -it $(docker ps -qf "name=cc-") /usr/local/bin/aws-connectivity-check
   ```

**Expected Results:**
- Connectivity check passes
- Shows successful connection to credential server
- Displays valid credential confirmation

### 4.4 AWS Operation Verification
**Purpose:** Verify AWS operations work correctly with credentials.

**Steps:**
1. Start the credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Create a container
   ```bash
   cc-up
   ```
3. Run a simple AWS CLI command inside the container
   ```bash
   docker exec -it $(docker ps -qf "name=cc-") aws sts get-caller-identity
   ```

**Expected Results:**
- AWS command runs successfully
- Shows correct account and user information
- No credential errors

## 5. Edge Case Tests

### 5.1 Edge Case: Invalid AWS Profile
**Purpose:** Verify behavior when using invalid AWS profile.

**Steps:**
1. Try starting credential server with non-existent profile
   ```bash
   cc-awsvault nonexistent-profile
   ```
2. Try starting container after above failure
   ```bash
   cc-up
   ```

**Expected Results:**
- Clear error message about invalid profile
- No credential server started
- Container creation fails with helpful error message
- Script suggests correct command to set up credentials

### 5.2 Edge Case: Docker/Colima Not Running
**Purpose:** Verify behavior when Docker is not available.

**Steps:**
1. Stop Docker/Colima if running
   ```bash
   colima stop
   ```
2. Try running container commands
   ```bash
   cc-up
   cc-chat
   ```
3. Restart Docker/Colima when done
   ```bash
   colima start
   ```

**Expected Results:**
- Clear error message about Docker not being available
- Scripts fail gracefully with helpful error message
- Suggests starting Docker/Colima

### 5.3 Edge Case: Multiple Credential Servers
**Purpose:** Verify behavior when multiple credential servers are running.

**Steps:**
1. Start credential server normally
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Manually start another aws-vault server on different port
   ```bash
   aws-vault exec --server --backend=file your-valid-profile -- aws sts get-caller-identity
   ```
3. Run the credential listing command
   ```bash
   cc-list-creds
   ```

**Expected Results:**
- Both credential servers shown in listing
- Clear distinction between the official one and manual one
- System continues to work with the officially started server

### 5.4 Edge Case: AWS Credential Server Timeout
**Purpose:** Verify behavior when credentials expire or timeout.

**Steps:**
1. Start credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Create container
   ```bash
   cc-up
   ```
3. Run the helper script to simulate credential timeout (see Helper Scripts section)
   ```bash
   ./tests/scripts/simulate-credential-timeout.sh
   ```

**Expected Results:**
- Container detects credential issues
- Monitoring script attempts to refresh credentials
- Clear error message if credentials cannot be refreshed
- Instructions provided for restarting credential server

### 5.5 Edge Case: Missing Dependencies
**Purpose:** Verify behavior when required dependencies are missing.

**Steps:**
1. Temporarily move aws-vault binary to simulate missing dependency
   ```bash
   sudo mv $(which aws-vault) $(which aws-vault).bak
   ```
2. Try starting credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
3. Restore aws-vault when done
   ```bash
   sudo mv $(which aws-vault).bak $(which aws-vault)
   ```

**Expected Results:**
- Clear error message about missing dependency
- Helpful instructions for installing the missing component
- Script exits without further errors

### 5.6 Edge Case: URL File Corruption
**Purpose:** Verify behavior when the credential URL file is corrupted.

**Steps:**
1. Start credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Create container
   ```bash
   cc-up
   ```
3. Run the helper script to corrupt the URL file
   ```bash
   ./tests/scripts/simulate-url-corruption.sh
   ```

**Expected Results:**
- Container detects corrupted URL file
- Monitoring script logs the issue
- Clear error message in logs
- Script handles corruption gracefully without crashing

### 5.7 Edge Case: Machine Sleep/Hibernate
**Purpose:** Verify behavior when machine sleeps and wakes up.

**Steps:**
1. Start credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Create container
   ```bash
   cc-up
   ```
3. Run the helper script to simulate sleep (or actually put your machine to sleep for 30 seconds)
   ```bash
   ./tests/scripts/simulate-sleep.sh
   ```
4. After wake-up, try to use Claude
   ```bash
   cc-chat
   ```

**Expected Results:**
- System detects potential connectivity issues after wake-up
- Clear error message about credential server being unavailable
- Instructions for restarting credential server
- Container remains running but credential access fails until server restarted

### 5.8 Edge Case: Network Connectivity Loss
**Purpose:** Verify behavior when network connectivity is lost.

**Steps:**
1. Start credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Create container
   ```bash
   cc-up
   ```
3. Disable network (turn off Wi-Fi or disconnect ethernet)
4. Try to use Claude
   ```bash
   cc-chat
   ```
5. Enable network again

**Expected Results:**
- System detects network connectivity issues
- Clear error message about connection problems
- Container remains running
- Functionality restored when network returns

### 5.9 Edge Case: Orphaned Credential Server
**Purpose:** Verify behavior with orphaned credential server processes.

**Steps:**
1. Start credential server
   ```bash
   cc-awsvault your-valid-profile
   ```
2. Manually kill the process to simulate abrupt termination
   ```bash
   kill -9 $(pgrep -f "aws-vault.*--server")
   ```
3. Run the credential listing command
   ```bash
   cc-list-creds
   ```
4. Run the cleanup with credential server termination
   ```bash
   cc-clean --all
   ```

**Expected Results:**
- Listing correctly shows stale URL but no running process
- Cleanup handles orphaned references gracefully
- URL file is cleaned up when requested

### 5.10 Edge Case: Concurrent Container Operations
**Purpose:** Verify behavior when multiple container operations run concurrently.

**Steps:**
1. Open multiple terminals
2. In terminal 1, run:
   ```bash
   cc-up feature/test1
   ```
3. Immediately in terminal 2, run:
   ```bash
   cc-up feature/test2
   ```
4. Check container statuses
   ```bash
   docker ps | grep cc-
   ```

**Expected Results:**
- Operations do not interfere with each other
- Both containers created successfully
- No race conditions or corrupted state

## 6. Helper Scripts

Several helper scripts are available in the `tests/scripts` directory to assist with testing edge cases:

### 6.1 simulate-url-corruption.sh
Corrupts the credential URL file to test error handling.

**Usage:**
```bash
./tests/scripts/simulate-url-corruption.sh
```

### 6.2 simulate-credential-timeout.sh
Simulates credential timeout or expiration.

**Usage:**
```bash
./tests/scripts/simulate-credential-timeout.sh
```

### 6.3 simulate-sleep.sh
Simulates machine sleep/hibernate by temporarily disrupting credential server connectivity.

**Usage:**
```bash
./tests/scripts/simulate-sleep.sh
```

### 6.4 test-multi-branch.sh
Tests container creation across multiple branches.

**Usage:**
```bash
./tests/scripts/test-multi-branch.sh
```

### 6.5 test-credential-refresh.sh
Tests credential refresh mechanisms in detail.

**Usage:**
```bash
./tests/scripts/test-credential-refresh.sh
```

## Test Reporting

For each test, record:
1. Pass/Fail status
2. Any unexpected behavior
3. Error messages received
4. Steps taken to resolve issues

This will help identify patterns and improve system reliability.