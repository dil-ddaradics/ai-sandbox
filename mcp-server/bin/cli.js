#!/usr/bin/env node

/**
 * MCP Server CLI
 * 
 * This script provides a command-line interface for the AI Sandbox MCP Server.
 * When installed globally, it allows running the MCP server from anywhere.
 */

import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

// Handle imports in ESM context
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Import our modules
async function importModules() {
  try {
    // Dynamically import our modules
    const { registerGreetingResource } = await import('../dist/resources/greeting.js');
    const { registerCalculatorTools } = await import('../dist/tools/calculator.js');
    const { registerEchoTool } = await import('../dist/tools/echo.js');
    
    return {
      registerGreetingResource,
      registerCalculatorTools,
      registerEchoTool
    };
  } catch (error) {
    console.error('Error importing modules:', error);
    process.exit(1);
  }
}

// Main function
async function main() {
  try {
    console.error("Starting AI Sandbox MCP Server...");
    
    // Create server instance
    const server = new McpServer({
      name: "ai-sandbox-mcp",
      version: "0.1.0",
      description: "Model Context Protocol server for AI Sandbox"
    });
    
    // Import and register resources and tools
    const modules = await importModules();
    modules.registerGreetingResource(server);
    modules.registerCalculatorTools(server);
    modules.registerEchoTool(server);
    
    // Connect with stdio transport
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