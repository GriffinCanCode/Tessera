#!/usr/bin/env Rscript

# Test Helper Functions for Tessera R Scripts
# Provides mock data generators and utility functions for testing

suppressPackageStartupMessages({
    library(testthat)
    library(jsonlite)
    library(igraph)
})

# Generate mock graph data in the format expected by the R scripts
generate_mock_graph_data <- function(n_nodes = 10, n_edges = 15, include_weights = TRUE, include_node_types = TRUE) {
    # Generate nodes
    node_ids <- paste0("node_", 1:n_nodes)
    
    nodes <- list()
    for (i in 1:n_nodes) {
        node_id <- node_ids[i]
        nodes[[node_id]] <- list(
            id = node_id,
            title = paste("Article", i),
            node_type = if (include_node_types) sample(c("article", "category", "disambiguation"), 1) else "article",
            importance = runif(1, 0, 1)
        )
    }
    
    # Generate edges
    edges <- list()
    for (i in 1:n_edges) {
        from_node <- sample(node_ids, 1)
        to_node <- sample(setdiff(node_ids, from_node), 1)
        
        edges[[i]] <- list(
            from = from_node,
            to = to_node,
            weight = if (include_weights) runif(1, 0.1, 1.0) else 1.0,
            link_type = sample(c("internal", "category", "redirect"), 1)
        )
    }
    
    return(list(nodes = nodes, edges = edges))
}

# Generate mock temporal data for temporal analysis
generate_mock_temporal_data <- function(n_articles = 20, n_links = 30, date_range_days = 30) {
    start_date <- as.Date("2024-01-01")
    end_date <- start_date + date_range_days
    
    # Generate articles with timestamps
    articles <- list()
    for (i in 1:n_articles) {
        created_at <- sample(seq(start_date, end_date, by = "day"), 1)
        articles[[i]] <- list(
            id = paste0("article_", i),
            title = paste("Article", i),
            created_at = format(created_at, "%Y-%m-%d"),
            categories = sample(c("Science", "History", "Technology", "Culture", "Geography"), 
                              sample(1:3, 1))
        )
    }
    
    # Generate links with timestamps
    links <- list()
    for (i in 1:n_links) {
        created_at <- sample(seq(start_date, end_date, by = "day"), 1)
        links[[i]] <- list(
            from = paste0("article_", sample(1:n_articles, 1)),
            to = paste0("article_", sample(1:n_articles, 1)),
            created_at = format(created_at, "%Y-%m-%d"),
            weight = runif(1, 0.1, 1.0)
        )
    }
    
    return(list(articles = articles, links = links))
}

# Create a simple test graph (triangle with 3 nodes)
create_simple_test_graph <- function() {
    nodes <- list(
        "A" = list(id = "A", title = "Node A", node_type = "article", importance = 0.8),
        "B" = list(id = "B", title = "Node B", node_type = "article", importance = 0.6),
        "C" = list(id = "C", title = "Node C", node_type = "category", importance = 0.4)
    )
    
    edges <- list(
        list(from = "A", to = "B", weight = 0.9),
        list(from = "B", to = "C", weight = 0.7),
        list(from = "C", to = "A", weight = 0.5)
    )
    
    return(list(nodes = nodes, edges = edges))
}

# Create a complex test graph (complete graph with 5 nodes)
create_complex_test_graph <- function() {
    n <- 5
    node_ids <- LETTERS[1:n]
    
    nodes <- list()
    for (i in 1:n) {
        node_id <- node_ids[i]
        nodes[[node_id]] <- list(
            id = node_id,
            title = paste("Node", node_id),
            node_type = sample(c("article", "category", "disambiguation"), 1),
            importance = runif(1, 0, 1)
        )
    }
    
    edges <- list()
    edge_count <- 1
    for (i in 1:(n-1)) {
        for (j in (i+1):n) {
            edges[[edge_count]] <- list(
                from = node_ids[i],
                to = node_ids[j],
                weight = runif(1, 0.1, 1.0)
            )
            edge_count <- edge_count + 1
            
            # Add reverse edge for some connections
            if (runif(1) > 0.5) {
                edges[[edge_count]] <- list(
                    from = node_ids[j],
                    to = node_ids[i],
                    weight = runif(1, 0.1, 1.0)
                )
                edge_count <- edge_count + 1
            }
        }
    }
    
    return(list(nodes = nodes, edges = edges))
}

# Create a DAG (Directed Acyclic Graph) for testing hierarchical layouts
create_dag_test_graph <- function() {
    nodes <- list(
        "root" = list(id = "root", title = "Root Node", node_type = "category", importance = 1.0),
        "level1_a" = list(id = "level1_a", title = "Level 1A", node_type = "article", importance = 0.8),
        "level1_b" = list(id = "level1_b", title = "Level 1B", node_type = "article", importance = 0.7),
        "level2_a" = list(id = "level2_a", title = "Level 2A", node_type = "article", importance = 0.6),
        "level2_b" = list(id = "level2_b", title = "Level 2B", node_type = "article", importance = 0.5),
        "level2_c" = list(id = "level2_c", title = "Level 2C", node_type = "article", importance = 0.4)
    )
    
    edges <- list(
        list(from = "root", to = "level1_a", weight = 0.9),
        list(from = "root", to = "level1_b", weight = 0.8),
        list(from = "level1_a", to = "level2_a", weight = 0.7),
        list(from = "level1_a", to = "level2_b", weight = 0.6),
        list(from = "level1_b", to = "level2_c", weight = 0.5)
    )
    
    return(list(nodes = nodes, edges = edges))
}

# Helper function to validate JSON output structure
validate_json_output <- function(json_string, expected_keys) {
    expect_type(json_string, "character")
    expect_true(nchar(json_string) > 0)
    
    # Parse JSON and check structure
    result <- fromJSON(json_string)
    
    for (key in expected_keys) {
        expect_true(key %in% names(result), 
                   info = paste("Missing expected key:", key))
    }
    
    return(result)
}

# Helper function to validate graph metrics structure
validate_graph_metrics <- function(metrics) {
    required_fields <- c("node_count", "edge_count", "density", "diameter", 
                        "transitivity", "degree_stats")
    
    for (field in required_fields) {
        expect_true(field %in% names(metrics),
                   info = paste("Missing required metric:", field))
    }
    
    # Check numeric values are reasonable
    expect_gte(metrics$node_count, 0)
    expect_gte(metrics$edge_count, 0)
    expect_gte(metrics$density, 0)
    expect_lte(metrics$density, 1)
    
    # Check degree stats structure
    degree_stats_fields <- c("mean_degree", "median_degree", "max_degree")
    for (field in degree_stats_fields) {
        expect_true(field %in% names(metrics$degree_stats),
                   info = paste("Missing degree stat:", field))
    }
}

# Helper function to validate centrality measures
validate_centrality_measures <- function(centrality, n_nodes) {
    required_measures <- c("pagerank", "betweenness", "closeness", "eigenvector")
    
    for (measure in required_measures) {
        expect_true(measure %in% names(centrality),
                   info = paste("Missing centrality measure:", measure))
        
        measure_values <- centrality[[measure]]
        expect_length(measure_values, n_nodes)
        expect_type(measure_values, "double")
        expect_true(all(is.finite(measure_values) | is.na(measure_values)))
    }
}

# Helper function to validate layout coordinates
validate_layout_coordinates <- function(layout, n_nodes) {
    expect_true("x" %in% names(layout))
    expect_true("y" %in% names(layout))
    expect_length(layout$x, n_nodes)
    expect_length(layout$y, n_nodes)
    # Accept both integer and double types for coordinates
    expect_true(is.numeric(layout$x))
    expect_true(is.numeric(layout$y))
    expect_true(all(is.finite(layout$x)))
    expect_true(all(is.finite(layout$y)))
}

# Helper function to validate temporal analysis structure
validate_temporal_analysis <- function(analysis) {
    required_sections <- c("growth_analysis", "discovery_timeline", 
                          "knowledge_evolution", "learning_phases")
    
    for (section in required_sections) {
        expect_true(section %in% names(analysis),
                   info = paste("Missing temporal analysis section:", section))
    }
    
    # Validate growth analysis structure
    growth <- analysis$growth_analysis
    expect_true("dates" %in% names(growth))
    expect_true("articles_cumulative" %in% names(growth))
    expect_true("links_cumulative" %in% names(growth))
}

# Helper function to create test JSON input
create_test_json <- function(graph_data) {
    return(toJSON(graph_data, auto_unbox = TRUE))
}

# Helper function to source R scripts safely
source_r_script <- function(script_path) {
    if (!file.exists(script_path)) {
        stop(paste("Script not found:", script_path))
    }
    
    # Source in a new environment to avoid conflicts
    script_env <- new.env()
    source(script_path, local = script_env)
    
    return(script_env)
}

# Helper function to test error handling
test_error_handling <- function(func, invalid_inputs, error_pattern = NULL) {
    for (input in invalid_inputs) {
        if (is.null(error_pattern)) {
            expect_error(func(input))
        } else {
            expect_error(func(input), error_pattern)
        }
    }
}

# Clean up test environment
cleanup_test_env <- function() {
    # Remove temporary files if any were created
    temp_files <- list.files(pattern = "^temp_test_", full.names = TRUE)
    if (length(temp_files) > 0) {
        file.remove(temp_files)
    }
}

cat("Test helpers loaded successfully\n")
