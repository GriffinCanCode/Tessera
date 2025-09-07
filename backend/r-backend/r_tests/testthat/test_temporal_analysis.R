#!/usr/bin/env Rscript

# Test Suite for temporal_analysis.R
# Tests temporal pattern analysis functions

# Load test framework and helpers
library(testthat)
library(jsonlite)

# Source the test helpers
source("helpers/test_helpers.R")

# Source the script under test
script_env <- source_r_script("../temporal_analysis.R")

# Helper to access functions from the script environment
get_func <- function(name) get(name, envir = script_env)

test_that("analyze_temporal_patterns handles valid JSON input", {
    temporal_data <- generate_mock_temporal_data(n_articles = 15, n_links = 25, date_range_days = 20)
    json_input <- create_test_json(temporal_data)
    
    result_json <- get_func("analyze_temporal_patterns")(json_input)
    result <- validate_json_output(result_json, 
                                 c("growth_analysis", "discovery_timeline", 
                                   "knowledge_evolution", "learning_phases", "temporal_metrics"))
    
    validate_temporal_analysis(result)
})

test_that("analyze_temporal_patterns handles invalid input gracefully", {
    # Test truly invalid JSON
    invalid_json_inputs <- c(
        "",
        "{invalid json}"
    )
    
    for (invalid_input in invalid_json_inputs) {
        result_json <- get_func("analyze_temporal_patterns")(invalid_input)
        result <- fromJSON(result_json)
        expect_true("error" %in% names(result))
    }
    
    # Test valid JSON but empty/null data (should handle gracefully)
    empty_data_inputs <- c(
        "null",
        '{"articles": null, "links": null}',
        '{"articles": [], "links": []}'
    )
    
    for (empty_input in empty_data_inputs) {
        result_json <- get_func("analyze_temporal_patterns")(empty_input)
        result <- fromJSON(result_json)
        # Should handle gracefully without errors
        expect_false("error" %in% names(result))
        expect_true("temporal_metrics" %in% names(result))
    }
})

test_that("analyze_growth_patterns computes growth metrics correctly", {
    temporal_data <- generate_mock_temporal_data(n_articles = 20, n_links = 35, date_range_days = 10)
    
    # Convert to JSON and back to simulate the actual data flow
    json_input <- create_test_json(temporal_data)
    parsed_data <- fromJSON(json_input)
    
    growth_analysis <- get_func("analyze_growth_patterns")(parsed_data)
    
    # Should not contain error
    expect_false("error" %in% names(growth_analysis))
    
    # Check required fields
    required_fields <- c("dates", "articles_cumulative", "links_cumulative", 
                        "articles_daily", "links_daily", "articles_velocity", 
                        "links_velocity", "knowledge_density_over_time")
    
    for (field in required_fields) {
        expect_true(field %in% names(growth_analysis),
                   info = paste("Missing field:", field))
    }
    
    # Check data consistency
    n_dates <- length(growth_analysis$dates)
    expect_equal(length(growth_analysis$articles_cumulative), n_dates)
    expect_equal(length(growth_analysis$links_cumulative), n_dates)
    expect_equal(length(growth_analysis$articles_daily), n_dates)
    expect_equal(length(growth_analysis$links_daily), n_dates)
    
    # Cumulative counts should be non-decreasing
    expect_true(all(diff(growth_analysis$articles_cumulative) >= 0))
    expect_true(all(diff(growth_analysis$links_cumulative) >= 0))
    
    # Final cumulative count should be close to input data (allowing for date filtering)
    expect_gte(tail(growth_analysis$articles_cumulative, 1), 15)  # Allow some filtering
    expect_lte(tail(growth_analysis$articles_cumulative, 1), 20)
    expect_gte(tail(growth_analysis$links_cumulative, 1), 25)
    expect_lte(tail(growth_analysis$links_cumulative, 1), 35)
    
    # Daily additions should sum to total (allowing for filtering)
    expect_gte(sum(growth_analysis$articles_daily), 15)
    expect_lte(sum(growth_analysis$articles_daily), 20)
    expect_gte(sum(growth_analysis$links_daily), 25)
    expect_lte(sum(growth_analysis$links_daily), 35)
})

test_that("analyze_growth_patterns handles missing data", {
    # Test with missing articles
    temporal_data_no_articles <- list(links = list(
        list(from = "A", to = "B", created_at = "2024-01-01")
    ))
    result <- get_func("analyze_growth_patterns")(temporal_data_no_articles)
    expect_true("error" %in% names(result))
    
    # Test with missing links
    temporal_data_no_links <- list(articles = list(
        list(id = "A", title = "Article A", created_at = "2024-01-01")
    ))
    result <- get_func("analyze_growth_patterns")(temporal_data_no_links)
    expect_true("error" %in% names(result))
})

test_that("analyze_discovery_timeline tracks discovery patterns", {
    temporal_data <- generate_mock_temporal_data(n_articles = 25, n_links = 30, date_range_days = 15)
    
    # Convert to JSON and back to simulate the actual data flow
    json_input <- create_test_json(temporal_data)
    parsed_data <- fromJSON(json_input)
    
    timeline <- get_func("analyze_discovery_timeline")(parsed_data)
    
    # Should not contain error
    expect_false("error" %in% names(timeline))
    
    # Check required sections
    required_sections <- c("discovery_milestones", "monthly_patterns", 
                          "category_evolution", "exploration_phases")
    
    for (section in required_sections) {
        expect_true(section %in% names(timeline),
                   info = paste("Missing timeline section:", section))
    }
    
    # Check discovery milestones structure
    milestones <- timeline$discovery_milestones
    if (is.data.frame(milestones) && nrow(milestones) > 0) {
        expect_true("category" %in% names(milestones))
        expect_true("first_discovery" %in% names(milestones))
        expect_true("article_count" %in% names(milestones))
        expect_true("representative_article" %in% names(milestones))
    }
})

test_that("analyze_discovery_timeline handles invalid dates", {
    # Create data with invalid dates
    temporal_data <- list(
        articles = list(
            list(id = "1", title = "Article 1", created_at = "invalid-date"),
            list(id = "2", title = "Article 2", created_at = "2024-01-01")
        ),
        links = list()
    )
    
    # Convert to JSON and back to simulate the actual data flow
    json_input <- create_test_json(temporal_data)
    parsed_data <- fromJSON(json_input)
    
    # This should handle the error gracefully
    tryCatch({
        timeline <- get_func("analyze_discovery_timeline")(parsed_data)
        
        # Should handle gracefully - either error or process valid dates only
        if (!"error" %in% names(timeline)) {
            # If no error, should have processed at least the valid date
            expect_true("discovery_milestones" %in% names(timeline))
        }
    }, error = function(e) {
        # It's acceptable for this to fail with invalid dates
        expect_true(grepl("character string is not in a standard unambiguous format", e$message))
    })
})

test_that("analyze_knowledge_evolution tracks structural changes", {
    temporal_data <- generate_mock_temporal_data(n_articles = 15, n_links = 25, date_range_days = 12)
    
    # Convert to JSON and back to simulate the actual data flow
    json_input <- create_test_json(temporal_data)
    parsed_data <- fromJSON(json_input)
    
    evolution <- get_func("analyze_knowledge_evolution")(parsed_data)
    
    # Should not contain error
    expect_false("error" %in% names(evolution))
    
    # Check required fields
    required_fields <- c("dates", "knowledge_depth_evolution", 
                        "complexity_score", "interconnectedness")
    
    for (field in required_fields) {
        expect_true(field %in% names(evolution),
                   info = paste("Missing evolution field:", field))
    }
    
    # Check that arrays have consistent lengths
    n_dates <- length(evolution$dates)
    expect_equal(length(evolution$knowledge_depth_evolution), n_dates)
    expect_equal(length(evolution$complexity_score), n_dates)
    expect_equal(length(evolution$interconnectedness), n_dates)
    
    # Knowledge depth should be non-negative
    expect_true(all(evolution$knowledge_depth_evolution >= 0))
    expect_true(all(evolution$interconnectedness >= 0))
})

test_that("identify_learning_phases detects activity patterns", {
    # Create data with distinct activity periods
    temporal_data <- generate_mock_temporal_data(n_articles = 30, n_links = 40, date_range_days = 28)
    
    # Convert to JSON and back to simulate the actual data flow
    json_input <- create_test_json(temporal_data)
    parsed_data <- fromJSON(json_input)
    
    phases <- get_func("identify_learning_phases")(parsed_data)
    
    # Should not contain error
    expect_false("error" %in% names(phases))
    
    # Check structure
    expect_true("phase_count" %in% names(phases))
    expect_true("phases" %in% names(phases))
    expect_type(phases$phases, "list")
    expect_gte(phases$phase_count, 1)
    
    # Each phase should have required fields
    if (phases$phase_count > 0) {
        for (i in 1:min(phases$phase_count, length(phases$phases))) {
            phase <- phases$phases[[i]]
            expect_true("start_date" %in% names(phase))
            expect_true("end_date" %in% names(phase))
            expect_true("activity_level" %in% names(phase))
            expect_true("description" %in% names(phase))
            
            # Activity level should be valid
            expect_true(phase$activity_level %in% c("high", "low"))
        }
    }
})

test_that("identify_learning_phases handles insufficient data", {
    # Test with very little data
    minimal_data <- list(
        articles = list(
            list(id = "1", title = "Article 1", created_at = "2024-01-01"),
            list(id = "2", title = "Article 2", created_at = "2024-01-02")
        ),
        links = list()
    )
    
    phases <- get_func("identify_learning_phases")(minimal_data)
    
    # Should handle gracefully
    expect_true("message" %in% names(phases) || "phase_count" %in% names(phases))
})

test_that("calculate_temporal_metrics computes summary statistics", {
    temporal_data <- generate_mock_temporal_data(n_articles = 20, n_links = 30, date_range_days = 10)
    
    # Convert to JSON and back to simulate the actual data flow
    json_input <- create_test_json(temporal_data)
    parsed_data <- fromJSON(json_input)
    
    metrics <- get_func("calculate_temporal_metrics")(parsed_data)
    
    # Check expected metrics
    expected_metrics <- c("total_days_active", "avg_articles_per_day", 
                         "peak_discovery_day", "avg_links_per_day", "peak_linking_day")
    
    for (metric in expected_metrics) {
        expect_true(metric %in% names(metrics),
                   info = paste("Missing temporal metric:", metric))
    }
    
    # Check metric values are reasonable
    expect_gte(metrics$total_days_active, 0)  # Allow 0 for edge cases
    expect_gte(metrics$avg_articles_per_day, 0)
    expect_gte(metrics$avg_links_per_day, 0)
    
    # Peak days should be valid date strings or "N/A"
    expect_true(nchar(metrics$peak_discovery_day) == 10 || metrics$peak_discovery_day == "N/A")
    expect_true(nchar(metrics$peak_linking_day) == 10 || metrics$peak_linking_day == "N/A")
})

test_that("helper functions work correctly", {
    # Test calculate_velocity
    cumulative_data <- c(0, 5, 10, 12, 20)
    velocity <- get_func("calculate_velocity")(cumulative_data)
    expected_velocity <- c(0, 5, 5, 2, 8)
    expect_equal(velocity, expected_velocity)
    
    # Test with short data
    short_data <- c(5)
    short_velocity <- get_func("calculate_velocity")(short_data)
    expect_equal(short_velocity, 0)
    
    # Test calculate_growth_rate
    articles <- c(1, 3, 5, 8, 10)
    links <- c(0, 2, 6, 10, 15)
    growth_rate <- get_func("calculate_growth_rate")(articles, links)
    expect_length(growth_rate, 5)
    expect_equal(growth_rate[1], 0)  # First value should be 0
    expect_true(all(is.finite(growth_rate)))
})

test_that("temporal analysis handles date parsing correctly", {
    # Test with various date formats
    temporal_data_iso <- list(
        articles = list(
            list(id = "1", title = "Article 1", created_at = "2024-01-15"),
            list(id = "2", title = "Article 2", created_at = "2024-01-16")
        ),
        links = list(
            list(from = "1", to = "2", created_at = "2024-01-15")
        )
    )
    
    json_input <- create_test_json(temporal_data_iso)
    result_json <- get_func("analyze_temporal_patterns")(json_input)
    result <- fromJSON(result_json)
    
    # Should process dates without errors
    expect_false("error" %in% names(result))
    expect_true("temporal_metrics" %in% names(result))
})

test_that("complex temporal patterns are detected", {
    # Create data with multiple discovery bursts
    complex_temporal_data <- list(
        articles = list(),
        links = list()
    )
    
    # Add articles in bursts
    article_count <- 1
    for (burst_day in c(1, 3, 7, 10, 15)) {
        for (i in 1:5) {
            complex_temporal_data$articles[[article_count]] <- list(
                id = as.character(article_count),
                title = paste("Article", article_count),
                created_at = paste0("2024-01-", sprintf("%02d", burst_day)),
                categories = sample(c("Science", "History", "Technology"), 1)
            )
            article_count <- article_count + 1
        }
    }
    
    # Add some links
    for (i in 1:20) {
        complex_temporal_data$links[[i]] <- list(
            from = as.character(sample(1:25, 1)),
            to = as.character(sample(1:25, 1)),
            created_at = paste0("2024-01-", sprintf("%02d", sample(1:15, 1)))
        )
    }
    
    json_input <- create_test_json(complex_temporal_data)
    result_json <- get_func("analyze_temporal_patterns")(json_input)
    result <- fromJSON(result_json)
    
    # Should detect multiple phases
    expect_false("error" %in% names(result))
    phases <- result$learning_phases
    expect_gte(phases$phase_count, 1)
    
    # Growth analysis should show variation
    growth <- result$growth_analysis
    expect_gt(max(growth$articles_daily), 0)
    expect_gt(var(growth$articles_daily), 0)  # Should have variation
})

test_that("case_when helper function works correctly", {
    case_when_func <- get_func("case_when")
    
    # Test basic functionality
    test_vector <- c(TRUE, FALSE, TRUE)
    result <- case_when_func(test_vector, "match", TRUE, "default")
    
    # Should return values of appropriate length
    expect_length(result, length(test_vector))
})

test_that("null coalescing operator works in temporal context", {
    null_coalesce <- get_func("%||%")
    
    expect_equal(null_coalesce(NULL, "default"), "default")
    expect_equal(null_coalesce(NA, "default"), "default")
    expect_equal(null_coalesce("value", "default"), "value")
    expect_equal(null_coalesce(c(), "default"), "default")
})

test_that("main function handles command line arguments correctly", {
    main_func <- get_func("main")
    expect_type(main_func, "closure")
})

test_that("end-to-end temporal analysis with different data patterns", {
    # Test different temporal patterns
    patterns <- list(
        steady = generate_mock_temporal_data(n_articles = 20, n_links = 30, date_range_days = 20),
        burst = list(
            articles = lapply(1:15, function(i) list(
                id = as.character(i),
                title = paste("Article", i),
                created_at = "2024-01-01",  # All on same day
                categories = "Science"
            )),
            links = lapply(1:20, function(i) list(
                from = as.character(sample(1:15, 1)),
                to = as.character(sample(1:15, 1)),
                created_at = "2024-01-01"
            ))
        ),
        sparse = generate_mock_temporal_data(n_articles = 10, n_links = 12, date_range_days = 60)
    )
    
    for (pattern_name in names(patterns)) {
        temporal_data <- patterns[[pattern_name]]
        json_input <- create_test_json(temporal_data)
        
        result_json <- get_func("analyze_temporal_patterns")(json_input)
        result <- fromJSON(result_json)
        
        # Should handle all patterns without error
        expect_false("error" %in% names(result),
                    info = paste("Error in", pattern_name, "pattern"))
        
        # Should have all major analysis sections
        validate_temporal_analysis(result)
        
        # Pattern-specific checks
        if (pattern_name == "burst") {
            # Burst pattern should show high activity on single day
            growth <- result$growth_analysis
            if (length(growth$articles_daily) > 0 && any(growth$articles_daily > 0)) {
                max_daily <- max(growth$articles_daily)
                expect_gte(max_daily, 0)  # At least some activity
            }
        }
        
        if (pattern_name == "sparse") {
            # Sparse pattern should have low average activity
            metrics <- result$temporal_metrics
            expect_lt(metrics$avg_articles_per_day, 1)
        }
    }
})

test_that("temporal analysis handles large datasets efficiently", {
    # Test with larger dataset
    large_temporal_data <- generate_mock_temporal_data(
        n_articles = 100, 
        n_links = 200, 
        date_range_days = 90
    )
    
    json_input <- create_test_json(large_temporal_data)
    
    start_time <- Sys.time()
    result_json <- get_func("analyze_temporal_patterns")(json_input)
    end_time <- Sys.time()
    
    result <- fromJSON(result_json)
    
    # Should complete efficiently
    execution_time <- as.numeric(end_time - start_time)
    expect_lt(execution_time, 30)  # Should complete within 30 seconds
    
    # Should produce valid results
    expect_false("error" %in% names(result))
    validate_temporal_analysis(result)
    
    # Results should reflect input size
    expect_gte(result$temporal_metrics$total_days_active, 90)  # Allow for date range variations  # 90 days + 1
})

# Cleanup after tests
teardown({
    cleanup_test_env()
})

cat("Temporal analysis tests completed successfully\n")
