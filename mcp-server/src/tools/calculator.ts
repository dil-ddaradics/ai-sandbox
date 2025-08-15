import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

/**
 * Register calculator tools for the MCP server
 * @param server The MCP server instance
 */
export function registerCalculatorTools(server: McpServer): void {
  // Addition tool
  server.registerTool(
    "add",
    {
      title: "Addition Tool",
      description: "Add two numbers together",
      inputSchema: {
        a: z.number().describe("First number"),
        b: z.number().describe("Second number")
      }
    },
    async ({ a, b }) => ({
      content: [{ 
        type: "text", 
        text: `${a} + ${b} = ${a + b}` 
      }]
    })
  );

  // Subtraction tool
  server.registerTool(
    "subtract",
    {
      title: "Subtraction Tool",
      description: "Subtract second number from first number",
      inputSchema: {
        a: z.number().describe("First number"),
        b: z.number().describe("Second number")
      }
    },
    async ({ a, b }) => ({
      content: [{ 
        type: "text", 
        text: `${a} - ${b} = ${a - b}` 
      }]
    })
  );

  // Multiplication tool
  server.registerTool(
    "multiply",
    {
      title: "Multiplication Tool",
      description: "Multiply two numbers",
      inputSchema: {
        a: z.number().describe("First number"),
        b: z.number().describe("Second number")
      }
    },
    async ({ a, b }) => ({
      content: [{ 
        type: "text", 
        text: `${a} × ${b} = ${a * b}` 
      }]
    })
  );

  // Division tool
  server.registerTool(
    "divide",
    {
      title: "Division Tool",
      description: "Divide first number by second number",
      inputSchema: {
        a: z.number().describe("First number (dividend)"),
        b: z.number().describe("Second number (divisor)")
      }
    },
    async ({ a, b }) => {
      if (b === 0) {
        return {
          content: [{ 
            type: "text", 
            text: "Error: Division by zero is not allowed." 
          }]
        };
      }
      return {
        content: [{ 
          type: "text", 
          text: `${a} ÷ ${b} = ${a / b}` 
        }]
      };
    }
  );
}