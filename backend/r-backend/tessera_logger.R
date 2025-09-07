# Tessera R Logger
# Modern structured logging for R analytics with colors and organization

# Install required packages if not available
required_packages <- c("futile.logger", "jsonlite", "crayon")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

if(length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cran.r-project.org")
}

library(futile.logger)
library(jsonlite)
library(crayon)

# Color scheme for different log levels
log_colors <- list(
  TRACE = crayon::silver,
  DEBUG = crayon::blue,
  INFO = crayon::green,
  WARN = crayon::yellow,
  ERROR = crayon::red,
  FATAL = crayon::magenta
)

# Emoji indicators for different contexts
emojis <- list(
  analysis = "📊",
  graph = "🕸️",
  processing = "⚙️",
  success = "✅",
  warning = "⚠️",
  error = "❌",
  performance = "📈",
  cache = "💾",
  data = "📋",
  network = "🌐",
  algorithm = "🧮",
  visualization = "📉",
  export = "💾",
  import = "📥"
)

# Custom formatter with colors and emojis
tessera_formatter <- function(msg, ...) {
  level <- list(...)$level
  logger_name <- list(...)$logger
  
  # Get color function for level
  color_fn <- log_colors[[level]] %||% crayon::white
  
  # Format timestamp
  timestamp <- format(Sys.time(), "%H:%M:%S")
  
  # Format message with color
  formatted_msg <- sprintf("[%s] %s %s - %s", 
                          timestamp, 
                          level, 
                          logger_name %||% "R", 
                          msg)
  
  return(color_fn(formatted_msg))
}

# Initialize logger with custom formatter
flog.layout(layout.format('[~t] ~l ~n - ~m'))

# Set log level based on environment
if (Sys.getenv("R_LOG_LEVEL") != "") {
  log_level <- toupper(Sys.getenv("R_LOG_LEVEL"))
} else {
  log_level <- "INFO"
}

flog.threshold(log_level)

# TesseraLogger class-like functionality
TesseraLogger <- list(
  
  # Core logging methods
  debug = function(message, context = NULL, logger_name = "R") {
    formatted_msg <- .format_message(message, context)
    flog.debug(formatted_msg, name = logger_name)
  },
  
  info = function(message, context = NULL, logger_name = "R") {
    formatted_msg <- .format_message(message, context)
    flog.info(formatted_msg, name = logger_name)
  },
  
  warn = function(message, context = NULL, logger_name = "R") {
    formatted_msg <- .format_message(message, context)
    flog.warn(formatted_msg, name = logger_name)
  },
  
  error = function(message, error_obj = NULL, context = NULL, logger_name = "R") {
    if (!is.null(error_obj)) {
      context <- c(context, list(error = as.character(error_obj)))
    }
    formatted_msg <- .format_message(message, context)
    flog.error(formatted_msg, name = logger_name)
  },
  
  # Specialized logging methods
  log_analysis_start = function(analysis_type, context = NULL) {
    message <- paste(emojis$processing, "Starting analysis:", analysis_type)
    TesseraLogger$info(message, context, "ANALYSIS")
  },
  
  log_analysis_complete = function(analysis_type, duration_ms = NULL, context = NULL) {
    if (!is.null(duration_ms)) {
      message <- paste(emojis$success, "Completed analysis:", analysis_type, 
                      sprintf("(%.1fms)", duration_ms))
    } else {
      message <- paste(emojis$success, "Completed analysis:", analysis_type)
    }
    TesseraLogger$info(message, context, "ANALYSIS")
  },
  
  log_graph_operation = function(operation, context = NULL) {
    message <- paste(emojis$graph, "Graph operation:", operation)
    TesseraLogger$info(message, context, "GRAPH")
  },
  
  log_performance_metric = function(metric_name, value, unit = "ms", context = NULL) {
    message <- paste(emojis$performance, sprintf("%s: %.2f%s", metric_name, value, unit))
    TesseraLogger$info(message, context, "PERFORMANCE")
  },
  
  log_data_processing = function(operation, rows = NULL, context = NULL) {
    if (!is.null(rows)) {
      message <- paste(emojis$data, sprintf("Data %s: %d rows", operation, rows))
    } else {
      message <- paste(emojis$data, "Data", operation)
    }
    TesseraLogger$info(message, context, "DATA")
  },
  
  log_algorithm_execution = function(algorithm, context = NULL) {
    message <- paste(emojis$algorithm, "Executing algorithm:", algorithm)
    TesseraLogger$info(message, context, "ALGORITHM")
  },
  
  log_visualization_creation = function(viz_type, context = NULL) {
    message <- paste(emojis$visualization, "Creating visualization:", viz_type)
    TesseraLogger$info(message, context, "VISUALIZATION")
  },
  
  log_cache_operation = function(operation, key, context = NULL) {
    emoji <- switch(operation,
                   "hit" = "🎯",
                   "miss" = "❌", 
                   emojis$cache)
    message <- paste(emoji, sprintf("Cache %s: %s", operation, key))
    TesseraLogger$debug(message, context, "CACHE")
  },
  
  log_network_analysis = function(operation, nodes = NULL, edges = NULL, context = NULL) {
    if (!is.null(nodes) && !is.null(edges)) {
      message <- paste(emojis$network, sprintf("Network %s: %d nodes, %d edges", 
                                              operation, nodes, edges))
    } else {
      message <- paste(emojis$network, "Network", operation)
    }
    TesseraLogger$info(message, context, "NETWORK")
  },
  
  log_export_operation = function(format, filename = NULL, context = NULL) {
    if (!is.null(filename)) {
      message <- paste(emojis$export, sprintf("Exporting to %s: %s", format, filename))
    } else {
      message <- paste(emojis$export, "Exporting to", format)
    }
    TesseraLogger$info(message, context, "EXPORT")
  },
  
  log_import_operation = function(source, context = NULL) {
    message <- paste(emojis$import, "Importing from:", source)
    TesseraLogger$info(message, context, "IMPORT")
  }
)

# Private helper function to format messages with context
.format_message <- function(message, context = NULL) {
  if (is.null(context) || length(context) == 0) {
    return(message)
  }
  
  # Convert context to key=value pairs
  context_str <- paste(
    sapply(names(context), function(key) {
      value <- context[[key]]
      if (is.numeric(value)) {
        sprintf("%s=%.2f", key, value)
      } else {
        sprintf("%s=%s", key, as.character(value))
      }
    }),
    collapse = ", "
  )
  
  return(sprintf("%s | %s", message, context_str))
}

# Performance measurement utilities
measure_performance <- function(name, expr, logger = TesseraLogger) {
  start_time <- Sys.time()
  logger$log_analysis_start(name)
  
  tryCatch({
    result <- eval(expr)
    duration_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000
    logger$log_analysis_complete(name, duration_ms)
    return(result)
  }, error = function(e) {
    duration_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000
    logger$error(sprintf("Failed: %s (%.1fms)", name, duration_ms), e)
    stop(e)
  })
}

# Convenience functions for common operations
log_r_startup <- function(script_name) {
  TesseraLogger$info(paste("🚀 Starting R script:", script_name), 
                    list(pid = Sys.getpid(), version = R.version.string))
}

log_r_shutdown <- function(script_name) {
  TesseraLogger$info(paste("🛑 Shutting down R script:", script_name))
}

log_package_load <- function(package_name) {
  TesseraLogger$debug(paste("📦 Loading package:", package_name))
}

log_data_summary <- function(data_name, data_obj) {
  if (is.data.frame(data_obj)) {
    context <- list(
      rows = nrow(data_obj),
      cols = ncol(data_obj),
      size_mb = round(object.size(data_obj) / 1024^2, 2)
    )
  } else if (is.matrix(data_obj)) {
    context <- list(
      rows = nrow(data_obj),
      cols = ncol(data_obj),
      size_mb = round(object.size(data_obj) / 1024^2, 2)
    )
  } else {
    context <- list(
      length = length(data_obj),
      class = class(data_obj)[1],
      size_mb = round(object.size(data_obj) / 1024^2, 2)
    )
  }
  
  TesseraLogger$log_data_processing("loaded", context = context)
}

# Export the logger for use in other scripts
tessera_logger <- TesseraLogger

# Print startup message
cat(crayon::green("✅ Tessera R Logger initialized\n"))
cat(crayon::blue(sprintf("📊 Log level: %s\n", log_level)))
cat(crayon::silver("🔧 Use tessera_logger$info(), tessera_logger$debug(), etc.\n"))
