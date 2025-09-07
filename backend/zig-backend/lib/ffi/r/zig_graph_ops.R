#!/usr/bin/env Rscript

# Zig Graph Operations for R
# High-performance graph operations using Zig backend

# Global variables for Zig graph library
.zig_graph_lib_loaded <- FALSE
.zig_graph_lib_path <- NULL

# Initialize Zig graph library
init_zig_graph_ops <- function(lib_path = NULL) {
    if (is.null(lib_path)) {
        # Auto-detect library path
        script_dir <- dirname(sys.frame(1)$ofile)
        possible_paths <- c(
            file.path(script_dir, "..", "..", "..", "zig-out", "lib", "libtessera_graph_ops.so"),
            file.path(script_dir, "..", "..", "..", "zig-out", "lib", "libtessera_graph_ops.dylib"),
            "./zig-backend/zig-out/lib/libtessera_graph_ops.so",
            "../zig-backend/zig-out/lib/libtessera_graph_ops.so"
        )
        
        lib_path <- NULL
        for (path in possible_paths) {
            if (file.exists(path)) {
                lib_path <- path
                break
            }
        }
    }
    
    if (is.null(lib_path) || !file.exists(lib_path)) {
        message("Zig graph operations library not found, using R fallback")
        .zig_graph_lib_loaded <<- FALSE
        return(FALSE)
    }
    
    tryCatch({
        # Load the library
        dyn.load(lib_path)
        .zig_graph_lib_path <<- lib_path
        .zig_graph_lib_loaded <<- TRUE
        
        message(paste("✅ Zig graph operations loaded from:", lib_path))
        return(TRUE)
    }, error = function(e) {
        message(paste("❌ Failed to load Zig graph library:", e$message))
        .zig_graph_lib_loaded <<- FALSE
        return(FALSE)
    })
}

# Check if Zig graph operations are available
is_zig_graph_available <- function() {
    return(.zig_graph_lib_loaded)
}

# High-performance degree centrality calculation
zig_calculate_degree_centrality <- function(adjacency_matrix) {
    if (!.zig_graph_lib_loaded) {
        return(r_calculate_degree_centrality(adjacency_matrix))
    }
    
    if (!is.matrix(adjacency_matrix)) {
        adjacency_matrix <- as.matrix(adjacency_matrix)
    }
    
    n <- nrow(adjacency_matrix)
    if (n != ncol(adjacency_matrix)) {
        stop("Adjacency matrix must be square")
    }
    
    tryCatch({
        # Prepare data
        adj_vec <- as.single(as.numeric(t(adjacency_matrix)))  # Row-major order
        in_degree <- numeric(n)
        out_degree <- numeric(n)
        total_degree <- numeric(n)
        
        # Call Zig function
        result <- .C("calculate_degree_centrality",
                    adjacency = adj_vec,
                    n = as.integer(n),
                    in_degree = as.single(in_degree),
                    out_degree = as.single(out_degree),
                    total_degree = as.single(total_degree))
        
        return(list(
            in_degree = result$in_degree,
            out_degree = result$out_degree,
            total_degree = result$total_degree
        ))
    }, error = function(e) {
        message(paste("Zig degree centrality failed, using R fallback:", e$message))
        return(r_calculate_degree_centrality(adjacency_matrix))
    })
}

# High-performance PageRank calculation
zig_calculate_pagerank <- function(adjacency_matrix, damping = 0.85, iterations = 50) {
    if (!.zig_graph_lib_loaded) {
        return(r_calculate_pagerank(adjacency_matrix, damping, iterations))
    }
    
    if (!is.matrix(adjacency_matrix)) {
        adjacency_matrix <- as.matrix(adjacency_matrix)
    }
    
    n <- nrow(adjacency_matrix)
    if (n != ncol(adjacency_matrix)) {
        stop("Adjacency matrix must be square")
    }
    
    if (n > 1000) {
        message("Graph too large for Zig optimization (>1000 nodes), using R fallback")
        return(r_calculate_pagerank(adjacency_matrix, damping, iterations))
    }
    
    tryCatch({
        # Prepare data
        adj_vec <- as.single(as.numeric(t(adjacency_matrix)))  # Row-major order
        pagerank <- numeric(n)
        
        # Call Zig function
        result <- .C("calculate_pagerank_fast",
                    adjacency = adj_vec,
                    n = as.integer(n),
                    damping = as.single(damping),
                    iterations = as.integer(iterations),
                    pagerank = as.single(pagerank))
        
        return(result$pagerank)
    }, error = function(e) {
        message(paste("Zig PageRank failed, using R fallback:", e$message))
        return(r_calculate_pagerank(adjacency_matrix, damping, iterations))
    })
}

# High-performance betweenness centrality calculation
zig_calculate_betweenness_centrality <- function(adjacency_matrix) {
    if (!.zig_graph_lib_loaded) {
        return(r_calculate_betweenness_centrality(adjacency_matrix))
    }
    
    if (!is.matrix(adjacency_matrix)) {
        adjacency_matrix <- as.matrix(adjacency_matrix)
    }
    
    n <- nrow(adjacency_matrix)
    if (n != ncol(adjacency_matrix)) {
        stop("Adjacency matrix must be square")
    }
    
    if (n > 1000) {
        message("Graph too large for Zig optimization (>1000 nodes), using R fallback")
        return(r_calculate_betweenness_centrality(adjacency_matrix))
    }
    
    tryCatch({
        # Prepare data
        adj_vec <- as.single(as.numeric(t(adjacency_matrix)))  # Row-major order
        betweenness <- numeric(n)
        
        # Call Zig function
        result <- .C("calculate_betweenness_centrality_fast",
                    adjacency = adj_vec,
                    n = as.integer(n),
                    betweenness = as.single(betweenness))
        
        return(result$betweenness)
    }, error = function(e) {
        message(paste("Zig betweenness centrality failed, using R fallback:", e$message))
        return(r_calculate_betweenness_centrality(adjacency_matrix))
    })
}

# High-performance clustering coefficient calculation
zig_calculate_clustering_coefficient <- function(adjacency_matrix) {
    if (!.zig_graph_lib_loaded) {
        return(r_calculate_clustering_coefficient(adjacency_matrix))
    }
    
    if (!is.matrix(adjacency_matrix)) {
        adjacency_matrix <- as.matrix(adjacency_matrix)
    }
    
    n <- nrow(adjacency_matrix)
    if (n != ncol(adjacency_matrix)) {
        stop("Adjacency matrix must be square")
    }
    
    if (n > 1000) {
        message("Graph too large for Zig optimization (>1000 nodes), using R fallback")
        return(r_calculate_clustering_coefficient(adjacency_matrix))
    }
    
    tryCatch({
        # Prepare data
        adj_vec <- as.single(as.numeric(t(adjacency_matrix)))  # Row-major order
        clustering <- numeric(n)
        
        # Call Zig function
        result <- .C("calculate_clustering_coefficient",
                    adjacency = adj_vec,
                    n = as.integer(n),
                    clustering = as.single(clustering))
        
        return(result$clustering)
    }, error = function(e) {
        message(paste("Zig clustering coefficient failed, using R fallback:", e$message))
        return(r_calculate_clustering_coefficient(adjacency_matrix))
    })
}

# High-performance layout optimization
zig_optimize_layout <- function(positions, adjacency_matrix, k = 1.0, iterations = 100) {
    if (!.zig_graph_lib_loaded) {
        return(r_optimize_layout(positions, adjacency_matrix, k, iterations))
    }
    
    if (!is.matrix(adjacency_matrix)) {
        adjacency_matrix <- as.matrix(adjacency_matrix)
    }
    
    if (!is.matrix(positions)) {
        positions <- as.matrix(positions)
    }
    
    n <- nrow(adjacency_matrix)
    if (n != ncol(adjacency_matrix)) {
        stop("Adjacency matrix must be square")
    }
    
    if (nrow(positions) != n || ncol(positions) != 2) {
        stop("Positions matrix must be n x 2")
    }
    
    if (n > 1000) {
        message("Graph too large for Zig optimization (>1000 nodes), using R fallback")
        return(r_optimize_layout(positions, adjacency_matrix, k, iterations))
    }
    
    tryCatch({
        # Prepare data - interleave x,y coordinates
        pos_vec <- as.single(as.numeric(t(positions)))  # x1,y1,x2,y2,...
        adj_vec <- as.single(as.numeric(t(adjacency_matrix)))  # Row-major order
        
        # Call Zig function
        result <- .C("optimize_layout_forces",
                    positions = pos_vec,
                    n = as.integer(n),
                    adjacency = adj_vec,
                    k = as.single(k),
                    iterations = as.integer(iterations))
        
        # Convert back to matrix format
        optimized_positions <- matrix(result$positions, nrow = n, ncol = 2, byrow = TRUE)
        return(optimized_positions)
    }, error = function(e) {
        message(paste("Zig layout optimization failed, using R fallback:", e$message))
        return(r_optimize_layout(positions, adjacency_matrix, k, iterations))
    })
}

# R fallback implementations
r_calculate_degree_centrality <- function(adjacency_matrix) {
    n <- nrow(adjacency_matrix)
    
    in_degree <- colSums(adjacency_matrix)
    out_degree <- rowSums(adjacency_matrix)
    total_degree <- in_degree + out_degree
    
    return(list(
        in_degree = in_degree,
        out_degree = out_degree,
        total_degree = total_degree
    ))
}

r_calculate_pagerank <- function(adjacency_matrix, damping = 0.85, iterations = 50) {
    n <- nrow(adjacency_matrix)
    
    # Initialize PageRank values
    pagerank <- rep(1/n, n)
    
    # Calculate out-degrees for normalization
    out_degree <- rowSums(adjacency_matrix)
    out_degree[out_degree == 0] <- 1  # Avoid division by zero
    
    # Power iteration
    for (iter in 1:iterations) {
        new_pagerank <- rep((1 - damping) / n, n)
        
        for (i in 1:n) {
            contribution <- damping * pagerank[i] / out_degree[i]
            for (j in 1:n) {
                if (adjacency_matrix[i, j] > 0) {
                    new_pagerank[j] <- new_pagerank[j] + contribution * adjacency_matrix[i, j]
                }
            }
        }
        
        pagerank <- new_pagerank
    }
    
    return(pagerank)
}

r_calculate_betweenness_centrality <- function(adjacency_matrix) {
    # Simplified betweenness centrality using igraph if available
    if (requireNamespace("igraph", quietly = TRUE)) {
        g <- igraph::graph_from_adjacency_matrix(adjacency_matrix, weighted = TRUE)
        return(igraph::betweenness(g, directed = TRUE))
    } else {
        # Very basic approximation
        n <- nrow(adjacency_matrix)
        return(rep(0, n))
    }
}

r_calculate_clustering_coefficient <- function(adjacency_matrix) {
    n <- nrow(adjacency_matrix)
    clustering <- numeric(n)
    
    for (i in 1:n) {
        neighbors <- which(adjacency_matrix[i, ] > 0)
        k <- length(neighbors)
        
        if (k < 2) {
            clustering[i] <- 0
            next
        }
        
        # Count triangles
        triangles <- 0
        for (j in 1:(k-1)) {
            for (l in (j+1):k) {
                if (adjacency_matrix[neighbors[j], neighbors[l]] > 0) {
                    triangles <- triangles + 1
                }
            }
        }
        
        possible_triangles <- k * (k - 1) / 2
        clustering[i] <- triangles / possible_triangles
    }
    
    return(clustering)
}

r_optimize_layout <- function(positions, adjacency_matrix, k = 1.0, iterations = 100) {
    # Simple force-directed layout optimization
    n <- nrow(positions)
    dt <- 0.1
    
    for (iter in 1:iterations) {
        forces <- matrix(0, nrow = n, ncol = 2)
        
        # Repulsive forces
        for (i in 1:(n-1)) {
            for (j in (i+1):n) {
                dx <- positions[i, 1] - positions[j, 1]
                dy <- positions[i, 2] - positions[j, 2]
                dist <- sqrt(dx^2 + dy^2)
                
                if (dist > 0) {
                    force_magnitude <- k^2 / dist
                    fx <- force_magnitude * dx / dist
                    fy <- force_magnitude * dy / dist
                    
                    forces[i, 1] <- forces[i, 1] + fx
                    forces[i, 2] <- forces[i, 2] + fy
                    forces[j, 1] <- forces[j, 1] - fx
                    forces[j, 2] <- forces[j, 2] - fy
                }
            }
        }
        
        # Attractive forces
        for (i in 1:n) {
            for (j in 1:n) {
                if (i != j && adjacency_matrix[i, j] > 0) {
                    dx <- positions[j, 1] - positions[i, 1]
                    dy <- positions[j, 2] - positions[i, 2]
                    dist <- sqrt(dx^2 + dy^2)
                    
                    if (dist > 0) {
                        force_magnitude <- dist^2 / k * adjacency_matrix[i, j]
                        fx <- force_magnitude * dx / dist
                        fy <- force_magnitude * dy / dist
                        
                        forces[i, 1] <- forces[i, 1] + fx
                        forces[i, 2] <- forces[i, 2] + fy
                    }
                }
            }
        }
        
        # Update positions with damping
        damping <- 1 - iter / iterations * 0.9
        positions <- positions + dt * forces * damping
    }
    
    return(positions)
}

# Enhanced functions that automatically choose best implementation
enhanced_degree_centrality <- function(adjacency_matrix) {
    if (.zig_graph_lib_loaded && nrow(adjacency_matrix) <= 1000) {
        return(zig_calculate_degree_centrality(adjacency_matrix))
    } else {
        return(r_calculate_degree_centrality(adjacency_matrix))
    }
}

enhanced_pagerank <- function(adjacency_matrix, damping = 0.85, iterations = 50) {
    if (.zig_graph_lib_loaded && nrow(adjacency_matrix) <= 1000) {
        return(zig_calculate_pagerank(adjacency_matrix, damping, iterations))
    } else {
        return(r_calculate_pagerank(adjacency_matrix, damping, iterations))
    }
}

enhanced_betweenness_centrality <- function(adjacency_matrix) {
    if (.zig_graph_lib_loaded && nrow(adjacency_matrix) <= 1000) {
        return(zig_calculate_betweenness_centrality(adjacency_matrix))
    } else {
        return(r_calculate_betweenness_centrality(adjacency_matrix))
    }
}

enhanced_clustering_coefficient <- function(adjacency_matrix) {
    if (.zig_graph_lib_loaded && nrow(adjacency_matrix) <= 1000) {
        return(zig_calculate_clustering_coefficient(adjacency_matrix))
    } else {
        return(r_calculate_clustering_coefficient(adjacency_matrix))
    }
}

enhanced_layout_optimization <- function(positions, adjacency_matrix, k = 1.0, iterations = 100) {
    if (.zig_graph_lib_loaded && nrow(adjacency_matrix) <= 1000) {
        return(zig_optimize_layout(positions, adjacency_matrix, k, iterations))
    } else {
        return(r_optimize_layout(positions, adjacency_matrix, k, iterations))
    }
}

# Utility function for benchmarking
benchmark_graph_ops <- function(adjacency_matrix) {
    message("🧪 Benchmarking Zig vs R graph operations...")
    
    n <- nrow(adjacency_matrix)
    message(sprintf("Graph size: %d nodes", n))
    
    if (.zig_graph_lib_loaded && n <= 1000) {
        # Benchmark Zig
        zig_time <- system.time({
            zig_results <- zig_calculate_degree_centrality(adjacency_matrix)
        })
        
        # Benchmark R
        r_time <- system.time({
            r_results <- r_calculate_degree_centrality(adjacency_matrix)
        })
        
        # Check accuracy
        accuracy <- all.equal(zig_results$total_degree, r_results$total_degree, tolerance = 1e-5)
        
        message(sprintf("📊 Degree Centrality Results:"))
        message(sprintf("   Zig time: %.2f ms", zig_time[3] * 1000))
        message(sprintf("   R time: %.2f ms", r_time[3] * 1000))
        message(sprintf("   Speedup: %.1fx", r_time[3] / zig_time[3]))
        message(sprintf("   Results match: %s", if(isTRUE(accuracy)) "✅ Yes" else "❌ No"))
        
        return(list(
            zig_time = zig_time[3],
            r_time = r_time[3],
            speedup = r_time[3] / zig_time[3],
            accuracy = accuracy
        ))
    } else {
        message("❌ Zig not available or graph too large, only R timing:")
        r_time <- system.time({
            r_results <- r_calculate_degree_centrality(adjacency_matrix)
        })
        message(sprintf("   R time: %.2f ms", r_time[3] * 1000))
        
        return(list(r_time = r_time[3]))
    }
}

# Auto-initialize when sourced
if (!exists(".zig_graph_init_attempted")) {
    .zig_graph_init_attempted <- TRUE
    init_zig_graph_ops()
}

# Export main functions
if (!exists("zig_graph_ops_loaded")) {
    zig_graph_ops_loaded <- TRUE
    message("📦 Zig graph operations for R loaded")
    if (.zig_graph_lib_loaded) {
        message("⚡ Zig graph acceleration available")
    } else {
        message("🔄 Using R fallback implementations")
    }
}
