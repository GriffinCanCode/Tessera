#!/usr/bin/env Rscript

# Performance Benchmarking Suite for Tessera R Backend
# Measures current performance to track optimization improvements

suppressPackageStartupMessages({
    library(igraph)
    library(jsonlite)
    library(microbenchmark)
})

# Source existing scripts
source("tessera_logger.R")
source("graph_analysis.R")
source("layout_algorithms.R")
source("temporal_analysis.R")
source("learning_analytics.R")

# Benchmark configuration
BENCHMARK_CONFIG <- list(
    small_graph = list(nodes = 50, edges = 100),
    medium_graph = list(nodes = 200, edges = 500),
    large_graph = list(nodes = 1000, edges = 2000),
    iterations = 10
)

# Generate test data
generate_test_graph <- function(n_nodes, n_edges) {
    # Create realistic test graph
    nodes <- list()
    for (i in 1:n_nodes) {
        nodes[[paste0("node_", i)]] <- list(
            id = paste0("node_", i),
            title = paste("Node", i),
            node_type = sample(c("article", "concept", "person"), 1),
            importance = runif(1)
        )
    }
    
    # Generate edges with realistic weights
    edges <- data.frame(
        from = sample(names(nodes), n_edges, replace = TRUE),
        to = sample(names(nodes), n_edges, replace = TRUE),
        weight = runif(n_edges, 0.1, 1.0),
        stringsAsFactors = FALSE
    )
    
    # Remove self-loops and duplicates
    edges <- edges[edges$from != edges$to, ]
    edges <- unique(edges)
    
    return(list(nodes = nodes, edges = edges))
}

generate_temporal_data <- function(n_articles = 100, n_links = 200) {
    # Generate realistic temporal data
    base_date <- as.Date("2024-01-01")
    dates <- base_date + sort(sample(0:365, n_articles, replace = TRUE))
    
    articles <- data.frame(
        id = 1:n_articles,
        title = paste("Article", 1:n_articles),
        created_at = dates,
        categories = sample(c("Science", "Technology", "History", "Art"), n_articles, replace = TRUE),
        stringsAsFactors = FALSE
    )
    
    link_dates <- base_date + sort(sample(0:365, n_links, replace = TRUE))
    links <- data.frame(
        id = 1:n_links,
        from_id = sample(1:n_articles, n_links, replace = TRUE),
        to_id = sample(1:n_articles, n_links, replace = TRUE),
        created_at = link_dates,
        stringsAsFactors = FALSE
    )
    
    return(list(articles = articles, links = links))
}

generate_learning_data <- function(n_subjects = 10, n_content = 100) {
    subjects <- lapply(1:n_subjects, function(i) {
        list(
            id = i,
            name = paste("Subject", i)
        )
    })
    
    content <- lapply(1:n_content, function(i) {
        list(
            id = i,
            title = paste("Content", i),
            subject_ids = sample(1:n_subjects, sample(1:3, 1)),
            completion_percentage = sample(0:100, 1),
            difficulty_level = sample(1:5, 1),
            content_type = sample(c("article", "video", "book"), 1),
            content = paste(rep("word", sample(50:500, 1)), collapse = " ")
        )
    })
    
    return(list(subjects = subjects, content = content))
}

# Benchmark functions
benchmark_graph_analysis <- function() {
    cat("📊 Benchmarking Graph Analysis...\n")
    
    results <- list()
    
    for (size_name in names(BENCHMARK_CONFIG)[1:3]) {
        config <- BENCHMARK_CONFIG[[size_name]]
        cat(sprintf("  Testing %s (%d nodes, %d edges)...\n", 
                   size_name, config$nodes, config$edges))
        
        # Generate test data
        graph_data <- generate_test_graph(config$nodes, config$edges)
        json_input <- toJSON(graph_data, auto_unbox = TRUE)
        
        # Benchmark main process_graph function
        timing <- microbenchmark(
            process_graph(json_input),
            times = BENCHMARK_CONFIG$iterations,
            unit = "ms"
        )
        
        results[[size_name]] <- list(
            nodes = config$nodes,
            edges = config$edges,
            mean_time_ms = mean(timing$time) / 1e6,
            median_time_ms = median(timing$time) / 1e6,
            min_time_ms = min(timing$time) / 1e6,
            max_time_ms = max(timing$time) / 1e6
        )
        
        cat(sprintf("    Mean: %.2f ms, Median: %.2f ms\n", 
                   results[[size_name]]$mean_time_ms,
                   results[[size_name]]$median_time_ms))
    }
    
    return(results)
}

benchmark_layout_algorithms <- function() {
    cat("📊 Benchmarking Layout Algorithms...\n")
    
    results <- list()
    
    for (size_name in names(BENCHMARK_CONFIG)[1:3]) {
        config <- BENCHMARK_CONFIG[[size_name]]
        cat(sprintf("  Testing %s (%d nodes, %d edges)...\n", 
                   size_name, config$nodes, config$edges))
        
        # Generate test data
        graph_data <- generate_test_graph(config$nodes, config$edges)
        json_input <- toJSON(graph_data, auto_unbox = TRUE)
        
        # Benchmark layout calculation
        timing <- microbenchmark(
            calculate_advanced_layouts(json_input),
            times = max(1, BENCHMARK_CONFIG$iterations / 2),  # Fewer iterations for expensive operations
            unit = "ms"
        )
        
        results[[size_name]] <- list(
            nodes = config$nodes,
            edges = config$edges,
            mean_time_ms = mean(timing$time) / 1e6,
            median_time_ms = median(timing$time) / 1e6
        )
        
        cat(sprintf("    Mean: %.2f ms, Median: %.2f ms\n", 
                   results[[size_name]]$mean_time_ms,
                   results[[size_name]]$median_time_ms))
    }
    
    return(results)
}

benchmark_temporal_analysis <- function() {
    cat("📊 Benchmarking Temporal Analysis...\n")
    
    # Generate test data
    temporal_data <- generate_temporal_data(200, 400)
    json_input <- toJSON(list(content = temporal_data), auto_unbox = TRUE)
    
    # Benchmark temporal analysis
    timing <- microbenchmark(
        analyze_learning_patterns(json_input),
        times = BENCHMARK_CONFIG$iterations,
        unit = "ms"
    )
    
    result <- list(
        mean_time_ms = mean(timing$time) / 1e6,
        median_time_ms = median(timing$time) / 1e6
    )
    
    cat(sprintf("  Mean: %.2f ms, Median: %.2f ms\n", 
               result$mean_time_ms, result$median_time_ms))
    
    return(result)
}

benchmark_learning_analytics <- function() {
    cat("📊 Benchmarking Learning Analytics...\n")
    
    # Generate test data
    learning_data <- generate_learning_data(10, 100)
    json_input <- toJSON(learning_data, auto_unbox = TRUE)
    
    # Benchmark learning analytics
    timing <- microbenchmark(
        analyze_learning_data(json_input),
        times = BENCHMARK_CONFIG$iterations,
        unit = "ms"
    )
    
    result <- list(
        mean_time_ms = mean(timing$time) / 1e6,
        median_time_ms = median(timing$time) / 1e6
    )
    
    cat(sprintf("  Mean: %.2f ms, Median: %.2f ms\n", 
               result$mean_time_ms, result$median_time_ms))
    
    return(result)
}

# Memory usage profiling
profile_memory_usage <- function() {
    cat("💾 Profiling Memory Usage...\n")
    
    # Test with medium-sized graph
    graph_data <- generate_test_graph(200, 500)
    json_input <- toJSON(graph_data, auto_unbox = TRUE)
    
    # Measure memory before
    gc()
    mem_before <- sum(gc()[, 2])
    
    # Run analysis
    result <- process_graph(json_input)
    
    # Measure memory after
    mem_after <- sum(gc()[, 2])
    mem_used <- mem_after - mem_before
    
    cat(sprintf("  Memory used: %.2f MB\n", mem_used))
    
    return(list(memory_mb = mem_used))
}

# Main benchmark runner
run_full_benchmark <- function() {
    cat("🚀 Starting Tessera R Backend Performance Benchmark\n")
    cat("=" %R% 60, "\n")
    
    start_time <- Sys.time()
    
    # Run all benchmarks
    results <- list(
        timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
        system_info = list(
            r_version = R.version.string,
            platform = R.version$platform,
            cores = parallel::detectCores()
        ),
        graph_analysis = benchmark_graph_analysis(),
        layout_algorithms = benchmark_layout_algorithms(),
        temporal_analysis = benchmark_temporal_analysis(),
        learning_analytics = benchmark_learning_analytics(),
        memory_profile = profile_memory_usage()
    )
    
    end_time <- Sys.time()
    total_time <- as.numeric(difftime(end_time, start_time, units = "secs"))
    
    cat("\n📈 Benchmark Summary\n")
    cat("=" %R% 30, "\n")
    cat(sprintf("Total benchmark time: %.2f seconds\n", total_time))
    
    # Print summary table
    cat("\nPerformance Summary (median times):\n")
    cat("Component                | Small    | Medium   | Large\n")
    cat("-------------------------|----------|----------|----------\n")
    
    ga <- results$graph_analysis
    cat(sprintf("Graph Analysis           | %6.1f ms | %6.1f ms | %6.1f ms\n",
               ga$small_graph$median_time_ms,
               ga$medium_graph$median_time_ms,
               ga$large_graph$median_time_ms))
    
    la <- results$layout_algorithms
    cat(sprintf("Layout Algorithms        | %6.1f ms | %6.1f ms | %6.1f ms\n",
               la$small_graph$median_time_ms,
               la$medium_graph$median_time_ms,
               la$large_graph$median_time_ms))
    
    cat(sprintf("Temporal Analysis        | %6.1f ms |\n", results$temporal_analysis$median_time_ms))
    cat(sprintf("Learning Analytics       | %6.1f ms |\n", results$learning_analytics$median_time_ms))
    cat(sprintf("Memory Usage             | %6.1f MB |\n", results$memory_profile$memory_mb))
    
    # Save results
    results_file <- paste0("benchmark_results_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".json")
    writeLines(toJSON(results, pretty = TRUE, auto_unbox = TRUE), results_file)
    cat(sprintf("\n📁 Results saved to: %s\n", results_file))
    
    return(results)
}

# Utility function for string repetition
`%R%` <- function(x, n) paste(rep(x, n), collapse = "")

# Main execution
main <- function() {
    args <- commandArgs(trailingOnly = TRUE)
    
    if (length(args) > 0 && args[1] == "--component") {
        # Run specific component benchmark
        component <- args[2]
        switch(component,
               "graph" = benchmark_graph_analysis(),
               "layout" = benchmark_layout_algorithms(),
               "temporal" = benchmark_temporal_analysis(),
               "learning" = benchmark_learning_analytics(),
               "memory" = profile_memory_usage(),
               {
                   cat("Unknown component. Available: graph, layout, temporal, learning, memory\n")
                   quit(status = 1)
               })
    } else {
        # Run full benchmark suite
        run_full_benchmark()
    }
}

if (sys.nframe() == 0) {
    main()
}
