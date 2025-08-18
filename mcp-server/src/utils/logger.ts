/**
 * Simple Logger for AI Sandbox MCP Server
 * 
 * This logger writes to both console and a log file at /tmp/ai-sandbox/mcp-server.log
 */

import fs from 'fs';
import path from 'path';
import os from 'os';

// Log levels in order of verbosity
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3
}

export class Logger {
  private logFilePath: string;
  private minLevel: LogLevel;
  private logToConsole: boolean;
  
  /**
   * Creates a new Logger instance
   * 
   * @param options Configuration options for the logger
   */
  constructor(options: {
    logFilePath?: string;
    minLevel?: LogLevel;
    logToConsole?: boolean;
  } = {}) {
    // Default to /tmp/ai-sandbox/mcp-server.log
    this.logFilePath = options.logFilePath || '/tmp/ai-sandbox/mcp-server.log';
    this.minLevel = options.minLevel !== undefined ? options.minLevel : LogLevel.INFO;
    this.logToConsole = options.logToConsole !== undefined ? options.logToConsole : true;
    
    // Ensure the directory exists
    this.ensureLogDirectoryExists();
  }
  
  /**
   * Ensures the log directory exists, creating it if necessary
   */
  private ensureLogDirectoryExists(): void {
    const logDir = path.dirname(this.logFilePath);
    
    if (!fs.existsSync(logDir)) {
      try {
        fs.mkdirSync(logDir, { recursive: true });
      } catch (error) {
        console.error(`Failed to create log directory at ${logDir}:`, error);
      }
    }
  }
  
  /**
   * Formats a log message with timestamp and level
   */
  private formatLogMessage(level: string, message: string): string {
    const timestamp = new Date().toISOString();
    return `[${timestamp}] [${level}] ${message}`;
  }
  
  /**
   * Writes a message to the log file
   */
  private writeToFile(message: string): void {
    try {
      fs.appendFileSync(this.logFilePath, message + os.EOL);
    } catch (error) {
      // If we can't write to the log file, at least try to log to console
      console.error(`Failed to write to log file:`, error);
    }
  }
  
  /**
   * Logs a message at the specified level
   */
  private log(level: LogLevel, levelName: string, message: string, ...args: any[]): void {
    if (level < this.minLevel) return;
    
    // Format any additional arguments
    let fullMessage = message;
    if (args.length > 0) {
      const formattedArgs = args.map(arg => {
        if (typeof arg === 'object') {
          return JSON.stringify(arg, null, 2);
        }
        return String(arg);
      }).join(' ');
      fullMessage = `${message} ${formattedArgs}`;
    }
    
    const formattedMessage = this.formatLogMessage(levelName, fullMessage);
    
    // Write to log file
    this.writeToFile(formattedMessage);
    
    // Optionally log to console
    if (this.logToConsole) {
      const consoleMethod = level === LogLevel.ERROR ? 'error' :
                           level === LogLevel.WARN ? 'warn' : 
                           level === LogLevel.INFO ? 'error' : 'error';
      
      // Use console.error instead of console.log to ensure it goes to stderr
      // which won't interfere with stdin/stdout used by the MCP protocol
      console[consoleMethod](formattedMessage);
    }
  }
  
  /**
   * Logs a debug message
   */
  debug(message: string, ...args: any[]): void {
    this.log(LogLevel.DEBUG, 'DEBUG', message, ...args);
  }
  
  /**
   * Logs an info message
   */
  info(message: string, ...args: any[]): void {
    this.log(LogLevel.INFO, 'INFO', message, ...args);
  }
  
  /**
   * Logs a warning message
   */
  warn(message: string, ...args: any[]): void {
    this.log(LogLevel.WARN, 'WARN', message, ...args);
  }
  
  /**
   * Logs an error message
   */
  error(message: string, ...args: any[]): void {
    this.log(LogLevel.ERROR, 'ERROR', message, ...args);
  }
  
  /**
   * Returns the path to the log file
   */
  getLogFilePath(): string {
    return this.logFilePath;
  }
}

// Create and export a default logger instance
export const logger = new Logger();

// Export as default for easier imports
export default logger;