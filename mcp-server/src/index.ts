import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerGreetingResource } from "./resources/greeting.js";
import { registerCalculatorTools } from "./tools/calculator.js";
import { registerEchoTool } from "./tools/echo.js";

// Create server instance
const server = new McpServer({
  name: "ai-sandbox-mcp",
  version: "0.1.0",
  description: "Model Context Protocol server for AI Sandbox"
});

// Register resources and tools
registerGreetingResource(server);
registerCalculatorTools(server);
registerEchoTool(server);

// Start the server
async function main() {
  try {
    console.error("Starting AI Sandbox MCP Server...");
    
    const transport = new StdioServerTransport();
    await server.connect(transport);
    
    console.error("MCP Server started successfully");
  } catch (error) {
    console.error("Error starting MCP server:", error);
    process.exit(1);
  }
}

// Handle process signals
process.on('SIGINT', () => {
  console.error('Server shutting down...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.error('Server shutting down...');
  process.exit(0);
});

// Start the server
main().catch(err => {
  console.error("Unhandled error:", err);
  process.exit(1);
});