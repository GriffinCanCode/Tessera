#!/usr/bin/env Rscript

# Test Suite for graph_analysis.R
# Tests all major functions in the graph analysis script

# Load test framework and helpers
library(testthat)
library(jsonlite)
library(igraph)

# Source the test helpers
source("helpers/test_helpers.R")

# Source the script under test
script_env <- source_r_script("../r_scripts/graph_analysis.R")

# Helper to access functions from the script environment
get_func <- function(name) get(name, envir = script_env)

test_that("process_graph handles valid JSON input correctly", {
    # Test with simple graph
    graph_data <- create_simple_test_graph()
    json_input <- create_test_json(graph_data)
    
    result_json <- get_func("process_graph")(json_input)
    result <- validate_json_output(result_json, 
                                 c("enhanced_metrics", "communities", "layouts", 
                                   "centrality_measures", "cluster_analysis"))
    
    # Check that all sections are present and non-empty
    expect_type(result$enhanced_metrics, "list")
    expect_type(result$communities, "list")
    expect_type(result$layouts, "list")
    expect_type(result$centrality_measures, "list")
    expect_type(result$cluster_analysis, "list")
})

test_that("process_graph handles invalid JSON input gracefully", {
    invalid_inputs <- c(
        "",
        "{invalid json}",
        "null",
        '{"nodes": null, "edges": null}',
        '{"nodes": [], "edges": []}'
    )
    
    for (invalid_input in invalid_inputs) {
        result_json <- get_func("process_graph")(invalid_input)
        result <- fromJSON(result_json)
        expect_true("error" %in% names(result))
    }
})

test_that("create_igraph_from_data creates valid igraph objects", {
    graph_data <- create_simple_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    
    # Check igraph object properties
    expect_s3_class(g, "igraph")
    expect_equal(vcount(g), 3)
    expect_equal(ecount(g), 3)
    
    # Check node attributes
    expect_true("title" %in% vertex_attr_names(g))
    expect_true("node_type" %in% vertex_attr_names(g))
    expect_true("importance" %in% vertex_attr_names(g))
    
    # Check edge attributes
    expect_true("weight" %in% edge_attr_names(g))
})

test_that("create_igraph_from_data handles missing data", {
    # Test with missing nodes
    invalid_data1 <- list(edges = list(list(from = "A", to = "B")))
    expect_error(get_func("create_igraph_from_data")(invalid_data1))
    
    # Test with missing edges
    invalid_data2 <- list(nodes = list("A" = list(id = "A")))
    expect_error(get_func("create_igraph_from_data")(invalid_data2))
})

test_that("calculate_enhanced_metrics produces valid metrics", {
    graph_data <- create_complex_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    
    metrics <- get_func("calculate_enhanced_metrics")(g, graph_data$nodes)
    
    validate_graph_metrics(metrics)
    
    # Test specific metric ranges
    expect_gte(metrics$node_count, 1)
    expect_gte(metrics$edge_count, 0)
    expect_gte(metrics$density, 0)
    expect_lte(metrics$density, 1)
    
    # Test degree statistics
    expect_gte(metrics$degree_stats$mean_degree, 0)
    expect_gte(metrics$degree_stats$max_degree, 0)
})

test_that("calculate_centrality_measures computes all centrality types", {
    graph_data <- create_complex_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    centrality <- get_func("calculate_centrality_measures")(g)
    
    validate_centrality_measures(centrality, n_nodes)
    
    # Test that PageRank values sum to approximately 1
    pagerank_sum <- sum(centrality$pagerank, na.rm = TRUE)
    expect_true(abs(pagerank_sum - 1.0) < 0.01)
    
    # Test that all centrality values are non-negative
    expect_true(all(centrality$betweenness >= 0, na.rm = TRUE))
    expect_true(all(centrality$degree_in >= 0))
    expect_true(all(centrality$degree_out >= 0))
    expect_true(all(centrality$degree_total >= 0))
})

test_that("detect_communities finds reasonable community structures", {
    graph_data <- create_complex_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    
    communities <- get_func("detect_communities")(g)
    
    # Check that all community detection methods are present
    expected_methods <- c("louvain", "walktrap", "fast_greedy", 
                         "label_propagation", "leading_eigenvector")
    for (method in expected_methods) {
        expect_true(method %in% names(communities))
        
        method_result <- communities[[method]]
        expect_true("membership" %in% names(method_result))
        expect_true("modularity" %in% names(method_result))
        expect_true("communities_count" %in% names(method_result))
        
        # Check membership vector length
        expect_length(method_result$membership, vcount(g))
        
        # Check that modularity is reasonable
        expect_gte(method_result$modularity, -1)
        expect_lte(method_result$modularity, 1)
        
        # Check community count is reasonable
        expect_gte(method_result$communities_count, 1)
        expect_lte(method_result$communities_count, vcount(g))
    }
})

test_that("calculate_layouts generates multiple layout algorithms", {
    graph_data <- create_simple_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layouts <- get_func("calculate_layouts")(g)
    
    # Check that common layout algorithms are present
    common_layouts <- c("fruchterman_reingold", "kamada_kawai", "gem", "circle")
    for (layout_name in common_layouts) {
        expect_true(layout_name %in% names(layouts))
        validate_layout_coordinates(layouts[[layout_name]], n_nodes)
    }
})

test_that("calculate_layouts handles DAG-specific layouts", {
    graph_data <- create_dag_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layouts <- get_func("calculate_layouts")(g)
    
    # DAG should have Sugiyama layout
    expect_true("sugiyama" %in% names(layouts))
    validate_layout_coordinates(layouts$sugiyama, n_nodes)
})

test_that("analyze_clusters performs cluster analysis", {
    graph_data <- create_complex_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    
    cluster_analysis <- get_func("analyze_clusters")(g)
    
    # Check k-cores analysis
    expect_true("k_cores" %in% names(cluster_analysis))
    expect_true("max_k_core" %in% names(cluster_analysis))
    expect_length(cluster_analysis$k_cores, vcount(g))
    expect_gte(cluster_analysis$max_k_core, 0)
    
    # Check clique analysis
    expect_true("max_cliques_count" %in% names(cluster_analysis))
    expect_true("largest_clique_size" %in% names(cluster_analysis))
    expect_gte(cluster_analysis$max_cliques_count, 0)
    expect_gte(cluster_analysis$largest_clique_size, 0)
})

test_that("calculate_skewness computes skewness correctly", {
    # Test with known data
    normal_data <- c(1, 2, 3, 4, 5, 4, 3, 2, 1)  # Symmetric
    right_skewed <- c(1, 1, 1, 2, 2, 3, 5, 8, 10) # Right skewed
    
    normal_skew <- get_func("calculate_skewness")(normal_data)
    right_skew <- get_func("calculate_skewness")(right_skewed)
    
    # Normal distribution should have skewness near 0
    expect_true(abs(normal_skew) < 1)
    
    # Right skewed should be positive
    expect_gt(right_skew, 0)
    
    # Test edge cases
    expect_true(is.na(get_func("calculate_skewness")(c(1))))  # Too few points
    expect_true(is.na(get_func("calculate_skewness")(c(1, 1, 1))))  # No variance
})

test_that("null coalescing operator works correctly", {
    null_coalesce <- get_func("%||%")
    
    expect_equal(null_coalesce(NULL, "default"), "default")
    expect_equal(null_coalesce(NA, "default"), "default")
    expect_equal(null_coalesce("value", "default"), "value")
    expect_equal(null_coalesce(c(), "default"), "default")
    expect_equal(null_coalesce(c(1, 2, 3), "default"), c(1, 2, 3))
})

test_that("main function handles command line arguments", {
    # This test checks the command line interface
    # We can't easily test the actual command line execution,
    # but we can test that the function exists and has the right structure
    main_func <- get_func("main")
    expect_type(main_func, "closure")
})

test_that("end-to-end graph analysis workflow", {
    # Test complete workflow with multiple graph types
    test_graphs <- list(
        simple = create_simple_test_graph(),
        complex = create_complex_test_graph(),
        dag = create_dag_test_graph()
    )
    
    for (graph_name in names(test_graphs)) {
        graph_data <- test_graphs[[graph_name]]
        json_input <- create_test_json(graph_data)
        
        # Test complete pipeline
        result_json <- get_func("process_graph")(json_input)
        result <- fromJSON(result_json)
        
        # Verify no errors occurred
        expect_false("error" %in% names(result))
        
        # Verify all major sections are present
        expect_true("enhanced_metrics" %in% names(result))
        expect_true("communities" %in% names(result))
        expect_true("layouts" %in% names(result))
        expect_true("centrality_measures" %in% names(result))
        expect_true("cluster_analysis" %in% names(result))
    }
})

test_that("performance with larger graphs", {
    # Test with a moderately sized graph (50 nodes)
    large_graph_data <- generate_mock_graph_data(n_nodes = 50, n_edges = 100)
    json_input <- create_test_json(large_graph_data)
    
    # Time the execution (should complete reasonably quickly)
    start_time <- Sys.time()
    result_json <- get_func("process_graph")(json_input)
    end_time <- Sys.time()
    
    execution_time <- as.numeric(end_time - start_time)
    
    # Should complete within reasonable time (< 30 seconds)
    expect_lt(execution_time, 30)
    
    # Should still produce valid output
    result <- fromJSON(result_json)
    expect_false("error" %in% names(result))
    expect_equal(result$enhanced_metrics$node_count, 50)
})

# Cleanup after tests
teardown({
    cleanup_test_env()
})

cat("Graph analysis tests completed successfully\n")
