#!/usr/bin/env node

/**
 * Test MCP Server Connection
 * 
 * This script tests the MCP server by sending a simple JSON-RPC request
 * and waiting for a response. It helps verify that the MCP server is working
 * correctly with the stdin/stdout transport.
 * 
 * Usage:
 *   node test-mcp-connection.js
 * 
 * The script will spawn the MCP server process and send a test request.
 */

import { spawn } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

// Get __dirname equivalent in ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const SERVER_SCRIPT = path.resolve(__dirname, '../dist/index.js');
const NODE_PATH = process.execPath;
const LOG_FILE = '/tmp/ai-sandbox/mcp-server.log';

// Clear log file to start fresh
try {
  if (fs.existsSync('/tmp/ai-sandbox')) {
    fs.writeFileSync(LOG_FILE, '', { flag: 'w' });
    console.log(`Cleared log file: ${LOG_FILE}`);
  } else {
    fs.mkdirSync('/tmp/ai-sandbox', { recursive: true });
    console.log(`Created directory: /tmp/ai-sandbox`);
  }
} catch (err) {
  console.error(`Error preparing log file: ${err.message}`);
}

console.log(`Starting MCP server: ${NODE_PATH} ${SERVER_SCRIPT}`);

// Start the server process
const serverProcess = spawn(NODE_PATH, [SERVER_SCRIPT], {
  stdio: ['pipe', 'pipe', 'inherit'] // We need to pipe stdin/stdout but let stderr pass through
});

// Handle process events
serverProcess.on('error', (err) => {
  console.error(`Failed to start MCP server: ${err.message}`);
  process.exit(1);
});

// Exit handler
process.on('exit', () => {
  if (!serverProcess.killed) {
    serverProcess.kill();
    console.log('MCP server process terminated');
  }
});

// Handle keyboard interrupt
process.on('SIGINT', () => {
  console.log('Received SIGINT, terminating...');
  serverProcess.kill();
  process.exit(0);
});

// Listen for server output
serverProcess.stdout.on('data', (data) => {
  const output = data.toString().trim();
  console.log(`[SERVER OUT] ${output}`);
  
  try {
    // Try to parse as JSON
    const response = JSON.parse(output);
    console.log('Received valid JSON response:');
    console.log(JSON.stringify(response, null, 2));
  } catch (err) {
    // Not valid JSON, which is a protocol violation
    console.error('Received non-JSON output from server, this breaks the MCP protocol!');
  }
});

// Wait a moment for the server to initialize
setTimeout(() => {
  // Send a test request - check if server is alive
  const pingRequest = {
    jsonrpc: '2.0',
    method: 'ping',
    id: 1
  };
  
  console.log('Sending ping request:');
  console.log(JSON.stringify(pingRequest, null, 2));
  
  serverProcess.stdin.write(JSON.stringify(pingRequest) + '\n');
  
  // Wait a bit and then send a tools/list request
  setTimeout(() => {
    const listRequest = {
      jsonrpc: '2.0',
      method: 'tools/list',
      params: {},
      id: 2
    };
    
    console.log('Sending tools/list request:');
    console.log(JSON.stringify(listRequest, null, 2));
    
    serverProcess.stdin.write(JSON.stringify(listRequest) + '\n');
    
    // Check log file after 2 seconds
    setTimeout(() => {
      try {
        if (fs.existsSync(LOG_FILE)) {
          const logContent = fs.readFileSync(LOG_FILE, 'utf8');
          console.log('\nLog file content:');
          console.log(logContent);
        } else {
          console.error(`Log file not found: ${LOG_FILE}`);
        }
        
        // Give time to see the output, then exit
        setTimeout(() => {
          console.log('Test complete, terminating server');
          serverProcess.kill();
          process.exit(0);
        }, 1000);
      } catch (err) {
        console.error(`Error reading log file: ${err.message}`);
      }
    }, 2000);
  }, 1000);
}, 1000);