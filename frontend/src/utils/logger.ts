/**
 * Tessera Frontend Logger
 * Modern structured logging for React/TypeScript with colors and organization
 */

import log from 'loglevel';
import prefix from 'loglevel-plugin-prefix';

// Configure loglevel with prefixes and colors
prefix.reg(log);

// Color scheme for different log levels
const colors = {
  TRACE: '#6B7280', // Gray
  DEBUG: '#3B82F6', // Blue
  INFO: '#10B981',  // Green
  WARN: '#F59E0B',  // Yellow
  ERROR: '#EF4444', // Red
};

// Emoji indicators for different contexts
const emojis = {
  api: '🌐',
  component: '⚛️',
  store: '📦',
  navigation: '🧭',
  user: '👤',
  performance: '📊',
  error: '❌',
  success: '✅',
  warning: '⚠️',
  processing: '⚙️',
  websocket: '🔌',
  cache: '💾',
  brain: '🧠',
  search: '🔍',
  graph: '🕸️',
  learning: '📚',
  notebook: '📝',
  dashboard: '📈',
  system: '🖥️',
};

// Configure prefix format
prefix.apply(log, {
  format(level, name, timestamp) {
    const color = colors[level.toUpperCase() as keyof typeof colors];
    const time = new Date(timestamp).toLocaleTimeString();
    
    return `%c[${time}] ${level.toUpperCase()} ${name || 'APP'}`;
  },
  levelFormatter(level) {
    return level.toUpperCase();
  },
  nameFormatter(name) {
    return name || 'APP';
  },
  timestampFormatter(date) {
    return date.toISOString();
  },
});

// Set default log level based on environment
if (import.meta.env.DEV) {
  log.setLevel('DEBUG');
} else {
  log.setLevel('INFO');
}

export interface LogContext {
  [key: string]: any;
}

export class TesseraLogger {
  private name: string;
  private logger: log.Logger;

  constructor(name: string) {
    this.name = name;
    this.logger = log.getLogger(name);
  }

  // Core logging methods with context support
  debug(message: string, context?: LogContext) {
    this.logger.debug(this.formatMessage(message, context));
  }

  info(message: string, context?: LogContext) {
    this.logger.info(this.formatMessage(message, context));
  }

  warn(message: string, context?: LogContext) {
    this.logger.warn(this.formatMessage(message, context));
  }

  error(message: string, error?: Error, context?: LogContext) {
    const errorContext = error ? { 
      error: error.message, 
      stack: error.stack,
      ...context 
    } : context;
    
    this.logger.error(this.formatMessage(message, errorContext));
    
    // Also log to console.error for better stack traces in dev tools
    if (error && import.meta.env.DEV) {
      console.error(error);
    }
  }

  // Specialized logging methods with emojis and context
  logApiRequest(method: string, url: string, context?: LogContext) {
    this.info(`${emojis.api} ${method} ${url}`, {
      type: 'api_request',
      method,
      url,
      ...context
    });
  }

  logApiResponse(method: string, url: string, status: number, duration?: number, context?: LogContext) {
    const emoji = status < 300 ? emojis.success : status < 400 ? emojis.warning : emojis.error;
    const level = status < 300 ? 'info' : status < 400 ? 'warn' : 'error';
    
    const message = duration 
      ? `${emoji} ${method} ${url} → ${status} (${duration}ms)`
      : `${emoji} ${method} ${url} → ${status}`;

    this[level](message, {
      type: 'api_response',
      method,
      url,
      status,
      duration,
      ...context
    });
  }

  logComponentMount(componentName: string, context?: LogContext) {
    this.debug(`${emojis.component} Mounted ${componentName}`, {
      type: 'component_lifecycle',
      component: componentName,
      action: 'mount',
      ...context
    });
  }

  logComponentUnmount(componentName: string, context?: LogContext) {
    this.debug(`${emojis.component} Unmounted ${componentName}`, {
      type: 'component_lifecycle',
      component: componentName,
      action: 'unmount',
      ...context
    });
  }

  logUserAction(action: string, context?: LogContext) {
    this.info(`${emojis.user} User action: ${action}`, {
      type: 'user_action',
      action,
      ...context
    });
  }

  logNavigation(from: string, to: string, context?: LogContext) {
    this.info(`${emojis.navigation} Navigation: ${from} → ${to}`, {
      type: 'navigation',
      from,
      to,
      ...context
    });
  }

  logStoreAction(store: string, action: string, context?: LogContext) {
    this.debug(`${emojis.store} Store ${store}: ${action}`, {
      type: 'store_action',
      store,
      action,
      ...context
    });
  }

  logPerformance(metric: string, value: number, unit: string = 'ms', context?: LogContext) {
    this.info(`${emojis.performance} ${metric}: ${value}${unit}`, {
      type: 'performance',
      metric,
      value,
      unit,
      ...context
    });
  }

  logProcessingStart(task: string, context?: LogContext) {
    this.info(`${emojis.processing} Starting: ${task}`, {
      type: 'processing',
      task,
      status: 'started',
      timestamp: Date.now(),
      ...context
    });
  }

  logProcessingComplete(task: string, duration?: number, context?: LogContext) {
    const message = duration 
      ? `${emojis.success} Completed: ${task} (${duration}ms)`
      : `${emojis.success} Completed: ${task}`;

    this.info(message, {
      type: 'processing',
      task,
      status: 'completed',
      duration,
      ...context
    });
  }

  logWebSocketEvent(event: string, context?: LogContext) {
    this.debug(`${emojis.websocket} WebSocket: ${event}`, {
      type: 'websocket',
      event,
      ...context
    });
  }

  logCacheOperation(operation: 'hit' | 'miss' | 'set' | 'clear', key: string, context?: LogContext) {
    const emoji = operation === 'hit' ? '🎯' : operation === 'miss' ? '❌' : emojis.cache;
    this.debug(`${emoji} Cache ${operation}: ${key}`, {
      type: 'cache',
      operation,
      key,
      ...context
    });
  }

  // Domain-specific logging methods
  logBrainVisualization(action: string, context?: LogContext) {
    this.info(`${emojis.brain} Brain: ${action}`, {
      type: 'brain_visualization',
      action,
      ...context
    });
  }

  logSearchQuery(query: string, results?: number, context?: LogContext) {
    const message = results !== undefined 
      ? `${emojis.search} Search: "${query}" (${results} results)`
      : `${emojis.search} Search: "${query}"`;

    this.info(message, {
      type: 'search',
      query,
      results,
      ...context
    });
  }

  logKnowledgeGraph(action: string, context?: LogContext) {
    this.info(`${emojis.graph} Knowledge Graph: ${action}`, {
      type: 'knowledge_graph',
      action,
      ...context
    });
  }

  logLearningProgress(subject: string, progress: number, context?: LogContext) {
    this.info(`${emojis.learning} Learning progress: ${subject} (${progress}%)`, {
      type: 'learning_progress',
      subject,
      progress,
      ...context
    });
  }

  logNotebookAction(action: string, context?: LogContext) {
    this.info(`${emojis.notebook} Notebook: ${action}`, {
      type: 'notebook',
      action,
      ...context
    });
  }

  logDashboardMetric(metric: string, value: any, context?: LogContext) {
    this.info(`${emojis.dashboard} Dashboard: ${metric} = ${value}`, {
      type: 'dashboard_metric',
      metric,
      value,
      ...context
    });
  }

  // Private helper methods
  private formatMessage(message: string, context?: LogContext): string {
    if (!context || Object.keys(context).length === 0) {
      return message;
    }

    // In development, show full context
    if (import.meta.env.DEV) {
      const contextStr = Object.entries(context)
        .map(([key, value]) => `${key}=${JSON.stringify(value)}`)
        .join(', ');
      return `${message} | ${contextStr}`;
    }

    // In production, show minimal context
    return message;
  }
}

// Global logger instances for different parts of the app
export const appLogger = new TesseraLogger('APP');
export const apiLogger = new TesseraLogger('API');
export const componentLogger = new TesseraLogger('COMPONENT');
export const storeLogger = new TesseraLogger('STORE');
export const brainLogger = new TesseraLogger('BRAIN');
export const searchLogger = new TesseraLogger('SEARCH');
export const graphLogger = new TesseraLogger('GRAPH');
export const learningLogger = new TesseraLogger('LEARNING');
export const notebookLogger = new TesseraLogger('NOTEBOOK');
export const dashboardLogger = new TesseraLogger('DASHBOARD');

// Convenience function to get a logger for any component
export function getLogger(name: string): TesseraLogger {
  return new TesseraLogger(name);
}

// Performance monitoring utilities
export function measurePerformance<T>(
  name: string, 
  fn: () => T, 
  logger: TesseraLogger = appLogger
): T {
  const start = performance.now();
  logger.logProcessingStart(name);
  
  try {
    const result = fn();
    const duration = performance.now() - start;
    logger.logProcessingComplete(name, duration);
    return result;
  } catch (error) {
    const duration = performance.now() - start;
    logger.error(`Failed: ${name} (${duration}ms)`, error as Error);
    throw error;
  }
}

export async function measureAsyncPerformance<T>(
  name: string, 
  fn: () => Promise<T>, 
  logger: TesseraLogger = appLogger
): Promise<T> {
  const start = performance.now();
  logger.logProcessingStart(name);
  
  try {
    const result = await fn();
    const duration = performance.now() - start;
    logger.logProcessingComplete(name, duration);
    return result;
  } catch (error) {
    const duration = performance.now() - start;
    logger.error(`Failed: ${name} (${duration}ms)`, error as Error);
    throw error;
  }
}

// Error boundary logging
export function logErrorBoundary(error: Error, errorInfo: any, componentStack?: string) {
  appLogger.error('React Error Boundary caught an error', error, {
    componentStack,
    errorInfo: JSON.stringify(errorInfo)
  });
}

// Global error handler
window.addEventListener('error', (event) => {
  appLogger.error('Unhandled JavaScript error', event.error, {
    filename: event.filename,
    lineno: event.lineno,
    colno: event.colno
  });
});

window.addEventListener('unhandledrejection', (event) => {
  appLogger.error('Unhandled Promise rejection', new Error(event.reason), {
    reason: event.reason
  });
});

export default TesseraLogger;
