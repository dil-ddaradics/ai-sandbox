# Claude Dev Sandbox

A turn-key workflow for spinning up isolated Claude Code development sandboxes for every Git work-tree on your machine.

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
- A valid **AWS SSO profile** in `~/.aws/config` (e.g. `[profile dev-sso]`)

## Installation

```bash
# Clone this repository
git clone https://github.com/yourname/claude-dev-sandbox.git

# Install into your project
./claude-dev-sandbox/install.sh ~/path/to/your/repo
```

## Usage

```bash
# Start credential server (run once)
cc-awsvault dev-sso

# Create or switch to a branch
git checkout -b feature/my-feature

# Spin up container + work-tree
cc-up

# Open Claude chat interface
cc-chat

# Stop the container when done for the day
cc-stop

# Clean up the work-tree and container when finished
cc-clean
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

Claude Dev Sandbox creates an isolated development environment for each Git branch by:

1. **Setting up AWS authentication**: Runs a credential server once that stays available across terminal sessions
2. **Creating branch workspaces**: Each branch gets its own Git worktree in a separate directory
3. **Running isolated containers**: Spins up Docker containers that mount your branch-specific code
4. **Connecting to Claude**: Uses AWS Bedrock to access Claude inside your container

When you run `cc-awsvault`, it starts an AWS credential server and saves the connection URL. This URL persists between terminal sessions, so you only need to run it once per machine reboot. When you run `cc-up`, it creates a separate worktree for your current branch and launches a container with that code mounted inside.

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