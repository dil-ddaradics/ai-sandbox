# AI Sandbox MCP Server

A Model Context Protocol (MCP) server for AI Sandbox that provides custom tools and resources for AI assistants. This MCP server integrates with Claude Code to enhance AI capabilities with domain-specific tools.

## Features

- **Greeting Resources**: Personalized greeting messages
- **Calculator Tools**: Basic math operations (add, subtract, multiply, divide)
- **Echo Tool**: Simple tool for testing

## Prerequisites

- Node.js v18.x or higher
- npm or yarn

## Installation

### Using npx (No Installation Required)

```bash
npx @dil-ddaradics/ai-sandbox-mcp-server
```

This runs the MCP server directly without installing it. This is the recommended method for most users.

### Global Installation

```bash
npm install -g @dil-ddaradics/ai-sandbox-mcp-server
```

After installing globally, you can run it using:

```bash
ai-sandbox-mcp
```

### Local Installation

```bash
npm install @dil-ddaradics/ai-sandbox-mcp-server
```

### Local Development Installation

1. Clone the AI Sandbox repository:

```bash
git clone https://github.com/dil-ddaradics/ai-sandbox.git
cd ai-sandbox/mcp-server
```

2. Install dependencies:

```bash
npm install
```

## Usage

### Running the Server

To run the MCP server locally:

```bash
npm start
```

This will start the server using stdio transport, which allows it to communicate with Claude Code.

### Connecting to Claude Code

To use the MCP server with Claude Code:

```bash
# Using npx (recommended, no installation required)
claude mcp add --transport stdio ai-sandbox-mcp -- 'npx @dil-ddaradics/ai-sandbox-mcp-server'

# If installed globally
claude mcp add --transport stdio ai-sandbox-mcp -- 'ai-sandbox-mcp'

# If installed locally from npm
claude mcp add --transport stdio ai-sandbox-mcp -- 'node /path/to/node_modules/@dil-ddaradics/ai-sandbox-mcp-server/dist/index.js'

# If running from local development installation
claude mcp add --transport stdio ai-sandbox-mcp -- 'npm start --prefix /path/to/ai-sandbox/mcp-server'
```

Replace `/path/to/...` with the actual paths on your system if needed.

## Testing the Server

### Using Resources

Once connected to Claude Code, you can test the greeting resource:

```
Use the ai-sandbox-mcp server to get a greeting with my name.
```

### Using Tools

To test the calculator tools:

```
Use the ai-sandbox-mcp server to add 25 and 17.
```

```
Use the ai-sandbox-mcp server to divide 100 by 5.
```

To test the echo tool:

```
Use the ai-sandbox-mcp server to echo "Hello, MCP!".
```

## Development

### Project Structure

```
mcp-server/
├── src/
│   ├── index.ts        # Main entry point
│   ├── resources/      # Resource implementations
│   │   └── greeting.ts # Greeting resource
│   └── tools/          # Tool implementations
│       ├── calculator.ts # Calculator tools
│       └── echo.ts      # Echo tool for testing
├── dist/              # Compiled JavaScript output
├── tsconfig.json      # TypeScript configuration
├── package.json       # npm configuration and scripts
└── README.md          # Documentation
```

### Building

To build the TypeScript code:

```bash
npm run build
```

This will compile the TypeScript code into JavaScript in the `dist` directory.

### Adding New Tools or Resources

To extend the MCP server with new capabilities:

1. Create a new file in `src/tools/` or `src/resources/`
2. Implement your tool or resource following the existing patterns
3. Import and register your new components in `src/index.ts`
4. Build and test your changes

## Publishing Updates

To publish a new version to npm:

1. Update the version in package.json:
   ```bash
   npm version patch  # For bug fixes
   npm version minor  # For new features
   npm version major  # For breaking changes
   ```

2. Build and publish:
   ```bash
   npm run publishToNpm
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.