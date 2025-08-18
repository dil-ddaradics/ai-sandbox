import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerGreetingResource } from "./resources/greeting.js";
import { registerCalculatorTools } from "./tools/calculator.js";
import { registerEchoTool } from "./tools/echo.js";
import logger from "./utils/logger.js";

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
    logger.info("Registering MCP resources and tools...");
    registerGreetingResource(server);
    registerCalculatorTools(server);
    registerEchoTool(server);
    
    // Start the server with stdio transport
    logger.info("Starting AI Sandbox MCP Server...");
    const transport = new StdioServerTransport();
    
    // Log additional server activity
    logger.info("Transport created");
    
    // Connect to the transport
    await server.connect(transport);
    
    logger.info("MCP Server started successfully and ready to receive requests");
    logger.info("Log file location: /tmp/ai-sandbox/mcp-server.log");
    logger.info("Use with Claude Code: claude mcp add --transport stdio ai-sandbox-mcp -- 'node /path/to/dist/index.js'");
  } catch (error) {
    logger.error("Error starting MCP server:", error);
    process.exit(1);
  }
}

// Handle process signals for graceful shutdown
process.on('SIGINT', () => {
  logger.info('Server shutting down (SIGINT)...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  logger.info('Server shutting down (SIGTERM)...');
  process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception:', error);
  process.exit(1);
});

// Log incoming messages (stdin)
process.stdin.on('data', (data) => {
  logger.debug(`Received data of length: ${data.length} bytes`);
});

// Log when stdin ends (which might indicate Claude has disconnected)
process.stdin.on('end', () => {
  logger.info('stdin stream ended - client may have disconnected');
});

// Start the server
main().catch(err => {
  logger.error("Unhandled error:", err);
  process.exit(1);
});