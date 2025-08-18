# Publishing to npm Registry

This document provides instructions for publishing the AI Sandbox MCP Server to the npm registry.

## Prerequisites

- npm account (you should be logged in with `npm login`)
- Repository with latest changes

## Publishing Steps

### 1. Ensure you are logged in to npm

```bash
npm whoami
```

This should display your npm username. If not, log in:

```bash
npm login
```

### 2. Publish to npm

You can publish directly using the script we've added:

```bash
npm run publishToNpm
```

Or use the standard npm publish command:

```bash
npm publish --access public
```

The `--access public` flag is required for scoped packages.

### 3. Verify Publication

After publishing, you can verify that your package is available on the npm registry:

1. Check the npm website: https://www.npmjs.com/package/@dil-ddaradics/ai-sandbox-mcp-server
2. Try to install it globally:

```bash
npm install -g @dil-ddaradics/ai-sandbox-mcp-server
```

## Installing and Using the Package

After publication, users can install your package globally:

```bash
npm install -g @dil-ddaradics/ai-sandbox-mcp-server
```

And then use it with Claude Code:

```bash
claude mcp add --transport stdio ai-sandbox-mcp -- ai-sandbox-mcp
```

## Updating the Package

To update the package in the future:

1. Make your changes to the code
2. Update the version number in package.json (or use `npm version patch/minor/major`)
3. Build and publish again using the steps above