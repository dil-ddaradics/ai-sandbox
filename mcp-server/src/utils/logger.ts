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
    
    // Immediately log creation to stderr (not using this.log to avoid circular reference)
    console.error(`[STARTUP] Logger initializing with log file: ${this.logFilePath}`);
    console.error(`[STARTUP] Log level: ${LogLevel[this.minLevel]}, Console output: ${this.logToConsole}`);
    
    // Ensure the directory exists
    this.ensureLogDirectoryExists();
    
    // Add immediate log entry
    try {
      const timestamp = new Date().toISOString();
      const startupMsg = `[${timestamp}] [INIT] Logger initialized successfully`;
      fs.appendFileSync(this.logFilePath, startupMsg + os.EOL);
      console.error(startupMsg);
    } catch (error) {
      console.error(`[STARTUP] Failed to write initial log entry:`, error);
    }
  }
  
  /**
   * Ensures the log directory exists, creating it if necessary
   */
  private ensureLogDirectoryExists(): void {
    const logDir = path.dirname(this.logFilePath);
    
    if (!fs.existsSync(logDir)) {
      try {
        fs.mkdirSync(logDir, { recursive: true });
        console.error(`Created log directory at ${logDir}`);
      } catch (error) {
        console.error(`Failed to create log directory at ${logDir}:`, error);
      }
    } else {
      console.error(`Log directory exists at ${logDir}`);
    }
    
    // Check if we can write to the directory
    try {
      const testFile = path.join(logDir, '.write-test');
      fs.writeFileSync(testFile, 'test');
      fs.unlinkSync(testFile);
      console.error(`Confirmed write access to log directory ${logDir}`);
    } catch (error) {
      console.error(`WARNING: Cannot write to log directory ${logDir}:`, error);
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
      // FIXED: Use the correct console methods but all via stderr
      // For MCP protocol compliance, we must avoid writing to stdout
      // Always use error stream regardless of log level to avoid breaking MCP protocol
      // Original mapping would be:
      // - ERROR -> console.error
      // - WARN -> console.warn
      // - INFO -> console.info
      // - DEBUG -> console.debug
      // But we'll use stderr for everything instead
      
      // Always use console.error for all log levels to avoid stdout
      console.error(formattedMessage);
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