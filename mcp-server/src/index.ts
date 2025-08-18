import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { registerGreetingResource } from "./resources/greeting.js";
import { registerCalculatorTools } from "./tools/calculator.js";
import { registerEchoTool } from "./tools/echo.js";
import logger from "./utils/logger.js";

// CRITICAL: Protect stdout from accidental writes that would break MCP protocol
// Save original console.log function
const originalConsoleLog = console.log;

// Override console.log to use stderr instead (will show in terminal but not interfere with JSON-RPC)
console.log = function(...args) {
  console.error(...args);
};

// Log the startup with timestamp
console.error(`[${new Date().toISOString()}] MCP Server initializing - STDOUT protected`);

// Add early protection for stdout
process.stdout.on('error', (err) => {
  console.error('Stdout error:', err);
});


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
    // Log early startup with PID and environment info
    logger.info(`MCP Server starting - PID: ${process.pid}, Node: ${process.version}`);
    logger.info(`Working directory: ${process.cwd()}`);
    logger.info(`Command: ${process.argv.join(' ')}`);
    
    // Create server instance
    const server = new McpServer({
      name: "ai-sandbox-mcp",
      version: "0.0.2", // Match the version in package.json
      description: "Model Context Protocol server for AI Sandbox"
    });
    logger.info("MCP Server instance created successfully");

    // Register resources and tools
    logger.info("Registering MCP resources and tools...");
    registerGreetingResource(server);
    registerCalculatorTools(server);
    registerEchoTool(server);
    logger.info("Resources and tools registered successfully");
    
    // Start the server with stdio transport
    logger.info("Creating StdioServerTransport...");
    const transport = new StdioServerTransport();
    logger.info("Transport created successfully");
    
    // Log connection attempt
    logger.info("Connecting to transport...");
    console.error("[MCP] Attempting to connect to transport...");
    
    // Connect to the transport
    await server.connect(transport);
    
    logger.info("MCP Server started successfully and ready to receive requests");
    logger.info("Log file location: /tmp/ai-sandbox/mcp-server.log");
    logger.info("Use with Claude Code: claude mcp add --transport stdio ai-sandbox-mcp -- 'node /path/to/dist/index.js'");
    
    // Log successful startup to stderr as well
    console.error("[MCP] Server started successfully and ready to receive requests");
  } catch (error) {
    logger.error("Error starting MCP server:", error);
    console.error("[FATAL] Error starting MCP server:", error);
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
  console.error('[FATAL] Uncaught exception:', error);
  process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled promise rejection:', reason);
  console.error('[FATAL] Unhandled promise rejection:', reason);
  // Don't exit the process to allow potential recovery
});

// Add warning handler
process.on('warning', (warning) => {
  logger.warn('Process warning:', warning.name, warning.message);
  console.error('[WARNING]', warning.name, warning.message);
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