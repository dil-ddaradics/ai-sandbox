import { McpServer, ResourceTemplate } from "@modelcontextprotocol/sdk/server/mcp.js";

/**
 * Register a greeting resource that returns a personalized greeting
 * @param server The MCP server instance
 */
export function registerGreetingResource(server: McpServer): void {
  server.registerResource(
    "greeting",
    new ResourceTemplate("greeting://{name}", { list: undefined }),
    { 
      title: "Greeting Resource",
      description: "Provides a personalized greeting message"
    },
    async (uri, { name }) => ({
      contents: [{
        uri: uri.href,
        text: `Hello, ${name}! Welcome to the AI Sandbox MCP Server.`
      }]
    })
  );

  // Also register a default greeting
  server.registerResource(
    "default-greeting",
    new ResourceTemplate("greeting://default", { list: undefined }),
    { 
      title: "Default Greeting",
      description: "Provides a default greeting message"
    },
    async () => ({
      contents: [{
        uri: "greeting://default",
        text: "Hello! Welcome to the AI Sandbox MCP Server. You can get a personalized greeting by accessing greeting://{your-name}"
      }]
    })
  );
}