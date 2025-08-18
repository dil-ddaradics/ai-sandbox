#!/usr/bin/env node

/**
 * AI Sandbox MCP Server CLI
 * 
 * This is a simple executable wrapper for the MCP server. It imports and runs
 * the main entry point from dist/index.js.
 * 
 * IMPORTANT: For MCP protocol compatibility, this file must NOT write anything to stdout
 * as it would break the JSON-RPC communication.
 */

// Force stderr usage for all console output
console.log = console.error;

// Early startup log to stderr only
console.error(`[${new Date().toISOString()}] AI Sandbox MCP Server CLI starting...`);

try {
  // Import and run the main module which will start the server
  import('../dist/index.js')
    .catch(err => {
      console.error('Error importing MCP server:', err);
      process.exit(1);
    });
} catch (err) {
  console.error('Error starting MCP server CLI:', err);
  process.exit(1);
}

// No additional code needed as our index.js handles everything:
// - Creates the MCP server
// - Registers all tools and resources
// - Connects with stdio transport
// - Handles errors and process signals