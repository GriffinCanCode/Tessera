#!/usr/bin/env python3
"""
Tessera Unified Logging Configuration
Modern structured logging with colors, organization, and strategic placement
"""

import os
import sys
import logging
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime

import structlog
import colorlog
from rich.console import Console
from rich.logging import RichHandler
from rich.traceback import install as install_rich_traceback


class TesseraLogger:
    """
    Centralized logging configuration for all Tessera Python services
    Features:
    - Structured logging with contextual data
    - Beautiful colored console output
    - File logging with rotation
    - Performance metrics
    - Error tracking with stack traces
    """
    
    _instance = None
    _initialized = False
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance
    
    def __init__(self):
        if not self._initialized:
            self.console = Console()
            self._setup_logging()
            TesseraLogger._initialized = True
    
    def _setup_logging(self):
        """Configure structured logging with rich console output"""
        
        # Install rich traceback handler for beautiful error displays
        install_rich_traceback(show_locals=True)
        
        # Create logs directory
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        
        # Configure structlog
        structlog.configure(
            processors=[
                # Add service name and timestamp
                structlog.contextvars.merge_contextvars,
                structlog.processors.add_log_level,
                structlog.processors.TimeStamper(fmt="iso"),
                
                # Add caller info for debugging
                structlog.dev.set_exc_info,
                
                # For console output - use rich formatting
                structlog.dev.ConsoleRenderer(
                    colors=True,
                    exception_formatter=structlog.dev.plain_traceback,
                ),
            ],
            wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
            logger_factory=structlog.stdlib.LoggerFactory(),
            cache_logger_on_first_use=True,
        )
        
        # Configure standard library logging
        logging.basicConfig(
            level=logging.INFO,
            format="%(message)s",
            handlers=[
                RichHandler(
                    console=self.console,
                    show_time=True,
                    show_path=True,
                    markup=True,
                    rich_tracebacks=True,
                ),
                # File handler for persistent logs
                logging.FileHandler(
                    log_dir / f"tessera_{datetime.now().strftime('%Y%m%d')}.log",
                    encoding='utf-8'
                )
            ]
        )
        
        # Set specific log levels for noisy libraries
        logging.getLogger("httpx").setLevel(logging.WARNING)
        logging.getLogger("urllib3").setLevel(logging.WARNING)
        logging.getLogger("aiohttp").setLevel(logging.WARNING)
    
    def get_logger(self, name: str) -> structlog.BoundLogger:
        """Get a configured logger for a service"""
        return structlog.get_logger(name)
    
    def log_service_start(self, service_name: str, port: Optional[int] = None, **context):
        """Log service startup with consistent formatting"""
        logger = self.get_logger("system")
        
        startup_context = {
            "service": service_name,
            "status": "starting",
            "pid": os.getpid(),
            **context
        }
        
        if port:
            startup_context["port"] = port
            
        logger.info(
            f"🚀 Starting {service_name}",
            **startup_context
        )
    
    def log_service_ready(self, service_name: str, **context):
        """Log service ready state"""
        logger = self.get_logger("system")
        logger.info(
            f"✅ {service_name} ready",
            service=service_name,
            status="ready",
            **context
        )
    
    def log_api_request(self, method: str, path: str, **context):
        """Log API requests with consistent format"""
        logger = self.get_logger("api")
        logger.info(
            f"🌐 {method} {path}",
            method=method,
            path=path,
            **context
        )
    
    def log_api_response(self, method: str, path: str, status_code: int, duration_ms: float, **context):
        """Log API responses with performance metrics"""
        logger = self.get_logger("api")
        
        # Color code by status
        if status_code < 300:
            emoji = "✅"
            level = "info"
        elif status_code < 400:
            emoji = "⚠️"
            level = "warning"
        else:
            emoji = "❌"
            level = "error"
            
        log_method = getattr(logger, level)
        log_method(
            f"{emoji} {method} {path} → {status_code} ({duration_ms:.1f}ms)",
            method=method,
            path=path,
            status_code=status_code,
            duration_ms=duration_ms,
            **context
        )
    
    def log_database_operation(self, operation: str, table: str, **context):
        """Log database operations"""
        logger = self.get_logger("database")
        logger.debug(
            f"🗄️ {operation} on {table}",
            operation=operation,
            table=table,
            **context
        )
    
    def log_external_api_call(self, service: str, endpoint: str, **context):
        """Log external API calls"""
        logger = self.get_logger("external")
        logger.info(
            f"🔗 Calling {service}: {endpoint}",
            external_service=service,
            endpoint=endpoint,
            **context
        )
    
    def log_processing_start(self, task: str, **context):
        """Log start of processing tasks"""
        logger = self.get_logger("processing")
        logger.info(
            f"⚙️ Starting: {task}",
            task=task,
            status="started",
            **context
        )
    
    def log_processing_complete(self, task: str, duration_ms: float, **context):
        """Log completion of processing tasks"""
        logger = self.get_logger("processing")
        logger.info(
            f"✅ Completed: {task} ({duration_ms:.1f}ms)",
            task=task,
            status="completed",
            duration_ms=duration_ms,
            **context
        )
    
    def log_error(self, error: Exception, context_msg: str, **context):
        """Log errors with full context and stack traces"""
        logger = self.get_logger("error")
        logger.error(
            f"❌ {context_msg}: {str(error)}",
            error_type=type(error).__name__,
            error_message=str(error),
            **context,
            exc_info=True
        )
    
    def log_performance_metric(self, metric_name: str, value: float, unit: str = "ms", **context):
        """Log performance metrics"""
        logger = self.get_logger("metrics")
        logger.info(
            f"📊 {metric_name}: {value:.2f}{unit}",
            metric=metric_name,
            value=value,
            unit=unit,
            **context
        )


# Global logger instance
tessera_logger = TesseraLogger()

# Convenience functions for easy import
def get_logger(name: str) -> structlog.BoundLogger:
    """Get a configured logger"""
    return tessera_logger.get_logger(name)

def log_service_start(service_name: str, port: Optional[int] = None, **context):
    """Log service startup"""
    return tessera_logger.log_service_start(service_name, port, **context)

def log_service_ready(service_name: str, **context):
    """Log service ready"""
    return tessera_logger.log_service_ready(service_name, **context)

def log_api_request(method: str, path: str, **context):
    """Log API request"""
    return tessera_logger.log_api_request(method, path, **context)

def log_api_response(method: str, path: str, status_code: int, duration_ms: float, **context):
    """Log API response"""
    return tessera_logger.log_api_response(method, path, status_code, duration_ms, **context)

def log_error(error: Exception, context_msg: str, **context):
    """Log error with context"""
    return tessera_logger.log_error(error, context_msg, **context)

def log_processing_start(task: str, **context):
    """Log processing start"""
    return tessera_logger.log_processing_start(task, **context)

def log_processing_complete(task: str, duration_ms: float, **context):
    """Log processing completion"""
    return tessera_logger.log_processing_complete(task, duration_ms, **context)
