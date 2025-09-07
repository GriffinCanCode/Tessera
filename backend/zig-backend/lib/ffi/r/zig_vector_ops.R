#!/usr/bin/env Rscript

# Zig Vector Operations for R
# High-performance vector operations using Zig backend

# Global variables for Zig library
.zig_lib_loaded <- FALSE
.zig_lib_path <- NULL

# Initialize Zig library
init_zig_ops <- function(lib_path = NULL) {
    if (is.null(lib_path)) {
        # Auto-detect library path
        script_dir <- dirname(sys.frame(1)$ofile)
        possible_paths <- c(
            file.path(script_dir, "..", "..", "..", "zig-out", "lib", "libtessera_vector_ops_r.dylib"),
            file.path(script_dir, "..", "..", "..", "zig-out", "lib", "libtessera_vector_ops_r.so"),
            "../zig-backend/zig-out/lib/libtessera_vector_ops_r.dylib",
            "../zig-backend/zig-out/lib/libtessera_vector_ops_r.so",
            "./zig-backend/zig-out/lib/libtessera_vector_ops_r.dylib",
            "/Users/griffinstrier/projects/Wikilizer/backend/zig-backend/zig-out/lib/libtessera_vector_ops_r.dylib"
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
        message("Zig vector operations library not found, using R fallback")
        .zig_lib_loaded <<- FALSE
        return(FALSE)
    }
    
    tryCatch({
        # Load the library
        dyn.load(lib_path)
        .zig_lib_path <<- lib_path
        .zig_lib_loaded <<- TRUE
        
        message(paste("✅ Zig vector operations loaded from:", lib_path))
        return(TRUE)
    }, error = function(e) {
        message(paste("❌ Failed to load Zig library:", e$message))
        .zig_lib_loaded <<- FALSE
        return(FALSE)
    })
}

# Check if Zig operations are available
is_zig_available <- function() {
    return(.zig_lib_loaded)
}

# High-performance cosine similarity
zig_cosine_similarity <- function(vec1, vec2) {
    if (!.zig_lib_loaded) {
        return(r_cosine_similarity(vec1, vec2))
    }
    
    if (length(vec1) != length(vec2)) {
        return(0.0)
    }
    
    tryCatch({
        # Convert to numeric vectors
        v1 <- as.numeric(vec1)
        v2 <- as.numeric(vec2)
        
        # Call C wrapper function (R-compatible interface)
        result <- .C("cosine_similarity",
                    vec1 = as.single(v1),
                    vec2 = as.single(v2),
                    len = as.integer(length(v1)),
                    result = as.single(0.0))
        
        return(result$result)
    }, error = function(e) {
        message(paste("Zig cosine similarity failed, using R fallback:", e$message))
        return(r_cosine_similarity(vec1, vec2))
    })
}

# High-performance batch cosine similarity
zig_batch_cosine_similarity <- function(query, embeddings_matrix) {
    if (!.zig_lib_loaded) {
        return(r_batch_cosine_similarity(query, embeddings_matrix))
    }
    
    if (!is.matrix(embeddings_matrix)) {
        embeddings_matrix <- as.matrix(embeddings_matrix)
    }
    
    num_embeddings <- nrow(embeddings_matrix)
    vector_dim <- length(query)
    
    if (ncol(embeddings_matrix) != vector_dim) {
        stop("Query dimension doesn't match embedding matrix dimensions")
    }
    
    tryCatch({
        # Prepare data
        query_vec <- as.single(as.numeric(query))
        embeddings_vec <- as.single(as.numeric(t(embeddings_matrix)))  # Row-major order
        results <- numeric(num_embeddings)
        
        # Call Zig function
        result <- .C("batch_cosine_similarity",
                    query = query_vec,
                    embeddings = embeddings_vec,
                    num_embeddings = as.integer(num_embeddings),
                    vector_dim = as.integer(vector_dim),
                    results = as.single(results))
        
        return(result$results)
    }, error = function(e) {
        message(paste("Zig batch similarity failed, using R fallback:", e$message))
        return(r_batch_cosine_similarity(query, embeddings_matrix))
    })
}

# Batch similarity with threshold filtering
zig_batch_similarity_with_threshold <- function(query, embeddings_matrix, threshold = 0.3) {
    if (!.zig_lib_loaded) {
        return(r_batch_similarity_with_threshold(query, embeddings_matrix, threshold))
    }
    
    if (!is.matrix(embeddings_matrix)) {
        embeddings_matrix <- as.matrix(embeddings_matrix)
    }
    
    num_embeddings <- nrow(embeddings_matrix)
    vector_dim <- length(query)
    
    tryCatch({
        # Prepare data
        query_vec <- as.single(as.numeric(query))
        embeddings_vec <- as.single(as.numeric(t(embeddings_matrix)))
        results <- numeric(num_embeddings)
        indices <- integer(num_embeddings)
        
        # Call Zig function
        result <- .C("batch_similarity_with_threshold",
                    query = query_vec,
                    embeddings = embeddings_vec,
                    num_embeddings = as.integer(num_embeddings),
                    vector_dim = as.integer(vector_dim),
                    threshold = as.single(threshold),
                    results = as.single(results),
                    indices = as.integer(indices),
                    count = as.integer(0))
        
        count <- result$count
        if (count > 0) {
            return(list(
                similarities = result$results[1:count],
                indices = result$indices[1:count] + 1  # Convert to 1-based indexing
            ))
        } else {
            return(list(similarities = numeric(0), indices = integer(0)))
        }
    }, error = function(e) {
        message(paste("Zig threshold similarity failed, using R fallback:", e$message))
        return(r_batch_similarity_with_threshold(query, embeddings_matrix, threshold))
    })
}

# Optimized R implementations using advanced BLAS techniques
r_cosine_similarity <- function(vec1, vec2) {
    if (length(vec1) != length(vec2)) return(0.0)
    
    dot_product <- sum(vec1 * vec2)
    norm1 <- sqrt(sum(vec1^2))
    norm2 <- sqrt(sum(vec2^2))
    
    if (norm1 == 0 || norm2 == 0) return(0.0)
    
    return(dot_product / (norm1 * norm2))
}

r_batch_cosine_similarity <- function(query, embeddings_matrix) {
    if (!is.matrix(embeddings_matrix)) {
        embeddings_matrix <- as.matrix(embeddings_matrix)
    }
    
    # ULTRA-OPTIMIZED: Maximum performance R implementation
    # Pre-normalize query once using squared norm for efficiency
    query_norm_sq <- sum(query * query)
    if (query_norm_sq == 0) return(rep(0, nrow(embeddings_matrix)))
    
    query_normalized <- query / sqrt(query_norm_sq)
    
    # Vectorized norms using rowSums (BLAS optimized)
    embedding_norms_sq <- rowSums(embeddings_matrix * embeddings_matrix)
    valid_idx <- embedding_norms_sq > 0
    
    results <- numeric(nrow(embeddings_matrix))
    
    if (any(valid_idx)) {
        # Use tcrossprod for maximum BLAS efficiency
        valid_embeddings <- embeddings_matrix[valid_idx, , drop = FALSE]
        valid_norms <- sqrt(embedding_norms_sq[valid_idx])
        
        # Single matrix operation - most efficient
        results[valid_idx] <- (valid_embeddings %*% query_normalized) / valid_norms
    }
    
    return(as.vector(results))
}

r_batch_similarity_with_threshold <- function(query, embeddings_matrix, threshold = 0.3) {
    similarities <- r_batch_cosine_similarity(query, embeddings_matrix)
    above_threshold <- similarities >= threshold
    
    return(list(
        similarities = similarities[above_threshold],
        indices = which(above_threshold)
    ))
}

# OPTIMAL ENHANCED FUNCTIONS - Intelligently choose best implementation
# Based on comprehensive benchmarking and workload analysis

enhanced_cosine_similarity <- function(vec1, vec2) {
    # OPTIMAL STRATEGY: R-BLAS for most cases, Zig only for specialized scenarios
    vector_length <- length(vec1)
    
    # Use Zig only for very large vectors (>2000) where SIMD provides clear benefits
    # or when vectors are part of complex iterative algorithms
    if (.zig_lib_loaded && vector_length > 2000) {
        return(zig_cosine_similarity(vec1, vec2))
    } else {
        # R-BLAS is optimal for standard vector operations
        return(r_cosine_similarity(vec1, vec2))
    }
}

enhanced_batch_cosine_similarity <- function(query, embeddings_matrix) {
    # OPTIMAL: R's BLAS is consistently fastest for batch operations
    # Matrix operations in R are highly optimized and beat Zig FFI overhead
    return(r_batch_cosine_similarity(query, embeddings_matrix))
}

enhanced_batch_similarity_with_threshold <- function(query, embeddings_matrix, threshold = 0.3) {
    # OPTIMAL HYBRID STRATEGY based on workload characteristics
    n_embeddings <- nrow(embeddings_matrix)
    vector_dim <- length(query)
    
    # Use Zig for small-medium datasets where threshold filtering benefits from SIMD
    # and FFI overhead is minimal compared to computation
    if (.zig_lib_loaded && n_embeddings >= 50 && n_embeddings <= 200 && vector_dim >= 384) {
        return(zig_batch_similarity_with_threshold(query, embeddings_matrix, threshold))
    } else {
        # Use optimized R-BLAS for all other cases (small datasets, large datasets, low dimensions)
        return(r_batch_similarity_with_threshold(query, embeddings_matrix, threshold))
    }
}

# Utility function for benchmarking
benchmark_zig_vs_r <- function(vector_dim = 384, num_embeddings = 1000) {
    message("🧪 Benchmarking Zig vs R vector operations...")
    
    # Generate test data
    set.seed(42)
    query <- rnorm(vector_dim)
    embeddings <- matrix(rnorm(num_embeddings * vector_dim), nrow = num_embeddings)
    
    # Normalize vectors for proper cosine similarity
    query <- query / sqrt(sum(query^2))
    embeddings <- embeddings / sqrt(rowSums(embeddings^2))
    
    if (.zig_lib_loaded) {
        # Benchmark Zig
        zig_time <- system.time({
            zig_results <- zig_batch_cosine_similarity(query, embeddings)
        })
        
        # Benchmark R
        r_time <- system.time({
            r_results <- r_batch_cosine_similarity(query, embeddings)
        })
        
        # Check accuracy
        accuracy <- all.equal(zig_results, r_results, tolerance = 1e-5)
        
        message(sprintf("📊 Results:"))
        message(sprintf("   Vector dimension: %d", vector_dim))
        message(sprintf("   Number of embeddings: %d", num_embeddings))
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
        message("❌ Zig not available, only R timing:")
        r_time <- system.time({
            r_results <- r_batch_cosine_similarity(query, embeddings)
        })
        message(sprintf("   R time: %.2f ms", r_time[3] * 1000))
        
        return(list(r_time = r_time[3]))
    }
}

# Auto-initialize when sourced
if (!exists(".zig_init_attempted")) {
    .zig_init_attempted <- TRUE
    init_zig_ops()
}

# Export main functions
if (!exists("zig_ops_loaded")) {
    zig_ops_loaded <- TRUE
    message("📦 Zig vector operations for R loaded")
    if (.zig_lib_loaded) {
        message("⚡ Zig acceleration available")
    } else {
        message("🔄 Using R fallback implementations")
    }
}
