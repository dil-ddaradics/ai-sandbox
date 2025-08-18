import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerGreetingResource } from "./resources/greeting.js";
import { registerCalculatorTools } from "./tools/calculator.js";
import { registerEchoTool } from "./tools/echo.js";

/**
 * Main entry point for the AI Sandbox MCP Server
 * 
 * This server provides:
 * - Greeting resources for personalized messages
 * - Calculator tools for basic math operations
 * - Echo tool for testing
 */
async function main() {
  try {
    // Create server instance
    const server = new McpServer({
      name: "ai-sandbox-mcp",
      version: "0.0.2", // Match the version in package.json
      description: "Model Context Protocol server for AI Sandbox"
    });

    // Register resources and tools
    console.error("Registering MCP resources and tools...");
    registerGreetingResource(server);
    registerCalculatorTools(server);
    registerEchoTool(server);
    
    // Start the server with stdio transport
    console.error("Starting AI Sandbox MCP Server...");
    const transport = new StdioServerTransport();
    await server.connect(transport);
    
    console.error("MCP Server started successfully and ready to receive requests");
    console.error("Use with Claude Code: claude mcp add --transport stdio ai-sandbox-mcp -- 'node /path/to/dist/index.js'");
  } catch (error) {
    console.error("Error starting MCP server:", error);
    process.exit(1);
  }
}

// Handle process signals for graceful shutdown
process.on('SIGINT', () => {
  console.error('Server shutting down (SIGINT)...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.error('Server shutting down (SIGTERM)...');
  process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught exception:', error);
  process.exit(1);
});

// Start the server
main().catch(err => {
  console.error("Unhandled error:", err);
  process.exit(1);
});