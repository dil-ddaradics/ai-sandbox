# MCP Server Troubleshooting Guide

This guide helps you troubleshoot issues with the AI Sandbox MCP server.

## Common Issues and Solutions

### 1. "Failed to connect" Error in Claude Code

If you see "Failed to connect" when trying to use the MCP server with Claude Code, try these solutions:

#### Check MCP Server Logs

```bash
# View the log file
cat /tmp/ai-sandbox/mcp-server.log

# Follow logs in real-time
tail -f /tmp/ai-sandbox/mcp-server.log
```

#### Test the Server Directly

Run the test script to verify the server works correctly:

```bash
node scripts/test-mcp-connection.js
```

This should show successful communication with the server and log file creation.

#### Update Claude Code Configuration

Remove and re-add the MCP server with the correct configuration:

```bash
# Remove existing configuration
claude mcp remove ai-sandbox-mcp -s local

# Add with absolute paths (recommended)
claude mcp add --transport stdio ai-sandbox-mcp -- '/absolute/path/to/node /absolute/path/to/dist/index.js'
```

### 2. STDOUT Protection

MCP servers must not write anything to stdout except JSON-RPC messages. Common issues:

- `console.log()` statements in the code break the protocol
- Third-party libraries writing to stdout
- Unexpected error outputs going to stdout

Our implementation now redirects all console.log calls to stderr to avoid breaking the protocol.

### 3. Permission Issues

If the log file isn't being created:

```bash
# Make sure the directory exists
mkdir -p /tmp/ai-sandbox

# Test write permissions
touch /tmp/ai-sandbox/test.log
```

## Common MCP Protocol Errors

1. **Method not found**: The requested method doesn't exist or isn't registered correctly
2. **Invalid params**: The parameters sent don't match what the method expects
3. **Parse error**: Invalid JSON sent to the server
4. **Invalid request**: Malformed request (missing required fields)

## Debugging Tips

1. Always check the log file first
2. Use the test script to verify server functionality
3. Run with absolute paths to avoid PATH issues
4. Make sure no `console.log()` calls exist in the code

## Further Assistance

If you're still having trouble, check the MCP protocol documentation or report an issue.