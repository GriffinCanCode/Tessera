#!/usr/bin/env Rscript

# WikiCrawler R Scripts Test Runner
# Comprehensive test suite runner for all R analysis scripts

# Load required libraries
suppressPackageStartupMessages({
    library(testthat)
    if (!requireNamespace("jsonlite", quietly = TRUE)) {
        install.packages("jsonlite", repos = "https://cran.r-project.org")
        library(jsonlite)
    }
    if (!requireNamespace("igraph", quietly = TRUE)) {
        install.packages("igraph", repos = "https://cran.r-project.org")
        library(igraph)
    }
})

# Configuration
TEST_DIR <- "testthat"
RESULTS_FILE <- "test_results.json"
COVERAGE_FILE <- "test_coverage.txt"

# Color codes for output
if (interactive()) {
    RED <- "\033[31m"
    GREEN <- "\033[32m"
    YELLOW <- "\033[33m"
    BLUE <- "\033[34m"
    RESET <- "\033[0m"
} else {
    RED <- ""
    GREEN <- ""
    YELLOW <- ""
    BLUE <- ""
    RESET <- ""
}

# Helper functions
cat_color <- function(text, color = "", newline = TRUE) {
    if (newline) {
        cat(color, text, RESET, "\n", sep = "")
    } else {
        cat(color, text, RESET, sep = "")
    }
}

print_header <- function(text) {
    cat("\n")
    cat_color(paste(rep("=", nchar(text) + 4), collapse = ""), BLUE)
    cat_color(paste("", text, ""), BLUE)
    cat_color(paste(rep("=", nchar(text) + 4), collapse = ""), BLUE)
}

print_section <- function(text) {
    cat("\n")
    cat_color(paste("-", text), YELLOW)
}

print_success <- function(text) {
    cat_color(paste("✓", text), GREEN)
}

print_error <- function(text) {
    cat_color(paste("✗", text), RED)
}

print_info <- function(text) {
    cat_color(paste("ℹ", text), BLUE)
}

# Check prerequisites
check_prerequisites <- function() {
    print_section("Checking Prerequisites")
    
    # Check R version
    r_version <- R.version.string
    print_info(paste("R Version:", r_version))
    
    # Check required packages
    required_packages <- c("testthat", "jsonlite", "igraph")
    missing_packages <- c()
    
    for (pkg in required_packages) {
        if (!requireNamespace(pkg, quietly = TRUE)) {
            missing_packages <- c(missing_packages, pkg)
        } else {
            print_success(paste("Package", pkg, "is available"))
        }
    }
    
    if (length(missing_packages) > 0) {
        print_error(paste("Missing packages:", paste(missing_packages, collapse = ", ")))
        cat("Installing missing packages...\n")
        install.packages(missing_packages, repos = "https://cran.r-project.org")
    }
    
    # Check R scripts exist
    r_scripts <- c(
        "../r_scripts/graph_analysis.R",
        "../r_scripts/layout_algorithms.R", 
        "../r_scripts/temporal_analysis.R"
    )
    
    for (script in r_scripts) {
        if (file.exists(script)) {
            print_success(paste("Found:", script))
        } else {
            print_error(paste("Missing:", script))
            return(FALSE)
        }
    }
    
    # Check test files exist
    test_files <- list.files(TEST_DIR, pattern = "test_.*\\.R$", full.names = TRUE)
    if (length(test_files) == 0) {
        print_error("No test files found in testthat directory")
        return(FALSE)
    }
    
    print_success(paste("Found", length(test_files), "test files"))
    return(TRUE)
}

# Run individual test file
run_test_file <- function(test_file) {
    test_name <- basename(test_file)
    cat_color(paste("Running", test_name, "..."), newline = FALSE)
    
    start_time <- Sys.time()
    
    # Capture test output
    result <- tryCatch({
        # Create a temporary environment for the test
        test_env <- new.env()
        
        # Run the test file
        with(test_env, {
            source(test_file, local = TRUE)
        })
        
        list(
            success = TRUE,
            errors = c(),
            warnings = c(),
            execution_time = as.numeric(Sys.time() - start_time)
        )
    }, error = function(e) {
        list(
            success = FALSE,
            errors = e$message,
            warnings = c(),
            execution_time = as.numeric(Sys.time() - start_time)
        )
    }, warning = function(w) {
        list(
            success = TRUE,
            errors = c(),
            warnings = w$message,
            execution_time = as.numeric(Sys.time() - start_time)
        )
    })
    
    if (result$success) {
        cat_color(" ✓", GREEN)
        cat_color(sprintf(" (%.2fs)", result$execution_time))
    } else {
        cat_color(" ✗", RED)
        cat_color(sprintf(" (%.2fs)", result$execution_time))
    }
    
    return(result)
}

# Run all tests using testthat framework
run_testthat_tests <- function() {
    print_section("Running Tests with testthat")
    
    # Change to test directory
    original_dir <- getwd()
    on.exit(setwd(original_dir))
    
    tryCatch({
        # Use testthat to run all tests
        test_results <- test_dir(
            TEST_DIR,
            reporter = "summary",
            env = parent.frame(),
            load_helpers = TRUE,
            stop_on_failure = FALSE
        )
        
        return(test_results)
    }, error = function(e) {
        print_error(paste("Error running testthat tests:", e$message))
        return(NULL)
    })
}

# Manual test runner (fallback)
run_manual_tests <- function() {
    print_section("Running Tests Manually")
    
    test_files <- list.files(TEST_DIR, pattern = "test_.*\\.R$", full.names = TRUE)
    test_files <- sort(test_files)  # Run in predictable order
    
    results <- list()
    total_time <- 0
    failed_tests <- 0
    passed_tests <- 0
    
    for (test_file in test_files) {
        result <- run_test_file(test_file)
        test_name <- basename(test_file)
        results[[test_name]] <- result
        total_time <- total_time + result$execution_time
        
        if (result$success) {
            passed_tests <- passed_tests + 1
        } else {
            failed_tests <- failed_tests + 1
            print_error(paste("Errors in", test_name, ":"))
            for (error in result$errors) {
                cat("  ", error, "\n")
            }
        }
        
        if (length(result$warnings) > 0) {
            cat_color("Warnings:", YELLOW)
            for (warning in result$warnings) {
                cat("  ", warning, "\n")
            }
        }
    }
    
    return(list(
        results = results,
        total_time = total_time,
        passed_tests = passed_tests,
        failed_tests = failed_tests,
        total_tests = length(test_files)
    ))
}

# Generate coverage report
generate_coverage_report <- function() {
    print_section("Analyzing Test Coverage")
    
    r_scripts <- c(
        "../r_scripts/graph_analysis.R",
        "../r_scripts/layout_algorithms.R",
        "../r_scripts/temporal_analysis.R"
    )
    
    coverage_info <- list()
    
    for (script_path in r_scripts) {
        if (!file.exists(script_path)) next
        
        script_name <- basename(script_path)
        script_content <- readLines(script_path)
        
        # Count functions (simple heuristic)
        function_lines <- grep("^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*<-[[:space:]]*function", 
                              script_content)
        
        # Extract function names
        function_names <- c()
        for (line_num in function_lines) {
            line <- script_content[line_num]
            func_match <- regexpr("^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)", line, perl = TRUE)
            if (func_match > 0) {
                func_name <- regmatches(line, func_match)
                func_name <- gsub("^[[:space:]]*", "", func_name)
                function_names <- c(function_names, func_name)
            }
        }
        
        coverage_info[[script_name]] <- list(
            total_lines = length(script_content),
            function_count = length(function_names),
            functions = function_names
        )
        
        print_info(paste(script_name, ":", length(function_names), "functions,", 
                        length(script_content), "lines"))
    }
    
    return(coverage_info)
}

# Save results to JSON
save_results <- function(test_results, coverage_info) {
    print_section("Saving Results")
    
    output <- list(
        timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        r_version = R.version.string,
        test_results = test_results,
        coverage_info = coverage_info,
        summary = list(
            total_tests = ifelse(is.null(test_results$total_tests), 0, test_results$total_tests),
            passed_tests = ifelse(is.null(test_results$passed_tests), 0, test_results$passed_tests),
            failed_tests = ifelse(is.null(test_results$failed_tests), 0, test_results$failed_tests),
            total_execution_time = ifelse(is.null(test_results$total_time), 0, test_results$total_time)
        )
    )
    
    tryCatch({
        writeLines(toJSON(output, pretty = TRUE, auto_unbox = TRUE), RESULTS_FILE)
        print_success(paste("Results saved to", RESULTS_FILE))
    }, error = function(e) {
        print_error(paste("Failed to save results:", e$message))
    })
}

# Print final summary
print_summary <- function(test_results) {
    print_header("Test Summary")
    
    if (is.null(test_results)) {
        print_error("No test results available")
        return()
    }
    
    total <- ifelse(is.null(test_results$total_tests), 0, test_results$total_tests)
    passed <- ifelse(is.null(test_results$passed_tests), 0, test_results$passed_tests)
    failed <- ifelse(is.null(test_results$failed_tests), 0, test_results$failed_tests)
    time <- ifelse(is.null(test_results$total_time), 0, test_results$total_time)
    
    cat("\n")
    print_info(paste("Total Tests:", total))
    
    if (passed > 0) {
        print_success(paste("Passed:", passed))
    }
    
    if (failed > 0) {
        print_error(paste("Failed:", failed))
    }
    
    print_info(paste("Total Time:", sprintf("%.2f seconds", time)))
    
    if (failed == 0 && total > 0) {
        cat("\n")
        print_success("All tests passed! 🎉")
    } else if (failed > 0) {
        cat("\n")
        print_error("Some tests failed. Please check the errors above.")
    }
    
    # Success rate
    if (total > 0) {
        success_rate <- (passed / total) * 100
        cat("\n")
        color <- if (success_rate == 100) GREEN else if (success_rate >= 80) YELLOW else RED
        cat_color(sprintf("Success Rate: %.1f%%", success_rate), color)
    }
}

# Main execution function
main <- function(args = commandArgs(trailingOnly = TRUE)) {
    print_header("WikiCrawler R Scripts Test Suite")
    
    # Parse command line arguments
    run_coverage <- "--coverage" %in% args
    verbose <- "--verbose" %in% args
    manual_mode <- "--manual" %in% args
    
    if ("--help" %in% args) {
        cat("Usage: Rscript run_r_tests.R [options]\n")
        cat("Options:\n")
        cat("  --coverage    Generate coverage report\n")
        cat("  --verbose     Verbose output\n")
        cat("  --manual      Use manual test runner instead of testthat\n")
        cat("  --help        Show this help message\n")
        return(invisible())
    }
    
    # Check prerequisites
    if (!check_prerequisites()) {
        print_error("Prerequisites not met. Exiting.")
        quit(status = 1)
    }
    
    # Run tests
    start_time <- Sys.time()
    
    if (manual_mode) {
        test_results <- run_manual_tests()
    } else {
        # Try testthat first, fallback to manual
        testthat_results <- run_testthat_tests()
        if (is.null(testthat_results)) {
            print_info("Falling back to manual test runner")
            test_results <- run_manual_tests()
        } else {
            # Convert testthat results to our format
            failed_count <- 0
            passed_count <- 0
            
            if (is.list(testthat_results)) {
                for (result in testthat_results) {
                    if (is.list(result) && "failed" %in% names(result)) {
                        if (result$failed > 0) {
                            failed_count <- failed_count + 1
                        } else {
                            passed_count <- passed_count + 1
                        }
                    }
                }
            }
            
            test_results <- list(
                results = testthat_results,
                total_time = as.numeric(Sys.time() - start_time),
                passed_tests = passed_count,
                failed_tests = failed_count,
                total_tests = passed_count + failed_count
            )
        }
    }
    
    # Generate coverage report if requested
    coverage_info <- NULL
    if (run_coverage) {
        coverage_info <- generate_coverage_report()
    }
    
    # Save results
    save_results(test_results, coverage_info)
    
    # Print summary
    print_summary(test_results)
    
    # Exit with appropriate code
    failed <- ifelse(is.null(test_results$failed_tests), 1, test_results$failed_tests)
    if (failed > 0) {
        quit(status = 1)
    } else {
        quit(status = 0)
    }
}

# Run if called from command line
if (sys.nframe() == 0) {
    main()
}
