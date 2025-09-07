#!/usr/bin/env Rscript

# Advanced Graph Analysis Functions for Tessera
# Integrates with Perl backend for enhanced knowledge graph analysis

# Load Tessera logger first
tryCatch({
    source("tessera_logger.R")
}, error = function(e) {
    # Try relative path for when sourced from tests
    tryCatch({
        source("../../tessera_logger.R")
    }, error = function(e2) {
        # Fallback: create minimal logging functions
        log_package_load <- function(pkg) message(paste("Loading:", pkg))
        log_info <- function(msg) message(paste("[INFO]", msg))
        log_warning <- function(msg) message(paste("[WARNING]", msg))
        log_error <- function(msg) message(paste("[ERROR]", msg))
        log_r_startup <- function(script) message(paste("Starting:", script))
        
        # Create tessera_logger object
        tessera_logger <<- list(
            log_analysis_start = function(op) message(paste("Starting:", op)),
            log_import_operation = function(op) message(paste("Import:", op)),
            log_data_processing = function(op, det = "") message(paste("Processing:", op, det)),
            log_analysis_complete = function(op, det = "") message(paste("Complete:", op, det)),
            log_analysis_error = function(op, err = "") message(paste("Error in", op, ":", err))
        )
    })
})

# Load Zig optimizations (with fallback)
tryCatch({
    source("../zig-backend/lib/ffi/r/zig_vector_ops.R")
    source("../zig-backend/lib/ffi/r/zig_graph_ops.R")
}, error = function(e) {
    message("Zig optimizations not available, using R implementations")
})

# Load required libraries
suppressPackageStartupMessages({
    log_package_load("igraph")
    library(igraph)
    log_package_load("networkD3")
    library(networkD3)
    log_package_load("visNetwork")
    library(visNetwork)
    log_package_load("jsonlite")
    library(jsonlite)
})

# Log script startup
log_r_startup("graph_analysis.R")

# Main function to process graph data from JSON input
process_graph <- function(json_input) {
    tessera_logger$log_analysis_start("Graph Processing")
    
    tryCatch({
        # Parse JSON input from Perl
        tessera_logger$log_import_operation("JSON input")
        graph_data <- fromJSON(json_input)
        
        tessera_logger$log_data_processing("parsed", 
                                         paste("nodes:", length(graph_data$nodes), 
                                               "edges:", length(graph_data$edges)))
        
        # Create igraph object
        g <- create_igraph_from_data(graph_data)
        
        # Calculate enhanced metrics
        enhanced_metrics <- calculate_enhanced_metrics(g, graph_data$nodes)
        
        # Detect communities
        communities <- detect_communities(g)
        
        # Calculate advanced layouts
        layouts <- calculate_layouts(g)
        
        # Return results as JSON
        result <- list(
            enhanced_metrics = enhanced_metrics,
            communities = communities,
            layouts = layouts,
            centrality_measures = calculate_centrality_measures(g),
            cluster_analysis = analyze_clusters(g)
        )
        
        return(toJSON(result, pretty = TRUE, auto_unbox = TRUE))
        
    }, error = function(e) {
        error_result <- list(error = paste("R Analysis Error:", e$message))
        return(toJSON(error_result, auto_unbox = TRUE))
    })
}

# Create igraph object from parsed data
create_igraph_from_data <- function(graph_data) {
    # Extract nodes and edges
    nodes <- graph_data$nodes
    edges <- graph_data$edges
    
    if (is.null(nodes) || is.null(edges)) {
        stop("Invalid graph data: missing nodes or edges")
    }
    
    # Convert nodes list to data frame if needed
    if (is.list(nodes)) {
        node_ids <- names(nodes)
        node_df <- data.frame(
            id = node_ids,
            stringsAsFactors = FALSE
        )
        
        # Add node attributes
        for (attr in c("title", "node_type", "importance")) {
            values <- sapply(nodes, function(x) x[[attr]] %||% NA)
            node_df[[attr]] <- values
        }
    } else {
        node_df <- nodes
    }
    
    # Convert edges to data frame
    if (is.data.frame(edges)) {
        edge_df <- edges
        # Ensure weight column exists
        if (!"weight" %in% names(edge_df)) {
            edge_df$weight <- 1.0
        }
    } else if (is.list(edges)) {
        edge_df <- data.frame(
            from = sapply(edges, function(x) x$from),
            to = sapply(edges, function(x) x$to),
            weight = sapply(edges, function(x) x$weight %||% 1),
            stringsAsFactors = FALSE
        )
    } else {
        stop("Invalid edges format")
    }
    
    # Create igraph object
    g <- graph_from_data_frame(edge_df, directed = TRUE, vertices = node_df)
    
    return(g)
}

# Calculate enhanced metrics beyond basic Perl implementation
calculate_enhanced_metrics <- function(g, nodes) {
    metrics <- list()
    
    # Basic graph metrics
    metrics$node_count <- vcount(g)
    metrics$edge_count <- ecount(g)
    metrics$density <- edge_density(g)
    metrics$diameter <- diameter(g, directed = TRUE)
    metrics$radius <- radius(g)
    metrics$transitivity <- transitivity(g)
    metrics$reciprocity <- reciprocity(g)
    
    # Degree statistics
    degrees <- degree(g, mode = "all")
    in_degrees <- degree(g, mode = "in")
    out_degrees <- degree(g, mode = "out")
    
    metrics$degree_stats <- list(
        mean_degree = mean(degrees),
        median_degree = median(degrees),
        max_degree = max(degrees),
        degree_variance = var(degrees),
        degree_skewness = calculate_skewness(degrees)
    )
    
    # Connectivity metrics
    metrics$is_connected <- is_connected(g, mode = "weak")
    metrics$components <- components(g, mode = "weak")$no
    metrics$articulation_points <- length(articulation_points(g))
    
    # Small-world properties
    metrics$average_path_length <- mean_distance(g, directed = TRUE)
    metrics$clustering_coefficient <- transitivity(g, type = "global")
    
    return(metrics)
}

# Advanced centrality measures with Zig acceleration and vectorization
calculate_centrality_measures <- function(g) {
    centrality <- list()
    n <- vcount(g)
    
    tessera_logger$log_analysis_start(paste("Centrality calculation for", n, "nodes"))
    
    # Get adjacency matrix for Zig operations
    adj_matrix <- as.matrix(as_adjacency_matrix(g, type = "both"))
    
    # Use Zig acceleration for graph operations when available and beneficial
    use_zig <- exists("is_zig_graph_available") && is_zig_graph_available() && n <= 1000 && n > 10
    
    if (use_zig) {
        tessera_logger$log_analysis_start("Using Zig-accelerated graph operations")
        
        # Zig-accelerated degree centrality
        tryCatch({
            degree_result <- enhanced_degree_centrality(adj_matrix)
            centrality$degree_in <- degree_result$in_degree
            centrality$degree_out <- degree_result$out_degree
            centrality$degree_total <- degree_result$total_degree
        }, error = function(e) {
            # Fallback to igraph
            centrality$degree_in <<- degree(g, mode = "in")
            centrality$degree_out <<- degree(g, mode = "out")
            centrality$degree_total <<- degree(g, mode = "all")
        })
        
        # Zig-accelerated PageRank
        tryCatch({
            centrality$pagerank <- enhanced_pagerank(adj_matrix, damping = 0.85, iterations = 50)
        }, error = function(e) {
            centrality$pagerank <<- page_rank(g, directed = TRUE)$vector
        })
        
        # Zig-accelerated betweenness centrality
        tryCatch({
            centrality$betweenness <- enhanced_betweenness_centrality(adj_matrix)
        }, error = function(e) {
            centrality$betweenness <<- betweenness(g, directed = TRUE)
        })
        
        tessera_logger$log_analysis_complete("Zig-accelerated centrality calculations")
    } else {
        # Standard igraph calculations with vectorization optimizations
        
        # Vectorized degree calculations
        centrality$degree_in <- degree(g, mode = "in")
        centrality$degree_out <- degree(g, mode = "out")
        centrality$degree_total <- degree(g, mode = "all")
        
        # Optimized PageRank for smaller graphs
        if (n < 500) {
            centrality$pagerank <- page_rank(g, directed = TRUE)$vector
        } else {
            # Use faster approximation for large graphs
            centrality$pagerank <- page_rank(g, directed = TRUE, options = list(niter = 20))$vector
        }
        
        # Conditional betweenness calculation (expensive for large graphs)
        if (n < 200) {
            centrality$betweenness <- betweenness(g, directed = TRUE)
        } else {
            # Sample-based approximation for large graphs
            sample_size <- min(100, n)
            centrality$betweenness <- betweenness(g, directed = TRUE, v = sample(V(g), sample_size))
        }
    }
    
    # Always calculate these (relatively fast operations)
    centrality$closeness <- closeness(g, mode = "all")
    
    # Eigenvector centrality (with error handling for disconnected graphs)
    tryCatch({
        centrality$eigenvector <- eigen_centrality(g, directed = TRUE)$vector
    }, error = function(e) {
        centrality$eigenvector <- rep(0, n)
    })
    
    # Authority and hub scores (HITS algorithm)
    tryCatch({
        hits_result <- hits_scores(g)
        centrality$authority <- hits_result$authority
        centrality$hub <- hits_result$hub
    }, error = function(e) {
        centrality$authority <- rep(0, n)
        centrality$hub <- rep(0, n)
    })
    
    # Enhanced similarity-based centrality using Zig optimizations
    # Use Zig for medium to large graphs where custom algorithms provide benefits
    if (exists("is_zig_available") && is_zig_available() && n > 100 && n <= 2000) {
        tryCatch({
            centrality$similarity_centrality <- calculate_zig_similarity_centrality(adj_matrix)
            tessera_logger$log_analysis_complete("Zig-optimized similarity centrality")
        }, error = function(e) {
            tessera_logger$log_analysis_error("Zig similarity centrality failed, using R fallback", error = e$message)
            # Fallback to R implementation
            centrality$similarity_centrality <- calculate_r_similarity_centrality(adj_matrix)
        })
    } else if (n > 50 && n <= 500) {
        # Use R vectorized for smaller graphs
        centrality$similarity_centrality <- calculate_r_similarity_centrality(adj_matrix)
        tessera_logger$log_analysis_complete("Vectorized similarity centrality")
    }
    
    tessera_logger$log_analysis_complete("All centrality measures calculated")
    return(centrality)
}

# Zig-optimized similarity-based centrality calculation
# Use this for medium to large graphs where custom algorithms shine
calculate_zig_similarity_centrality <- function(adj_matrix) {
    n <- nrow(adj_matrix)
    if (n < 2) return(rep(0, n))
    
    similarity_scores <- numeric(n)
    
    # Use Zig batch cosine similarity for complex similarity computations
    # This is beneficial for custom algorithms beyond basic linear algebra
    for (i in 1:n) {
        query_vector <- adj_matrix[i, ]
        other_vectors <- adj_matrix[-i, , drop = FALSE]
        
        if (nrow(other_vectors) > 0) {
            # Use Zig for batch similarity calculation
            similarities <- enhanced_batch_cosine_similarity(query_vector, other_vectors)
            similarity_scores[i] <- mean(similarities, na.rm = TRUE)
        }
    }
    
    return(similarity_scores)
}

# R-optimized similarity-based centrality calculation  
# Use this for smaller graphs where R's BLAS optimizations are sufficient
calculate_r_similarity_centrality <- function(adj_matrix) {
    n <- nrow(adj_matrix)
    if (n < 2) return(rep(0, n))
    
    # Pure R vectorized implementation using optimized BLAS operations
    # Normalize rows for cosine similarity
    row_norms <- sqrt(rowSums(adj_matrix^2))
    row_norms[row_norms == 0] <- 1  # Avoid division by zero
    normalized_matrix <- adj_matrix / row_norms
    
    # Calculate similarity matrix using optimized matrix operations
    similarity_matrix <- tcrossprod(normalized_matrix)
    
    # Calculate mean similarity for each node (excluding self-similarity)
    similarity_scores <- numeric(n)
    for (i in 1:n) {
        similarities <- similarity_matrix[i, -i]
        similarity_scores[i] <- mean(similarities, na.rm = TRUE)
    }
    
    return(similarity_scores)
}

# Community detection using multiple algorithms
detect_communities <- function(g) {
    communities <- list()
    
    # Convert to undirected for community detection
    g_undirected <- as_undirected(g, mode = "collapse")
    
    # Louvain method
    communities$louvain <- cluster_louvain(g_undirected)
    
    # Walktrap
    communities$walktrap <- cluster_walktrap(g_undirected)
    
    # Fast greedy
    communities$fast_greedy <- cluster_fast_greedy(g_undirected)
    
    # Label propagation
    communities$label_propagation <- cluster_label_prop(g_undirected)
    
    # Leading eigenvector
    communities$leading_eigenvector <- cluster_leading_eigen(g_undirected)
    
    # Extract membership and modularity for each method
    result <- list()
    for (method_name in names(communities)) {
        method_result <- communities[[method_name]]
        member_vec <- as.vector(membership(method_result))
        result[[method_name]] <- list(
            membership = member_vec,
            modularity = modularity(method_result),
            communities_count = max(member_vec)
        )
    }
    
    return(result)
}

# Calculate advanced layout algorithms
calculate_layouts <- function(g) {
    layouts <- list()
    
    # Fruchterman-Reingold
    layouts$fruchterman_reingold <- layout_with_fr(g)
    
    # Kamada-Kawai
    layouts$kamada_kawai <- layout_with_kk(g)
    
    # Spring-embedded (GEM)
    layouts$gem <- layout_with_gem(g)
    
    # Large graph layout
    layouts$lgl <- layout_with_lgl(g)
    
    # Multi-dimensional scaling (for smaller graphs)
    if (vcount(g) < 1000 && vcount(g) > 2) {  # MDS is computationally expensive and needs >2 nodes
        tryCatch({
            layouts$mds <- layout_with_mds(g)
        }, error = function(e) {
            # Skip MDS if it fails
        })
    }
    
    # Hierarchical layouts
    if (is_dag(g)) {
        tryCatch({
            layouts$sugiyama <- layout_with_sugiyama(g)
        }, error = function(e) {
            # Skip Sugiyama if it fails
        })
    }
    
    # Circular layout
    layouts$circle <- layout_in_circle(g)
    
    # Grid layout for regular structures
    layouts$grid <- layout_on_grid(g)
    
    # Convert matrices to list format for JSON serialization
    for (layout_name in names(layouts)) {
        layout_matrix <- layouts[[layout_name]]
        if (is.matrix(layout_matrix) && ncol(layout_matrix) >= 2) {
            layouts[[layout_name]] <- list(
                x = layout_matrix[, 1],
                y = layout_matrix[, 2]
            )
        } else if (is.list(layout_matrix) && "layout" %in% names(layout_matrix)) {
            # Handle Sugiyama layout which returns a list with $layout component
            coords <- layout_matrix$layout
            if (is.matrix(coords) && ncol(coords) >= 2) {
                layouts[[layout_name]] <- list(
                    x = coords[, 1],
                    y = coords[, 2]
                )
            }
        }
    }
    
    return(layouts)
}

# Cluster analysis
analyze_clusters <- function(g) {
    analysis <- list()
    
    # K-core decomposition
    analysis$k_cores <- coreness(g)
    analysis$max_k_core <- max(analysis$k_cores)
    
    # Clique analysis
    max_cliques <- max_cliques(g, min = 3)  # Only cliques of size 3+
    analysis$max_cliques_count <- length(max_cliques)
    analysis$largest_clique_size <- if (length(max_cliques) > 0) {
        max(sapply(max_cliques, length))
    } else {
        0
    }
    
    # Motif analysis
    if (vcount(g) <= 100) {  # Motif analysis is expensive for large graphs
        analysis$triangle_count <- count_triangles(g)
    }
    
    # Rich club coefficient
    degrees <- degree(g)
    if (length(degrees) > 0) {
        max_degree <- max(degrees)
        rich_club <- rep(NA, max_degree)
        for (k in 1:min(max_degree, 50)) {  # Limit computation
            subgraph_nodes <- which(degrees >= k)
            if (length(subgraph_nodes) > 1) {
                subg <- induced_subgraph(g, subgraph_nodes)
                rich_club[k] <- edge_density(subg)
            }
        }
        analysis$rich_club_coefficient <- rich_club[!is.na(rich_club)]
    }
    
    return(analysis)
}

# Utility function for skewness calculation
calculate_skewness <- function(x) {
    n <- length(x)
    if (n < 3) return(NA)
    
    x_mean <- mean(x)
    x_sd <- sd(x)
    
    if (x_sd == 0) return(NA)
    
    skewness <- sum(((x - x_mean) / x_sd)^3) / n
    return(skewness)
}

# Utility function for null coalescing
`%||%` <- function(lhs, rhs) {
    if (is.null(lhs) || length(lhs) == 0) {
        rhs
    } else if (length(lhs) == 1 && is.na(lhs)) {
        rhs
    } else {
        lhs
    }
}

# Main execution when called from command line
main <- function() {
    args <- commandArgs(trailingOnly = TRUE)
    
    if (length(args) == 0) {
        cat("Usage: Rscript graph_analysis.R '<json_input>'\n")
        cat("Or call process_graph() function directly with JSON string\n")
        quit(status = 1)
    }
    
    json_input <- args[1]
    result <- process_graph(json_input)
    cat(result)
}

# Run main if script is executed directly
if (sys.nframe() == 0) {
    main()
}
