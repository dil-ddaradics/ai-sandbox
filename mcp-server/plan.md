# AI Sandbox MCP Server Enhancement Plan

This document outlines the plan for enhancing the existing MCP server with capabilities to interact with AI Sandbox features and provide comprehensive information to AI assistants.

## Overview

The enhanced MCP server will enable AI assistants to:
1. Access comprehensive documentation about AI Sandbox
2. Check and manage AWS credentials for AI Sandbox environments
3. View, create, and manage AI Sandbox environments across repositories

## Core Design Principle

**All MCP resources and tools will be implemented as thin wrappers around bash scripts.**

- Each feature will first be implemented as a standalone bash script
- Scripts will be independently testable via command line
- MCP server will primarily call these scripts and format their output
- This approach ensures maintainability and separation of concerns

## Functional Areas

Rather than separating by resource type and tool type, this plan groups functionality by domain area, keeping related resources and tools together.

### 1. Documentation

| Component Type | Name | Description | Bash Script |
|--------------|-------------|-------------|------------|
| Resource | `sandbox-documentation` | Comprehensive documentation about AI Sandbox | `ai-documentation-get.sh` |
| Resource | `sandbox-installation` | Checks if ai-sandbox is globally installed and provides installation instructions | N/A (implemented directly in MCP server) |

The documentation functionality will:
- Provide complete information about AI Sandbox features, prerequisites, workflows, and configuration
- Parse and format the README.md content for optimal AI consumption
- Include links to relevant sections for quick reference
- Implement as a bash script that reads and formats the README.md

The installation check functionality will:
- Check if the ai-sandbox is globally installed (`install-ai-sandbox` command available in PATH)
- Provide detailed installation instructions if not found
- Include prerequisites and steps for global installation
- Return information about proper installation verification
- Be implemented directly in the MCP server using Node.js functionality
- Used by other MCP components to verify prerequisites before execution

### 2. Credentials Management

| Component Type | Name | Description | Parameters | Bash Script |
|--------------|-------------|-------------|------------|------------|
| Resource | `sandbox-credentials` | Status of AWS credential servers | None | `ai-credentials-status.sh` |
| Tool | `start-credentials` | Start the AWS credential server | `profile`: AWS profile name to use | `ai-credentials-start.sh` |
| Tool | `list-credentials` | List running credential servers | None | `ai-credentials-list.sh` |
| Tool | `stop-credentials` | Stop credential server | None | `ai-credentials-stop.sh` |
| Tool | `test-credentials` | Test credential handling in a container | None | `ai-credentials-test.sh` |

The credentials functionality will:
- Show the status of all AWS credential servers
- Start and stop credential servers
- Test if credentials are working correctly
- Provide detailed information about credential expiration and validity

### 3. Environment Management

| Component Type | Name | Description | Parameters | Bash Script |
|--------------|-------------|-------------|------------|------------|
| Resource | `sandbox-environments` | Comprehensive view of all AI Sandbox environments | None | `ai-environment-discover.sh` |
| Tool | `create-environment` | Create workspace for a branch | `branch_name`: Name of branch (optional) | `ai-environment-create.sh` |
| Tool | `stop-environment` | Stop the container | `branch_name`: Name of branch (optional) | `ai-environment-stop.sh` |
| Tool | `clean-environment` | Clean up worktree and container | `branch_name`: Name of branch (optional), `all`: Boolean to also stop credential server | `ai-environment-clean.sh` |
| Tool | `list-environments` | Show all environments and their status | None | `ai-environment-list.sh` |

The environment functionality will:
- Show all sandbox environments across all repositories
- Group environments by repository
- Include branch information, running state, and creation time
- Show AWS credential status for each environment
- Indicate which environments are worktrees vs. main repositories
- Allow creation, stopping, and cleaning of environments

## Docker Metadata Approach

To track sandbox environments effectively, we will:

1. **Extend Docker Container Labels:**
   ```yaml
   labels:
     - "ai.sandbox.repo_path=${REPO_PATH}"
     - "ai.sandbox.branch=${BRANCH_NAME}"
     - "ai.sandbox.is_worktree=${IS_WORKTREE}"
     - "ai.sandbox.created=${TIMESTAMP}"
   ```

2. **Extend `.env.compose` File:**
   ```bash
   # Added to .env.compose
   REPO_PATH=/absolute/path/to/repository
   BRANCH_NAME=feature/branch-name
   IS_WORKTREE=true|false
   TIMESTAMP=2023-08-18T14:30:00Z
   ```

3. **Create a Discovery Script:**
   - Use `docker ps` to find all containers with our labels
   - Group and structure the information by repository
   - Extract and validate all metadata
   - Present in a JSON-compatible format for the MCP resource

## Implementation Approach

### Bash Script Development

1. **Create Scriptable API Layer:**
   - Develop a set of bash scripts in `scripts/` directory
   - Each script should be independently testable
   - Scripts should have consistent parameter handling and output formatting
   - Use JSON output format where appropriate for easier parsing

2. **Environment Discovery Script:**
   - Create a core script `ai-environment-discover.sh` that:
     - Finds all Docker containers with AI Sandbox labels
     - Groups them by repository
     - Extracts branch and state information
     - Formats output as structured JSON
     - This script will be the foundation for the `sandbox-environments` resource

3. **Credentials Status Script:**
   - Create a script `ai-credentials-status.sh` that:
     - Checks for running credential servers
     - Validates credential health and expiration
     - Reports credential status in a structured format

4. **Script Documentation:**
   - All scripts should include usage information (accessible via `--help`)
   - Include examples and parameter descriptions
   - Document expected output format

### MCP Server Integration

For each functional area:
1. **Create Resource Handlers:**
   - For bash script-based resources:
     - Wrap the corresponding status/info bash scripts
     - Format the output for AI consumption
   - For direct MCP implementation (like installation check):
     - Implement using Node.js native functionality
     - Check installation status using command availability in PATH

2. **Create Tool Handlers:**
   - Wrap the corresponding action bash scripts
   - Validate parameters before passing to scripts
   - Format script output for AI-friendly responses
   - Handle script errors gracefully

## Security Considerations

All implementations will:
- Validate inputs to prevent command injection
- Only expose intended functionality
- Handle credentials securely
- Follow the principle of least privilege

## Implementation Phases

1. **Phase 1: Script Foundation**
   - Create core bash scripts for all functionality
   - Implement Docker metadata extensions
   - Test scripts independently

2. **Phase 2: Documentation and Installation**
   - Implement README.md reader script
   - Create MCP resource wrapper for documentation
   - Implement installation check functionality directly in MCP server
   - Create installation validation utility for reuse across MCP server

3. **Phase 3: Credentials Management**
   - Implement credential status script
   - Implement credential management scripts (start, list, stop, test)
   - Create MCP wrappers

4. **Phase 4: Environment Management**
   - Implement environment discovery script
   - Implement environment management scripts (create, stop, clean, list)
   - Create MCP wrappers

5. **Phase 5: Testing and Integration**
   - Comprehensive testing of all components
   - Integration with Claude Code for end-to-end testing