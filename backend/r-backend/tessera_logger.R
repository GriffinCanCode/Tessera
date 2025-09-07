#!/usr/bin/env Rscript

# Simple Tessera Logger for R Scripts
# Provides basic logging functionality for the Tessera R analysis scripts

# Simple logging functions
log_package_load <- function(package_name) {
    # Simple stub - in production this would log to file
    message(paste("Loading package:", package_name))
}

log_info <- function(message) {
    cat("[INFO]", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "-", message, "\n")
}

log_warning <- function(message) {
    cat("[WARNING]", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "-", message, "\n")
}

log_error <- function(message) {
    cat("[ERROR]", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "-", message, "\n")
}

log_debug <- function(message) {
    # Only log debug messages if debug mode is enabled
    if (Sys.getenv("TESSERA_DEBUG", "false") == "true") {
        cat("[DEBUG]", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "-", message, "\n")
    }
}

log_r_startup <- function(script_name) {
    log_info(paste("Starting R script:", script_name))
}

# Create tessera_logger object with expected methods
tessera_logger <- list(
    log_analysis_start = function(operation) {
        log_info(paste("Starting analysis:", operation))
    },
    log_import_operation = function(operation) {
        log_info(paste("Import operation:", operation))
    },
    log_data_processing = function(operation, details = "") {
        log_info(paste("Data processing:", operation, details))
    },
    log_analysis_complete = function(operation, details = "") {
        log_info(paste("Analysis complete:", operation, details))
    },
    log_analysis_error = function(operation, error = "") {
        log_error(paste("Analysis error in", operation, ":", error))
    }
)

# Initialize logger
log_info("Tessera logger initialized")