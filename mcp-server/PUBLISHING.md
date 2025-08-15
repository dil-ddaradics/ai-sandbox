# Publishing Guide for AI Sandbox MCP Server

This document provides instructions for publishing the AI Sandbox MCP Server to GitHub Packages, where it can be installed as a global npm package.

## Prerequisites

- GitHub account with write access to the repository
- Personal Access Token (PAT) with `read:packages`, `write:packages`, and `delete:packages` permissions
- Node.js and npm installed locally

## Setup for Publishing

### 1. Configure Authentication

Create or edit your local `.npmrc` file to authenticate with GitHub Packages:

```bash
# Create .npmrc in your home directory if it doesn't exist
touch ~/.npmrc

# Add these lines to ~/.npmrc
@dil-ddaradics:registry=https://npm.pkg.github.com/
//npm.pkg.github.com/:_authToken=YOUR_GITHUB_TOKEN
```

Replace `YOUR_GITHUB_TOKEN` with your GitHub Personal Access Token (PAT).

### 2. Login to GitHub Packages

Verify you are logged in to GitHub Packages:

```bash
npm whoami --registry=https://npm.pkg.github.com/
```

If you're not logged in, you can log in with:

```bash
npm login --registry=https://npm.pkg.github.com/ --scope=@dil-ddaradics
```

## Publishing Process

### 1. Prepare the Package

Ensure the code is ready for publishing:

```bash
# Navigate to the package directory
cd /path/to/ai-sandbox/mcp-server

# Install dependencies
npm install

# Build the package
npm run build
```

### 2. Update Version Number

Increment the version number based on semantic versioning:

```bash
# For patch updates (bug fixes)
npm version patch

# For minor updates (new features, backwards compatible)
npm version minor

# For major updates (breaking changes)
npm version major
```

### 3. Publish the Package

Publish the package to GitHub Packages:

```bash
npm publish
```

This will run the build process and then publish the package to GitHub Packages.

### 4. Verify Publication

Check that the package was published successfully:

1. Visit your GitHub repository
2. Navigate to the "Packages" section
3. Verify that the new version appears

## Installation After Publishing

To install the published package globally:

```bash
npm install -g @dil-ddaradics/ai-sandbox-mcp-server
```

## Troubleshooting

### Common Issues

1. **Authentication Error**
   - Make sure your PAT has the necessary permissions
   - Verify the token in your `.npmrc` file is correct and not expired

2. **Scope Error**
   - Ensure the package name in `package.json` is correctly scoped with `@dil-ddaradics/`

3. **Version Conflict**
   - Cannot publish a version that already exists. Make sure to increment the version number before publishing

## Additional Resources

- [GitHub Packages Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-npm-registry)
- [npm Publishing Documentation](https://docs.npmjs.com/cli/v8/commands/npm-publish)