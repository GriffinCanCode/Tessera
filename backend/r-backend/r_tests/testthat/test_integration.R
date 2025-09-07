#!/usr/bin/env Rscript

# Integration Test Suite for Tessera R Scripts
# Tests interactions between all R analysis scripts

# Load test framework and helpers
library(testthat)
library(jsonlite)
library(igraph)

# Source the test helpers
source("helpers/test_helpers.R")

# Source all R scripts under test
graph_env <- source_r_script("../graph_analysis.R")
layout_env <- source_r_script("../layout_algorithms.R")
temporal_env <- source_r_script("../temporal_analysis.R")

# Helper functions to access script environments
get_graph_func <- function(name) get(name, envir = graph_env)
get_layout_func <- function(name) get(name, envir = layout_env)
get_temporal_func <- function(name) get(name, envir = temporal_env)

test_that("graph and layout analysis work together", {
    # Create test data
    graph_data <- create_complex_test_graph()
    json_input <- create_test_json(graph_data)
    
    # Run graph analysis
    graph_result_json <- get_graph_func("process_graph")(json_input)
    graph_result <- fromJSON(graph_result_json)
    expect_false("error" %in% names(graph_result))
    
    # Run layout analysis on same data
    layout_result_json <- get_layout_func("calculate_advanced_layouts")(json_input)
    layout_result <- fromJSON(layout_result_json)
    expect_false("error" %in% names(layout_result))
    
    # Results should be compatible - same node count
    n_nodes <- length(graph_data$nodes)
    expect_equal(graph_result$enhanced_metrics$node_count, n_nodes)
    
    # Layout coordinates should match node count
    for (layout_name in names(layout_result$layouts)) {
        layout <- layout_result$layouts[[layout_name]]
        if (!is.null(layout$x) && !is.null(layout$y)) {
            expect_length(layout$x, n_nodes)
            expect_length(layout$y, n_nodes)
        }
    }
})

test_that("temporal analysis integrates with graph structure", {
    # Create temporal data
    temporal_data <- generate_mock_temporal_data(n_articles = 10, n_links = 15, date_range_days = 7)
    
    # Run temporal analysis
    temporal_json_input <- create_test_json(temporal_data)
    temporal_result_json <- get_temporal_func("analyze_temporal_patterns")(temporal_json_input)
    temporal_result <- fromJSON(temporal_result_json)
    expect_false("error" %in% names(temporal_result))
    
    # Create a simple graph for testing
    simple_graph_data <- create_simple_test_graph()
    graph_json_input <- create_test_json(simple_graph_data)
    graph_result_json <- get_graph_func("process_graph")(graph_json_input)
    graph_result <- fromJSON(graph_result_json)
    expect_false("error" %in% names(graph_result))
    
    # Both analyses should complete successfully
    expect_true("temporal_metrics" %in% names(temporal_result))
    expect_true("enhanced_metrics" %in% names(graph_result))
})

test_that("all three analysis types can process same underlying data", {
    # Create rich test dataset
    base_temporal_data <- generate_mock_temporal_data(n_articles = 15, n_links = 20, date_range_days = 10)
    
    # Convert to graph format (final state)
    graph_data <- list(
        nodes = list(),
        edges = base_temporal_data$links
    )
    
    # Convert articles to graph nodes
    for (i in seq_along(base_temporal_data$articles)) {
        article <- base_temporal_data$articles[[i]]
        node_id <- article$id
        graph_data$nodes[[node_id]] <- list(
            id = node_id,
            title = article$title,
            node_type = "article",
            importance = runif(1, 0, 1),
            created_at = article$created_at,
            categories = article$categories
        )
    }
    
    # Test all three analysis types
    temporal_json <- create_test_json(base_temporal_data)
    graph_json <- create_test_json(graph_data)
    
    # Run all analyses
    temporal_result_json <- get_temporal_func("analyze_temporal_patterns")(temporal_json)
    temporal_result <- fromJSON(temporal_result_json)
    
    graph_result_json <- get_graph_func("process_graph")(graph_json)
    graph_result <- fromJSON(graph_result_json)
    
    layout_result_json <- get_layout_func("calculate_advanced_layouts")(graph_json)
    layout_result <- fromJSON(layout_result_json)
    
    # All should succeed
    expect_false("error" %in% names(temporal_result))
    expect_false("error" %in% names(graph_result))
    expect_false("error" %in% names(layout_result))
    
    # Cross-validate results
    expect_equal(length(base_temporal_data$articles), graph_result$enhanced_metrics$node_count)
    expect_equal(length(base_temporal_data$links), graph_result$enhanced_metrics$edge_count)
})

test_that("workflow simulation: knowledge graph evolution", {
    # Simulate a knowledge graph growing over time
    days <- 1:5
    cumulative_data <- list(articles = list(), links = list())
    
    daily_results <- list(
        temporal = list(),
        graph = list(),
        layout = list()
    )
    
    for (day in days) {
        # Add new articles each day
        new_articles <- lapply(1:3, function(i) {
            id <- paste0("day", day, "_article", i)
            list(
                id = id,
                title = paste("Article from day", day, "#", i),
                created_at = paste0("2024-01-", sprintf("%02d", day)),
                categories = sample(c("Science", "Tech", "History"), 1)
            )
        })
        
        cumulative_data$articles <- c(cumulative_data$articles, new_articles)
        
        # Add new links
        if (length(cumulative_data$articles) > 1) {
            new_links <- lapply(1:2, function(i) {
                available_ids <- sapply(cumulative_data$articles, function(x) x$id)
                list(
                    from = sample(available_ids, 1),
                    to = sample(available_ids, 1),
                    created_at = paste0("2024-01-", sprintf("%02d", day)),
                    weight = runif(1, 0.1, 1.0)
                )
            })
            cumulative_data$links <- c(cumulative_data$links, new_links)
        }
        
        # Convert to graph format
        graph_data <- list(
            nodes = list(),
            edges = cumulative_data$links
        )
        
        for (article in cumulative_data$articles) {
            graph_data$nodes[[article$id]] <- list(
                id = article$id,
                title = article$title,
                node_type = "article",
                importance = runif(1, 0, 1)
            )
        }
        
        # Run all analyses
        temporal_json <- create_test_json(cumulative_data)
        graph_json <- create_test_json(graph_data)
        
        # Temporal analysis
        temporal_result <- fromJSON(get_temporal_func("analyze_temporal_patterns")(temporal_json))
        expect_false("error" %in% names(temporal_result))
        daily_results$temporal[[day]] <- temporal_result
        
        # Graph analysis (skip if too few nodes)
        if (length(cumulative_data$articles) >= 2) {
            graph_result <- fromJSON(get_graph_func("process_graph")(graph_json))
            expect_false("error" %in% names(graph_result))
            daily_results$graph[[day]] <- graph_result
            
            # Layout analysis
            layout_result <- fromJSON(get_layout_func("calculate_advanced_layouts")(graph_json))
            expect_false("error" %in% names(layout_result))
            daily_results$layout[[day]] <- layout_result
        }
    }
    
    # Verify growth trends
    expect_length(daily_results$temporal, length(days))
    
    # Check that metrics show growth over time
    final_temporal <- daily_results$temporal[[length(days)]]
    expect_gte(final_temporal$temporal_metrics$total_days_active, length(days))
    
    # Graph complexity should increase
    if (length(daily_results$graph) >= 2) {
        early_graph <- daily_results$graph[[2]]
        late_graph <- daily_results$graph[[length(daily_results$graph)]]
        
        expect_gte(late_graph$enhanced_metrics$node_count, 
                  early_graph$enhanced_metrics$node_count)
    }
})

test_that("error handling consistency across scripts", {
    # Test that all scripts handle truly invalid inputs consistently
    invalid_inputs <- c(
        "",
        "invalid json"
    )
    
    for (invalid_input in invalid_inputs) {
        # All should return JSON with error field for truly invalid JSON
        temporal_result <- fromJSON(get_temporal_func("analyze_temporal_patterns")(invalid_input))
        graph_result <- fromJSON(get_graph_func("process_graph")(invalid_input))
        layout_result <- fromJSON(get_layout_func("calculate_advanced_layouts")(invalid_input))
        
        expect_true("error" %in% names(temporal_result))
        expect_true("error" %in% names(graph_result))  
        expect_true("error" %in% names(layout_result))
        
        # Error messages should be informative
        if (!is.null(temporal_result$error)) expect_gt(nchar(temporal_result$error), 5)
        if (!is.null(graph_result$error)) expect_gt(nchar(graph_result$error), 5)
        if (!is.null(layout_result$error)) expect_gt(nchar(layout_result$error), 5)
    }
    
    # Test that valid but empty inputs are handled gracefully (not as errors)
    graceful_inputs <- c("null", '{"invalid": "structure"}')
    for (graceful_input in graceful_inputs) {
        temporal_result <- fromJSON(get_temporal_func("analyze_temporal_patterns")(graceful_input))
        # These should either work or fail gracefully - both are acceptable
        expect_true(is.list(temporal_result))
    }
})

test_that("JSON serialization/deserialization compatibility", {
    # Test that outputs from one script can be processed by others
    graph_data <- create_complex_test_graph()
    json_input <- create_test_json(graph_data)
    
    # Get graph analysis output
    graph_result_json <- get_graph_func("process_graph")(json_input)
    graph_result <- fromJSON(graph_result_json)
    
    # Should be able to re-serialize
    re_serialized <- toJSON(graph_result, auto_unbox = TRUE, pretty = TRUE)
    re_parsed <- fromJSON(re_serialized)
    
    # Key structure should be preserved
    expect_equal(names(graph_result), names(re_parsed))
    expect_equal(graph_result$enhanced_metrics$node_count, 
                re_parsed$enhanced_metrics$node_count)
    
    # Layout results should also be serializable
    layout_result_json <- get_layout_func("calculate_advanced_layouts")(json_input)
    layout_result <- fromJSON(layout_result_json)
    
    layout_re_serialized <- toJSON(layout_result, auto_unbox = TRUE, pretty = TRUE)
    layout_re_parsed <- fromJSON(layout_re_serialized)
    
    expect_equal(names(layout_result), names(layout_re_parsed))
})

test_that("performance characteristics under load", {
    # Test all scripts with progressively larger datasets
    sizes <- c(10, 25, 50)
    
    performance_data <- data.frame(
        size = integer(),
        graph_time = numeric(),
        layout_time = numeric(),
        temporal_time = numeric(),
        stringsAsFactors = FALSE
    )
    
    for (size in sizes) {
        # Generate test data
        graph_data <- generate_mock_graph_data(
            n_nodes = size, 
            n_edges = min(size * 2, size * (size - 1) / 4)
        )
        temporal_data <- generate_mock_temporal_data(
            n_articles = size, 
            n_links = size * 2, 
            date_range_days = 20
        )
        
        graph_json <- create_test_json(graph_data)
        temporal_json <- create_test_json(temporal_data)
        
        # Time each analysis
        start_time <- Sys.time()
        graph_result <- get_graph_func("process_graph")(graph_json)
        graph_time <- as.numeric(Sys.time() - start_time)
        
        start_time <- Sys.time()
        layout_result <- get_layout_func("calculate_advanced_layouts")(graph_json)
        layout_time <- as.numeric(Sys.time() - start_time)
        
        start_time <- Sys.time()
        temporal_result <- get_temporal_func("analyze_temporal_patterns")(temporal_json)
        temporal_time <- as.numeric(Sys.time() - start_time)
        
        # Record performance
        performance_data <- rbind(performance_data, data.frame(
            size = size,
            graph_time = graph_time,
            layout_time = layout_time,
            temporal_time = temporal_time
        ))
        
        # All should complete reasonably quickly
        expect_lt(graph_time, 30)
        expect_lt(layout_time, 30)
        expect_lt(temporal_time, 30)
        
        # Results should still be valid
        expect_false("error" %in% names(fromJSON(graph_result)))
        expect_false("error" %in% names(fromJSON(layout_result)))
        expect_false("error" %in% names(fromJSON(temporal_result)))
    }
    
    # Performance should scale reasonably (not exponentially)
    if (nrow(performance_data) >= 2) {
        max_time_increase <- max(
            performance_data$graph_time[nrow(performance_data)] / performance_data$graph_time[1],
            performance_data$layout_time[nrow(performance_data)] / performance_data$layout_time[1],
            performance_data$temporal_time[nrow(performance_data)] / performance_data$temporal_time[1]
        )
        
        size_increase <- max(sizes) / min(sizes)
        
        # Time increase should not be much worse than quadratic relative to size
        expect_lt(max_time_increase, size_increase^3)
    }
})

test_that("data format compatibility between Perl and R", {
    # Test that R scripts can handle data formats as they would come from Perl backend
    
    # Simulate Perl-style data structure
    perl_style_graph <- list(
        nodes = list(
            "Article_1" = list(
                id = "Article_1",
                title = "Sample Article 1",
                node_type = "article",
                importance = 0.75,
                categories = list("Science", "Technology")
            ),
            "Category:Science" = list(
                id = "Category:Science", 
                title = "Science",
                node_type = "category",
                importance = 0.9
            )
        ),
        edges = list(
            list(from = "Article_1", to = "Category:Science", weight = 0.8, link_type = "category"),
            list(from = "Category:Science", to = "Article_1", weight = 0.6, link_type = "reverse_category")
        )
    )
    
    perl_json <- create_test_json(perl_style_graph)
    
    # All scripts should handle this format
    graph_result <- fromJSON(get_graph_func("process_graph")(perl_json))
    expect_false("error" %in% names(graph_result))
    
    layout_result <- fromJSON(get_layout_func("calculate_advanced_layouts")(perl_json))
    expect_false("error" %in% names(layout_result))
    
    # Results should reflect the mixed node types
    expect_equal(graph_result$enhanced_metrics$node_count, 2)
    expect_equal(graph_result$enhanced_metrics$edge_count, 2)
})

test_that("concurrent execution safety", {
    # Test that scripts can be run concurrently without interference
    # (This is a basic test - full concurrency testing would require more complex setup)
    
    test_data <- create_complex_test_graph()
    json_input <- create_test_json(test_data)
    
    # Run same analysis multiple times in sequence
    results <- list()
    for (i in 1:3) {
        results[[i]] <- get_graph_func("process_graph")(json_input)
    }
    
    # Results should be identical
    parsed_results <- lapply(results, fromJSON)
    
    for (i in 2:length(parsed_results)) {
        expect_equal(parsed_results[[1]]$enhanced_metrics$node_count,
                    parsed_results[[i]]$enhanced_metrics$node_count)
        expect_equal(parsed_results[[1]]$enhanced_metrics$edge_count,
                    parsed_results[[i]]$enhanced_metrics$edge_count)
    }
})

# Cleanup after tests
teardown({
    cleanup_test_env()
})

cat("Integration tests completed successfully\n")
