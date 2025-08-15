# AI Sandbox MCP Server

A Model Context Protocol (MCP) server for AI Sandbox that provides custom tools and resources for AI assistants.

## Features

- **Greeting Resources**: Personalized greeting messages
- **Calculator Tools**: Basic math operations (add, subtract, multiply, divide)
- **Echo Tool**: Simple tool for testing

## Prerequisites

- Node.js v18.x or higher
- npm or yarn

## Installation

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

To run the MCP server:

```bash
npm start
```

This will start the server using stdio transport, which allows it to be connected to Claude Code.

### Connecting to Claude Code

To use the MCP server with Claude Code:

```bash
claude mcp add --transport stdio ai-sandbox-mcp -- 'npm start --prefix /path/to/ai-sandbox/mcp-server'
```

Replace `/path/to/ai-sandbox/mcp-server` with the actual path to the mcp-server directory.

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
│   ├── index.ts        # Entry point
│   ├── resources/      # Resource implementations
│   │   └── greeting.ts # Greeting resource
│   └── tools/          # Tool implementations
│       ├── calculator.ts # Calculator tools
│       └── echo.ts      # Echo tool
├── dist/              # Compiled JavaScript
├── tsconfig.json      # TypeScript configuration
├── package.json       # npm configuration
└── README.md          # This documentation
```

### Building

To build the TypeScript code:

```bash
npm run build
```

This will compile the TypeScript code into JavaScript in the `dist` directory.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.