#!/usr/bin/env Rscript

# Quick verification script to ensure R test setup is working

cat("=== WikiCrawler R Test Setup Verification ===\n\n")

# Check R version
cat("R Version:", R.version.string, "\n")

# Check required packages
packages <- c("testthat", "jsonlite", "igraph")
missing <- c()

for (pkg in packages) {
    if (requireNamespace(pkg, quietly = TRUE)) {
        cat("✓ Package", pkg, "is available\n")
    } else {
        cat("✗ Package", pkg, "is missing\n")
        missing <- c(missing, pkg)
    }
}

if (length(missing) > 0) {
    cat("\nInstalling missing packages...\n")
    install.packages(missing, repos = "https://cran.r-project.org")
    cat("✓ Packages installed\n")
}

# Check R scripts exist
scripts <- c(
    "../r_scripts/graph_analysis.R",
    "../r_scripts/layout_algorithms.R",
    "../r_scripts/temporal_analysis.R"
)

all_exist <- TRUE
for (script in scripts) {
    if (file.exists(script)) {
        cat("✓ Found:", script, "\n")
    } else {
        cat("✗ Missing:", script, "\n")
        all_exist <- FALSE
    }
}

# Check test files
test_files <- list.files("testthat", pattern = "test_.*\\.R$", full.names = TRUE)
cat("✓ Found", length(test_files), "test files\n")

# Check test helpers
if (file.exists("helpers/test_helpers.R")) {
    cat("✓ Test helpers available\n")
} else {
    cat("✗ Test helpers missing\n")
    all_exist <- FALSE
}

# Quick functionality test
cat("\n=== Quick Functionality Test ===\n")

tryCatch({
    # Source test helpers
    source("helpers/test_helpers.R")
    cat("✓ Test helpers loaded successfully\n")
    
    # Test mock data generation
    graph_data <- create_simple_test_graph()
    cat("✓ Mock graph data generated\n")
    
    temporal_data <- generate_mock_temporal_data(n_articles = 5, n_links = 7, date_range_days = 3)
    cat("✓ Mock temporal data generated\n")
    
    # Test JSON conversion
    json_data <- create_test_json(graph_data)
    parsed_data <- jsonlite::fromJSON(json_data)
    cat("✓ JSON conversion working\n")
    
    cat("\n🎉 Setup verification completed successfully!\n")
    cat("You can now run: Rscript run_r_tests.R\n")
    
}, error = function(e) {
    cat("✗ Error during verification:", e$message, "\n")
    quit(status = 1)
})
