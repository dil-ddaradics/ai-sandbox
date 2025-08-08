# AI Sandbox

A turn-key workflow for spinning up isolated AI development sandboxes for every Git work-tree on your machine.

## Features

- **Per-branch isolation**: Each Git branch gets its own container and work-tree
- **AWS Bedrock integration**: Connect to Claude via AWS Bedrock credentials
- **Minimal footprint**: Alpine-based container with essential dev tools
- **Simple commands**: Easy-to-use scripts for the entire workflow
- **Resource control**: Limit CPU and memory usage as needed
- **Easy installation**: Install in any repository with a single command

## Prerequisites

- **macOS** (tested on Ventura & Sonoma)
- **Homebrew packages**:
  ```bash
  brew install colima docker aws-vault
  colima start --cpu 4 --memory 8
  ```
- **Optional packages**:
  ```bash
  brew install direnv   # For automatic PATH integration
  ```
- A valid **AWS SSO profile** in `~/.aws/config` (e.g. `[profile dev-sso]`)

## Installation

```bash
# Clone this repository
git clone https://github.com/dil-ddaradics/ai-sandbox.git

# Install into your project
./ai-sandbox/install.sh ~/path/to/your/repo
```

### Path Integration

AI Sandbox supports two ways to access the `cc-*` commands from anywhere in your repository:

1. **With direnv** (recommended): If you have [direnv](https://direnv.net/) installed, the installation script will automatically configure `.envrc` to add the scripts to your PATH when you navigate to your repository.

2. **Without direnv**: You'll need to either:
   - Run commands from your repository root
   - Add the scripts directory to your PATH manually: 
     ```bash
     export PATH="$PATH:/path/to/your/repo/.cc/scripts"
     ```

## Usage

```bash
# Credential Management
cc-awsvault dev-sso        # Start credential server (run once)
cc-list-creds              # List running credential servers
cc-awsvault-stop           # Stop credential server
cc-test-creds              # Test credential handling in a container

# Container Management
cc-up                      # Spin up container + work-tree for current branch
cc-up feature/other        # Or directly specify a branch (will create if needed)
cc-chat                    # Open Claude chat interface
cc-stop                    # Stop the container when done for the day
cc-clean                   # Clean up the work-tree and container
cc-clean --all             # Clean up and also stop credential server
```

## Configuration

You can override default settings by creating a `.cc/.ccenv` file in your repository:

```bash
# Claude / Bedrock
CLAUDE_CODE_USE_BEDROCK=1
ANTHROPIC_MODEL=us.anthropic.claude-3-sonnet-20250219-v1:0

# Work-tree parking lot
WT_ROOT=$HOME/worktrees

# Docker resource hints
CPU_LIMIT=4
MEM_LIMIT=8g
```

## How It Works

AI Sandbox creates an isolated development environment for each Git branch by:

1. **Setting up AWS authentication**: Runs a credential server once that stays available across terminal sessions
2. **Creating branch workspaces**: Each branch gets its own Git worktree in a separate directory
3. **Running isolated containers**: Spins up Docker containers that mount your branch-specific code
4. **Connecting to Claude**: Uses AWS Bedrock to access Claude inside your container

When you run `cc-awsvault`, it starts an AWS credential server and saves the connection URL. This URL persists between terminal sessions, so you only need to run it once per machine reboot. The containers have a dynamic credential system that monitors for credential URL changes, so even if the credential server restarts with a different URL, your containers will automatically reconnect without needing to be restarted. When you run `cc-up`, it creates a separate worktree for your current branch and launches a container with that code mounted inside.

### Credential Handling Flow

```mermaid
flowchart TB
    subgraph Host Machine
        aws["aws-vault\nCredential Server"]
        url["~/.cc/awsvault_url\nStored URL"]
        cc-awsvault["cc-awsvault\nScript"]
    end
    
    subgraph Docker Container
        monitor["aws-cred-monitor.sh\nBackground Process"]
        refresh["aws-cred-refresh.sh\nRefresh Script"]
        entrypoint["Container Entrypoint"]
        env_file["/tmp/.aws_cred_env\nStores credentials"]
        aws_ops["AWS Operations\n(Claude Code)"]
    end
    
    cc-awsvault -->|"1. Starts server\nand writes URL"| aws
    cc-awsvault -->|"2. Saves URL"| url
    url -->|"3. Mounted as\n/host/.cc/awsvault_url"| monitor
    entrypoint -->|"4. Runs at\ncontainer start"| monitor
    entrypoint -->|"5. Initial\ncredential load"| refresh
    monitor -->|"6. Periodically\nchecks for changes"| url
    monitor -->|"7. Runs refresh\nwhen URL changes"| refresh
    refresh -->|"8. Updates\nenvironment variables"| env_file
    aws_ops -->|"9. Uses credentials\nfor API calls"| aws
    env_file -->|"10. Provides\ncredentials"| aws_ops

    classDef hostNode fill:#e1f5fe,stroke:#0277bd,stroke-width:2px;
    classDef containerNode fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px;
    
    class aws,url,cc-awsvault hostNode;
    class monitor,refresh,entrypoint,env_file,aws_ops containerNode;
```

The diagram illustrates how credentials flow through the system:

1. The `cc-awsvault` script starts the credential server and writes the URL
2. The URL is saved to `~/.cc/awsvault_url` on the host machine
3. This file is mounted into the container as `/host/.cc/awsvault_url`
4. When a container starts, the entrypoint script launches a monitor process
5. The entrypoint also loads credentials initially
6. The monitor process periodically checks if the URL file has changed
7. When changes are detected, the refresh script is called
8. The refresh script updates environment variables and saves them to `/tmp/.aws_cred_env`
9. AWS operations use these environment variables to get fresh credentials
10. The credential server handles token expiration automatically

The result is a clean, isolated environment where you can work with Claude on each branch without interference from other branches or projects.

## Extending

- **Add packages**: Edit `Dockerfile` and rebuild
- **Database sidecar**: Extend `docker-compose.yml`
- **Resource limits**: Set `CPU_LIMIT` / `MEM_LIMIT` in `.ccenv`

## Uninstallation

```bash
# Remove from a specific repo
./uninstall.sh ~/path/to/your/repo
```

The uninstallation process:
1. Stops any running containers associated with the repository
2. Removes the `.cc` directory containing all scripts and configuration
3. Cleans up PATH entries in `.envrc` if direnv is installed
4. Provides guidance for manual PATH cleanup if needed

If you've manually added the scripts to your PATH, you'll need to remove those entries from your shell configuration files.