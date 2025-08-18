#!/usr/bin/env node

/**
 * AI Sandbox MCP Server CLI
 * 
 * This is a simple executable wrapper for the MCP server. It imports and runs
 * the main entry point from dist/index.js.
 */

// Just import the main module which will start the server
import '../dist/index.js';

// No additional code needed as our index.js handles everything:
// - Creates the MCP server
// - Registers all tools and resources
// - Connects with stdio transport
// - Handles errors and process signals