#!/usr/bin/env Rscript

# Advanced Layout Algorithms for WikiCrawler Knowledge Graph
# Specialized R script for graph layout calculations

suppressPackageStartupMessages({
    library(igraph)
    library(jsonlite)
})

# Main function to calculate advanced layouts
calculate_advanced_layouts <- function(json_input) {
    tryCatch({
        # Parse input
        graph_data <- fromJSON(json_input)
        g <- create_igraph_from_data(graph_data)
        
        # Calculate multiple layout algorithms
        layouts <- list()
        
        # Force-directed layouts
        tryCatch({
            layouts$fruchterman_reingold <- calculate_fr_layout(g)
        }, error = function(e) {
            # Skip FR layout if it fails
        })
        tryCatch({
            layouts$kamada_kawai <- calculate_kk_layout(g)
        }, error = function(e) {
            # Skip KK layout if it fails
        })
        tryCatch({
            layouts$spring_embedded <- calculate_gem_layout(g)
        }, error = function(e) {
            # Skip GEM layout if it fails
        })
        
        # Hierarchical layouts
        if (is_dag(g)) {
            layouts$sugiyama <- calculate_sugiyama_layout(g)
            layouts$reingold_tilford <- calculate_tree_layout(g)
        }
        
        # Large graph optimized layouts
        if (vcount(g) > 100) {
            tryCatch({
                layouts$large_graph <- calculate_lgl_layout(g)
            }, error = function(e) {
                # Skip LGL layout if it fails
            })
            tryCatch({
                layouts$grid_force <- calculate_grid_force_layout(g)
            }, error = function(e) {
                # Skip grid force layout if it fails
            })
        }
        
        # Stress minimization layouts
        tryCatch({
            layouts$stress_majorization <- calculate_stress_layout(g)
        }, error = function(e) {
            # Skip stress layout if it fails
        })
        
        # Multi-dimensional scaling (for smaller graphs)
        if (vcount(g) < 200) {
            tryCatch({
                layouts$mds <- calculate_mds_layout(g)
            }, error = function(e) {
                # Skip MDS layout if it fails
            })
        }
        
        # Specialized layouts for different node types
        if (has_node_types(graph_data$nodes)) {

            tryCatch({
                layouts$bipartite <- calculate_bipartite_layout(g, graph_data$nodes)
            }, error = function(e) {
                # Skip bipartite layout if it fails
            })
            tryCatch({
                layouts$clustered <- calculate_clustered_layout(g)
            }, error = function(e) {
                # Skip clustered layout if it fails
            })
        }
        
        # Physics-based layouts
        tryCatch({
            layouts$physics_simulation <- calculate_physics_layout(g)
        }, error = function(e) {
            # Skip physics layout if it fails
        })
        
        # Return as JSON
        result <- list(
            layouts = layouts,
            recommendations = recommend_best_layout(g, layouts),
            layout_metrics = evaluate_layout_quality(g, layouts)
        )
        
        return(toJSON(result, pretty = TRUE, auto_unbox = TRUE))
        
    }, error = function(e) {
        error_result <- list(error = paste("Layout Error:", e$message))
        return(toJSON(error_result, auto_unbox = TRUE))
    })
}

# Fruchterman-Reingold with optimized parameters
calculate_fr_layout <- function(g) {
    n <- vcount(g)
    
    # Optimize parameters based on graph size
    niter <- if (n < 100) 500 else if (n < 500) 300 else 100
    
    layout <- layout_with_fr(
        g,
        niter = niter,
        start.temp = sqrt(n),
        grid = "nogrid",
        weights = E(g)$weight
    )
    
    # Apply edge-length optimization
    layout <- optimize_edge_lengths(g, layout)
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Kamada-Kawai with distance matrix optimization
calculate_kk_layout <- function(g) {
    # Use shortest path distances as ideal distances
    layout <- layout_with_kk(
        g,
        weights = E(g)$weight,
        kkconst = vcount(g)
    )
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# GEM (Graph EMbedder) algorithm
calculate_gem_layout <- function(g) {
    layout <- layout_with_gem(
        g,
        maxiter = 40 * vcount(g)^2
    )
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Sugiyama hierarchical layout for DAGs
calculate_sugiyama_layout <- function(g) {
    layout <- layout_with_sugiyama(
        g,
        layers = NULL,
        weights = E(g)$weight
    )
    
    # Extract coordinates from the layout object
    coords <- layout$layout
    return(list(x = coords[, 1], y = coords[, 2]))
}

# Reingold-Tilford tree layout
calculate_tree_layout <- function(g) {
    # Find root nodes (nodes with no incoming edges)
    indegrees <- degree(g, mode = "in")
    roots <- which(indegrees == 0)
    
    if (length(roots) == 0) {
        # If no clear root, use node with highest out-degree
        outdegrees <- degree(g, mode = "out")
        roots <- which.max(outdegrees)
    }
    
    layout <- layout_as_tree(g, root = roots[1], circular = FALSE)
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Large Graph Layout (LGL)
calculate_lgl_layout <- function(g) {
    layout <- layout_with_lgl(
        g,
        maxiter = 150,
        maxdelta = vcount(g),
        area = vcount(g)^2,
        coolexp = 1.5,
        repulserad = vcount(g)^3,
        cellsize = sqrt(sqrt(vcount(g)))
    )
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Grid-based force layout
calculate_grid_force_layout <- function(g) {
    # Start with grid layout
    grid_layout <- layout_on_grid(g, dim = 2)
    
    # Apply force-directed refinement
    layout <- layout_with_fr(
        g,
        coords = grid_layout,
        niter = 100
    )
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Stress majorization layout
calculate_stress_layout <- function(g) {
    # Calculate shortest path distances
    distances <- distances(g, weights = E(g)$weight)
    
    # Use multi-dimensional scaling with stress minimization
    layout <- layout_with_mds(g, dist = distances)
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Multi-dimensional scaling
calculate_mds_layout <- function(g) {
    layout <- layout_with_mds(g)
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Bipartite layout for graphs with distinct node types
calculate_bipartite_layout <- function(g, nodes) {
    # Try to detect bipartite structure
    if (is_bipartite(g)) {
        layout <- layout_as_bipartite(g)
    } else {
        # Create pseudo-bipartite based on node types
        node_types <- sapply(nodes, function(x) x$node_type %||% "general")
        
        # Group by most common types
        type_counts <- table(node_types)
        sorted_types <- names(sort(type_counts, decreasing = TRUE))
        main_types <- sorted_types[1:min(2, length(sorted_types))]
        
        # Assign coordinates
        n <- vcount(g)
        layout <- matrix(0, nrow = n, ncol = 2)
        
        for (i in 1:n) {
            node_type <- node_types[i]
            if (length(main_types) >= 1 && node_type == main_types[1]) {
                layout[i, 1] <- -1
                layout[i, 2] <- runif(1, -1, 1)
            } else if (length(main_types) >= 2 && node_type == main_types[2]) {
                layout[i, 1] <- 1
                layout[i, 2] <- runif(1, -1, 1)
            } else {
                layout[i, 1] <- runif(1, -0.5, 0.5)
                layout[i, 2] <- runif(1, -1, 1)
            }
        }
    }
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Clustered layout based on community detection
calculate_clustered_layout <- function(g) {
    # Detect communities
    communities <- cluster_louvain(as_undirected(g, mode = "collapse"))
    membership <- membership(communities)
    
    # Position communities in a circle
    n_communities <- max(membership)
    community_positions <- data.frame(
        x = cos(2 * pi * (1:n_communities) / n_communities),
        y = sin(2 * pi * (1:n_communities) / n_communities)
    )
    
    # Layout nodes within communities
    layout <- matrix(0, nrow = vcount(g), ncol = 2)
    
    for (comm in 1:n_communities) {
        comm_nodes <- which(membership == comm)
        n_nodes <- length(comm_nodes)
        
        if (n_nodes == 1) {
            layout[comm_nodes, ] <- as.matrix(community_positions[comm, ])
        } else {
            # Create subgraph for this community
            subg <- induced_subgraph(g, comm_nodes)
            sub_layout <- layout_in_circle(subg, order = V(subg))
            
            # Scale and position around community center
            scale_factor <- 0.3
            sub_layout <- sub_layout * scale_factor
            sub_layout[, 1] <- sub_layout[, 1] + community_positions[comm, 1]
            sub_layout[, 2] <- sub_layout[, 2] + community_positions[comm, 2]
            
            layout[comm_nodes, ] <- sub_layout
        }
    }
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Physics-based simulation layout
calculate_physics_layout <- function(g) {
    n <- vcount(g)
    
    # Start with random positions
    layout <- matrix(runif(n * 2, -1, 1), ncol = 2)
    
    # Physics parameters
    k <- 1 / sqrt(n)  # Optimal distance
    dt <- 0.1  # Time step
    iterations <- 500
    
    for (iter in 1:iterations) {
        forces <- matrix(0, nrow = n, ncol = 2)
        
        # Repulsive forces (between all nodes)
        for (i in 1:(n-1)) {
            for (j in (i+1):n) {
                diff <- layout[i, ] - layout[j, ]
                dist <- sqrt(sum(diff^2))
                
                if (dist > 0) {
                    force <- k^2 / dist * (diff / dist)
                    forces[i, ] <- forces[i, ] + force
                    forces[j, ] <- forces[j, ] - force
                }
            }
        }
        
        # Attractive forces (between connected nodes)
        edges <- as_edgelist(g, names = FALSE)
        for (e in 1:nrow(edges)) {
            i <- edges[e, 1]
            j <- edges[e, 2]
            
            diff <- layout[i, ] - layout[j, ]
            dist <- sqrt(sum(diff^2))
            
            if (dist > 0) {
                force <- dist^2 / k * (diff / dist)
                forces[i, ] <- forces[i, ] - force
                forces[j, ] <- forces[j, ] + force
            }
        }
        
        # Update positions with damping
        damping <- 1 - iter / iterations * 0.9
        layout <- layout + dt * forces * damping
        
        # Cool down
        dt <- dt * 0.995
    }
    
    return(list(x = layout[, 1], y = layout[, 2]))
}

# Optimize edge lengths in existing layout
optimize_edge_lengths <- function(g, layout) {
    edges <- as_edgelist(g, names = FALSE)
    weights <- E(g)$weight
    
    if (is.null(weights)) weights <- rep(1, nrow(edges))
    
    # Calculate current edge lengths
    current_lengths <- rep(0, nrow(edges))
    for (i in 1:nrow(edges)) {
        v1 <- edges[i, 1]
        v2 <- edges[i, 2]
        diff <- layout[v1, ] - layout[v2, ]
        current_lengths[i] <- sqrt(sum(diff^2))
    }
    
    # Target lengths based on weights (inverse relationship)
    target_lengths <- 1 / (weights + 0.1)
    target_lengths <- target_lengths / mean(target_lengths) * mean(current_lengths)
    
    # Apply small adjustments
    adjustment_factor <- 0.1
    for (i in 1:nrow(edges)) {
        v1 <- edges[i, 1]
        v2 <- edges[i, 2]
        
        current_length <- current_lengths[i]
        target_length <- target_lengths[i]
        
        if (current_length > 0) {
            adjustment <- (target_length - current_length) * adjustment_factor
            direction <- (layout[v2, ] - layout[v1, ]) / current_length
            
            layout[v1, ] <- layout[v1, ] + direction * adjustment * 0.5
            layout[v2, ] <- layout[v2, ] - direction * adjustment * 0.5
        }
    }
    
    return(layout)
}

# Recommend best layout based on graph properties
recommend_best_layout <- function(g, layouts) {
    n <- vcount(g)
    m <- ecount(g)
    density <- edge_density(g)
    
    recommendations <- list()
    
    if (n < 50) {
        recommendations$small_graph <- c("kamada_kawai", "stress_majorization", "mds")
    } else if (n < 200) {
        recommendations$medium_graph <- c("fruchterman_reingold", "spring_embedded", "physics_simulation")
    } else {
        recommendations$large_graph <- c("large_graph", "grid_force", "clustered")
    }
    
    if (is_dag(g)) {
        recommendations$hierarchical <- c("sugiyama", "reingold_tilford")
    }
    
    if (density > 0.1) {
        recommendations$dense_graph <- c("kamada_kawai", "mds")
    } else {
        recommendations$sparse_graph <- c("fruchterman_reingold", "large_graph")
    }
    
    return(recommendations)
}

# Evaluate layout quality metrics
evaluate_layout_quality <- function(g, layouts) {
    metrics <- list()
    
    for (layout_name in names(layouts)) {
        layout <- layouts[[layout_name]]
        
        if (is.null(layout$x) || is.null(layout$y)) next
        
        coords <- cbind(layout$x, layout$y)
        
        # Calculate quality metrics
        edge_variance <- calculate_edge_length_variance(g, coords)
        node_separation <- calculate_min_node_distance(coords)
        aspect_ratio <- calculate_aspect_ratio(coords)
        
        metrics[[layout_name]] <- list(
            edge_length_variance = edge_variance,
            min_node_distance = node_separation,
            aspect_ratio = aspect_ratio,
            quality_score = calculate_overall_quality(edge_variance, node_separation, aspect_ratio)
        )
    }
    
    return(metrics)
}

# Helper functions for quality evaluation
calculate_edge_length_variance <- function(g, coords) {
    edges <- as_edgelist(g, names = FALSE)
    lengths <- rep(0, nrow(edges))
    
    for (i in 1:nrow(edges)) {
        v1 <- edges[i, 1]
        v2 <- edges[i, 2]
        diff <- coords[v1, ] - coords[v2, ]
        lengths[i] <- sqrt(sum(diff^2))
    }
    
    return(var(lengths))
}

calculate_min_node_distance <- function(coords) {
    n <- nrow(coords)
    min_dist <- Inf
    
    for (i in 1:(n-1)) {
        for (j in (i+1):n) {
            dist <- sqrt(sum((coords[i, ] - coords[j, ])^2))
            if (dist < min_dist) min_dist <- dist
        }
    }
    
    return(min_dist)
}

calculate_aspect_ratio <- function(coords) {
    x_range <- diff(range(coords[, 1]))
    y_range <- diff(range(coords[, 2]))
    
    return(max(x_range, y_range) / min(x_range, y_range))
}

calculate_overall_quality <- function(edge_var, min_dist, aspect_ratio) {
    # Normalize and combine metrics (lower is better for this score)
    normalized_variance <- 1 / (1 + edge_var)
    normalized_separation <- min_dist
    normalized_aspect <- 1 / aspect_ratio
    
    return(normalized_variance * normalized_separation * normalized_aspect)
}

# Utility functions
create_igraph_from_data <- function(graph_data) {
    nodes <- graph_data$nodes
    edges <- graph_data$edges
    
    if (is.list(nodes)) {
        node_ids <- names(nodes)
        node_df <- data.frame(id = node_ids, stringsAsFactors = FALSE)
    } else {
        node_df <- nodes
    }
    
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
    
    return(graph_from_data_frame(edge_df, directed = TRUE, vertices = node_df))
}

has_node_types <- function(nodes) {
    if (is.data.frame(nodes)) {
        return("node_type" %in% names(nodes))
    } else if (is.list(nodes)) {
        return(any(sapply(nodes, function(x) !is.null(x$node_type))))
    }
    return(FALSE)
}

`%||%` <- function(lhs, rhs) {
    if (is.null(lhs) || length(lhs) == 0) {
        rhs
    } else if (length(lhs) == 1 && is.na(lhs)) {
        rhs
    } else {
        lhs
    }
}

# Main execution
main <- function() {
    args <- commandArgs(trailingOnly = TRUE)
    
    if (length(args) == 0) {
        cat("Usage: Rscript layout_algorithms.R '<json_input>'\n")
        quit(status = 1)
    }
    
    result <- calculate_advanced_layouts(args[1])
    cat(result)
}

if (sys.nframe() == 0) {
    main()
}
