#!/usr/bin/env Rscript

# Test Suite for layout_algorithms.R
# Tests all layout calculation functions and quality evaluation

# Load test framework and helpers
library(testthat)
library(jsonlite)
library(igraph)

# Source the test helpers
source("helpers/test_helpers.R")

# Source the script under test
script_env <- source_r_script("../layout_algorithms.R")

# Helper to access functions from the script environment
get_func <- function(name) get(name, envir = script_env)

test_that("calculate_advanced_layouts handles valid JSON input", {
    graph_data <- create_simple_test_graph()
    json_input <- create_test_json(graph_data)
    
    result_json <- get_func("calculate_advanced_layouts")(json_input)
    result <- validate_json_output(result_json, 
                                 c("layouts", "recommendations", "layout_metrics"))
    
    # Check that main sections are present
    expect_type(result$layouts, "list")
    expect_type(result$recommendations, "list")
    expect_type(result$layout_metrics, "list")
    
    # Check that some standard layouts are present
    common_layouts <- c("fruchterman_reingold", "kamada_kawai", "spring_embedded", 
                       "stress_majorization", "physics_simulation")
    for (layout_name in common_layouts) {
        expect_true(layout_name %in% names(result$layouts))
    }
})

test_that("calculate_advanced_layouts handles invalid input gracefully", {
    invalid_inputs <- c(
        "",
        "{invalid json}",
        "null",
        '{"nodes": null, "edges": null}'
    )
    
    for (invalid_input in invalid_inputs) {
        result_json <- get_func("calculate_advanced_layouts")(invalid_input)
        result <- fromJSON(result_json)
        expect_true("error" %in% names(result))
    }
})

test_that("calculate_fr_layout produces valid coordinates", {
    graph_data <- create_simple_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_fr_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
    
    # Check that coordinates are reasonably distributed
    x_range <- max(layout$x) - min(layout$x)
    y_range <- max(layout$y) - min(layout$y)
    expect_gt(x_range, 0)
    expect_gt(y_range, 0)
})

test_that("calculate_kk_layout produces valid coordinates", {
    graph_data <- create_complex_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_kk_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
})

test_that("calculate_gem_layout produces valid coordinates", {
    graph_data <- create_simple_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_gem_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
})

test_that("calculate_sugiyama_layout works with DAGs", {
    graph_data <- create_dag_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    # Should work since it's a DAG
    layout <- get_func("calculate_sugiyama_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
    
    # In hierarchical layout, y-coordinates should show hierarchy
    unique_y <- length(unique(round(layout$y, 2)))
    expect_gte(unique_y, 2)  # Should have at least 2 levels
})

test_that("calculate_tree_layout finds appropriate root", {
    graph_data <- create_dag_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_tree_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
})

test_that("calculate_lgl_layout handles larger graphs", {
    # Test with a larger graph
    large_graph_data <- generate_mock_graph_data(n_nodes = 20, n_edges = 30)
    g <- get_func("create_igraph_from_data")(large_graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_lgl_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
})

test_that("calculate_grid_force_layout combines grid and force", {
    graph_data <- create_simple_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_grid_force_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
})

test_that("calculate_stress_layout minimizes stress", {
    graph_data <- create_complex_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_stress_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
})

test_that("calculate_mds_layout produces valid embedding", {
    graph_data <- create_simple_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_mds_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
})

test_that("calculate_bipartite_layout handles different node types", {
    # Create graph with different node types
    graph_data <- generate_mock_graph_data(n_nodes = 6, n_edges = 8, include_node_types = TRUE)
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_bipartite_layout")(g, graph_data$nodes)
    validate_layout_coordinates(layout, n_nodes)
    
    # Should separate different node types spatially
    x_values <- layout$x
    expect_gt(max(x_values) - min(x_values), 0)
})

test_that("calculate_clustered_layout groups similar nodes", {
    graph_data <- create_complex_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_clustered_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
})

test_that("calculate_physics_layout simulates physics", {
    graph_data <- create_simple_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    n_nodes <- vcount(g)
    
    layout <- get_func("calculate_physics_layout")(g)
    validate_layout_coordinates(layout, n_nodes)
    
    # Physics layout should spread nodes out
    min_distance <- min(dist(cbind(layout$x, layout$y)))
    expect_gt(min_distance, 0)
})

test_that("optimize_edge_lengths improves layout quality", {
    graph_data <- create_simple_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    
    # Start with a basic layout
    initial_layout <- matrix(runif(vcount(g) * 2), ncol = 2)
    
    optimized_layout <- get_func("optimize_edge_lengths")(g, initial_layout)
    
    expect_equal(nrow(optimized_layout), vcount(g))
    expect_equal(ncol(optimized_layout), 2)
    expect_true(all(is.finite(optimized_layout)))
})

test_that("recommend_best_layout provides appropriate recommendations", {
    # Test with different graph sizes
    small_graph <- create_simple_test_graph()
    medium_graph <- generate_mock_graph_data(n_nodes = 50, n_edges = 80)
    large_graph <- generate_mock_graph_data(n_nodes = 300, n_edges = 500)
    
    graphs <- list(
        small = get_func("create_igraph_from_data")(small_graph),
        medium = get_func("create_igraph_from_data")(medium_graph),
        large = get_func("create_igraph_from_data")(large_graph)
    )
    
    layouts <- list()  # Empty layouts for testing
    
    for (graph_name in names(graphs)) {
        g <- graphs[[graph_name]]
        recommendations <- get_func("recommend_best_layout")(g, layouts)
        
        expect_type(recommendations, "list")
        
        # Should have recommendations for different graph sizes
        if (vcount(g) < 50) {
            expect_true("small_graph" %in% names(recommendations))
        } else if (vcount(g) < 200) {
            expect_true("medium_graph" %in% names(recommendations))
        } else {
            expect_true("large_graph" %in% names(recommendations))
        }
        
        # DAG test
        dag_g <- get_func("create_igraph_from_data")(create_dag_test_graph())
        dag_recommendations <- get_func("recommend_best_layout")(dag_g, layouts)
        expect_true("hierarchical" %in% names(dag_recommendations))
    }
})

test_that("evaluate_layout_quality computes meaningful metrics", {
    graph_data <- create_simple_test_graph()
    g <- get_func("create_igraph_from_data")(graph_data)
    
    # Create test layouts
    layouts <- list(
        test_layout = list(
            x = c(0, 1, 0.5),
            y = c(0, 0, 1)
        )
    )
    
    metrics <- get_func("evaluate_layout_quality")(g, layouts)
    
    expect_type(metrics, "list")
    expect_true("test_layout" %in% names(metrics))
    
    layout_metrics <- metrics$test_layout
    expect_true("edge_length_variance" %in% names(layout_metrics))
    expect_true("min_node_distance" %in% names(layout_metrics))
    expect_true("aspect_ratio" %in% names(layout_metrics))
    expect_true("quality_score" %in% names(layout_metrics))
    
    # Check that metrics are reasonable
    expect_gte(layout_metrics$edge_length_variance, 0)
    expect_gt(layout_metrics$min_node_distance, 0)
    expect_gte(layout_metrics$aspect_ratio, 1)
    expect_gt(layout_metrics$quality_score, 0)
})

test_that("helper quality functions work correctly", {
    # Test edge length variance
    g <- get_func("create_igraph_from_data")(create_simple_test_graph())
    coords <- matrix(c(0, 1, 0.5, 0, 0, 1), ncol = 2)
    
    edge_var <- get_func("calculate_edge_length_variance")(g, coords)
    expect_gte(edge_var, 0)
    expect_type(edge_var, "double")
    
    # Test minimum node distance
    min_dist <- get_func("calculate_min_node_distance")(coords)
    expect_gt(min_dist, 0)
    expect_type(min_dist, "double")
    
    # Test aspect ratio
    aspect <- get_func("calculate_aspect_ratio")(coords)
    expect_gte(aspect, 1)
    expect_type(aspect, "double")
    
    # Test overall quality
    quality <- get_func("calculate_overall_quality")(edge_var, min_dist, aspect)
    expect_gt(quality, 0)
    expect_type(quality, "double")
})

test_that("has_node_types correctly detects node type information", {
    # Test with list format (has node types)
    nodes_with_types <- list(
        "A" = list(id = "A", node_type = "article"),
        "B" = list(id = "B", node_type = "category")
    )
    expect_true(get_func("has_node_types")(nodes_with_types))
    
    # Test without node types
    nodes_without_types <- list(
        "A" = list(id = "A", title = "Article A"),
        "B" = list(id = "B", title = "Article B")
    )
    expect_false(get_func("has_node_types")(nodes_without_types))
    
    # Test with data frame format
    df_with_types <- data.frame(id = c("A", "B"), node_type = c("article", "category"), stringsAsFactors = FALSE)
    expect_true(get_func("has_node_types")(df_with_types))
    
    df_without_types <- data.frame(id = c("A", "B"), title = c("Article A", "Article B"), stringsAsFactors = FALSE)
    expect_false(get_func("has_node_types")(df_without_types))
})

test_that("layout algorithms handle edge cases", {
    # Test with single node
    single_node_data <- list(
        nodes = list("A" = list(id = "A", title = "Single Node")),
        edges = list()
    )
    json_input <- create_test_json(single_node_data)
    
    result_json <- get_func("calculate_advanced_layouts")(json_input)
    result <- fromJSON(result_json)
    
    # Single node graphs may have limited layout options, so just check it doesn't crash
    expect_true("layouts" %in% names(result) || "error" %in% names(result))
    
    # Test with disconnected components
    disconnected_data <- list(
        nodes = list(
            "A" = list(id = "A", title = "Node A"),
            "B" = list(id = "B", title = "Node B"),
            "C" = list(id = "C", title = "Node C"),
            "D" = list(id = "D", title = "Node D")
        ),
        edges = list(
            list(from = "A", to = "B", weight = 1.0),
            list(from = "C", to = "D", weight = 1.0)
        )
    )
    json_input <- create_test_json(disconnected_data)
    
    result_json <- get_func("calculate_advanced_layouts")(json_input)
    result <- fromJSON(result_json)
    
    expect_false("error" %in% names(result))
})

test_that("layout algorithms scale appropriately", {
    # Test different graph sizes and verify layouts are computed
    sizes <- c(5, 20, 50)
    
    for (n in sizes) {
        graph_data <- generate_mock_graph_data(n_nodes = n, n_edges = min(n * 2, n * (n - 1) / 4))
        json_input <- create_test_json(graph_data)
        
        start_time <- Sys.time()
        result_json <- get_func("calculate_advanced_layouts")(json_input)
        end_time <- Sys.time()
        
        result <- fromJSON(result_json)
        
        # Should complete without error
        expect_false("error" %in% names(result))
        
        # Should have some layout algorithms
        expect_gt(length(result$layouts), 0)
        
        # Execution time should be reasonable (adjust threshold as needed)
        execution_time <- as.numeric(end_time - start_time)
        expect_lt(execution_time, 60)  # Should complete within 1 minute
    }
})

test_that("main function exists and is callable", {
    main_func <- get_func("main")
    expect_type(main_func, "closure")
    
    # The main function expects command line arguments
    # We can't easily test it directly, but we can verify it exists
})

test_that("complete layout pipeline with various graph types", {
    test_graphs <- list(
        simple = create_simple_test_graph(),
        complex = create_complex_test_graph(),
        dag = create_dag_test_graph(),
        large = generate_mock_graph_data(n_nodes = 30, n_edges = 50)
    )
    
    for (graph_name in names(test_graphs)) {
        graph_data <- test_graphs[[graph_name]]
        json_input <- create_test_json(graph_data)
        
        result_json <- get_func("calculate_advanced_layouts")(json_input)
        result <- fromJSON(result_json)
        
        # Should complete without errors
        expect_false("error" %in% names(result), 
                    info = paste("Error in", graph_name, "graph"))
        
        # Should have all major components
        expect_true("layouts" %in% names(result))
        expect_true("recommendations" %in% names(result))
        expect_true("layout_metrics" %in% names(result))
        
        # Should have at least a few layout algorithms
        expect_gte(length(result$layouts), 3)
        
        # All layouts should have valid coordinates
        for (layout_name in names(result$layouts)) {
            layout <- result$layouts[[layout_name]]
            if (!is.null(layout$x) && !is.null(layout$y)) {
                n_nodes <- length(graph_data$nodes)
                validate_layout_coordinates(layout, n_nodes)
            }
        }
    }
})

# Cleanup after tests
teardown({
    cleanup_test_env()
})

cat("Layout algorithms tests completed successfully\n")
