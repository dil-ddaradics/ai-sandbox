import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

/**
 * Register an echo tool for testing
 * @param server The MCP server instance
 */
export function registerEchoTool(server: McpServer): void {
  server.registerTool(
    "echo",
    {
      title: "Echo Tool",
      description: "Echoes back the input message (useful for testing)",
      inputSchema: {
        message: z.string().describe("Message to echo back")
      }
    },
    async ({ message }) => ({
      content: [{ 
        type: "text", 
        text: `Echo: ${message}` 
      }]
    })
  );
}