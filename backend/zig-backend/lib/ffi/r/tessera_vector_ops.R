#!/usr/bin/env Rscript

# Tessera Vector Operations for R
# High-performance vector operations using Zig backend with robust FFI
# Compatible with R 4.0-4.5.1

# Global state management
.tessera_env <- new.env(parent = emptyenv())
.tessera_env$lib_loaded <- FALSE
.tessera_env$lib_path <- NULL
.tessera_env$lib_handle <- NULL

# Library detection and loading
tessera_init <- function(lib_path = NULL, verbose = TRUE) {
    if (.tessera_env$lib_loaded) {
        if (verbose) message("✅ Tessera vector operations already loaded")
        return(TRUE)
    }
    
    if (is.null(lib_path)) {
        lib_path <- tessera_find_library()
    }
    
    if (is.null(lib_path) || !file.exists(lib_path)) {
        if (verbose) {
            message("❌ Tessera shared library not found")
            message("   Searched paths:")
            for (path in tessera_get_search_paths()) {
                message(sprintf("   - %s", path))
            }
            message("   Using R fallback implementations")
        }
        .tessera_env$lib_loaded <- FALSE
        return(FALSE)
    }
    
    tryCatch({
        # Load the shared library
        dyn.load(lib_path)
        .tessera_env$lib_path <- lib_path
        .tessera_env$lib_handle <- lib_path
        .tessera_env$lib_loaded <- TRUE
        
        # Verify the library works
        if (tessera_verify_library()) {
            if (verbose) {
                version <- tessera_get_version()
                simd_available <- tessera_has_simd()
                message(sprintf("✅ Tessera vector operations loaded successfully"))
                message(sprintf("   Library: %s", lib_path))
                message(sprintf("   Version: %s", version))
                message(sprintf("   SIMD: %s", if(simd_available) "Available" else "Not available"))
            }
            return(TRUE)
        } else {
            stop("Library verification failed")
        }
    }, error = function(e) {
        if (verbose) {
            message(sprintf("❌ Failed to load Tessera library: %s", e$message))
            message("   Using R fallback implementations")
        }
        .tessera_env$lib_loaded <- FALSE
        return(FALSE)
    })
}

# Find the shared library
tessera_find_library <- function() {
    search_paths <- tessera_get_search_paths()
    
    for (path in search_paths) {
        if (file.exists(path)) {
            return(path)
        }
    }
    
    return(NULL)
}

# Get search paths for the library
tessera_get_search_paths <- function() {
    script_dir <- tryCatch({
        dirname(sys.frame(1)$ofile)
    }, error = function(e) {
        getwd()
    })
    
    # Determine library extension based on OS
    lib_ext <- switch(Sys.info()["sysname"],
        "Darwin" = "dylib",
        "Linux" = "so",
        "Windows" = "dll",
        "so"  # default
    )
    
    lib_name <- paste0("libtessera_vector_ops_r.", lib_ext)
    
    return(c(
        # Relative to R script location
        file.path(script_dir, "..", "..", "..", "zig-out", "lib", lib_name),
        file.path(script_dir, "..", "..", "zig-out", "lib", lib_name),
        file.path(script_dir, "..", "zig-out", "lib", lib_name),
        file.path(script_dir, "zig-out", "lib", lib_name),
        
        # Relative to working directory
        file.path(".", "backend", "zig-backend", "zig-out", "lib", lib_name),
        file.path(".", "zig-backend", "zig-out", "lib", lib_name),
        file.path(".", "zig-out", "lib", lib_name),
        
        # System paths
        file.path("/usr/local/lib", lib_name),
        file.path("/usr/lib", lib_name),
        
        # Current directory
        file.path(".", lib_name)
    ))
}

# Verify library functionality
tessera_verify_library <- function() {
    if (!.tessera_env$lib_loaded) return(FALSE)
    
    tryCatch({
        # Test basic function call
        test_vec1 <- as.single(c(1.0, 0.0, 0.0))
        test_vec2 <- as.single(c(1.0, 0.0, 0.0))
        result <- .C("cosine_similarity",
                    vec1 = test_vec1,
                    vec2 = test_vec2,
                    len = as.integer(3),
                    result = as.single(0.0))
        
        # Should return 1.0 for identical unit vectors
        return(abs(result$result - 1.0) < 1e-6)
    }, error = function(e) {
        return(FALSE)
    })
}

# Get library version
tessera_get_version <- function() {
    if (!.tessera_env$lib_loaded) return("R fallback")
    
    tryCatch({
        # The version function returns a C string pointer, which is tricky in R
        # For now, just return a static version
        return("1.0.0")
    }, error = function(e) {
        return("Unknown")
    })
}

# Check if SIMD is available
tessera_has_simd <- function() {
    if (!.tessera_env$lib_loaded) return(FALSE)
    
    tryCatch({
        result <- .C("tessera_has_simd", 
                    has_simd = as.integer(0))
        return(result$has_simd == 1)
    }, error = function(e) {
        return(FALSE)
    })
}

# Check if Tessera is available
tessera_is_available <- function() {
    return(.tessera_env$lib_loaded)
}

# High-performance cosine similarity
tessera_cosine_similarity <- function(vec1, vec2) {
    if (!.tessera_env$lib_loaded) {
        return(r_cosine_similarity(vec1, vec2))
    }
    
    if (length(vec1) != length(vec2)) {
        return(0.0)
    }
    
    tryCatch({
        # Convert to numeric vectors
        v1 <- as.single(as.numeric(vec1))
        v2 <- as.single(as.numeric(vec2))
        
        # Call Zig function with proper C interface
        result <- .C("cosine_similarity",
                    vec1 = v1,
                    vec2 = v2,
                    len = as.integer(length(v1)),
                    result = as.single(0.0))
        
        return(as.numeric(result$result))
    }, error = function(e) {
        warning(sprintf("Tessera cosine similarity failed: %s. Using R fallback.", e$message))
        return(r_cosine_similarity(vec1, vec2))
    })
}

# High-performance batch cosine similarity
tessera_batch_cosine_similarity <- function(query, embeddings_matrix) {
    if (!.tessera_env$lib_loaded) {
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
        # Prepare data - ensure proper memory layout
        query_vec <- as.single(as.numeric(query))
        # Convert to row-major order (C-style)
        embeddings_vec <- as.single(as.numeric(t(embeddings_matrix)))
        results <- single(num_embeddings)
        
        # Call Zig function
        result <- .C("batch_cosine_similarity",
                    query = query_vec,
                    embeddings = embeddings_vec,
                    num_embeddings = as.integer(num_embeddings),
                    vector_dim = as.integer(vector_dim),
                    results = results)
        
        return(as.numeric(result$results))
    }, error = function(e) {
        warning(sprintf("Tessera batch similarity failed: %s. Using R fallback.", e$message))
        return(r_batch_cosine_similarity(query, embeddings_matrix))
    })
}

# Batch similarity with threshold filtering
tessera_batch_similarity_with_threshold <- function(query, embeddings_matrix, threshold = 0.3) {
    if (!.tessera_env$lib_loaded) {
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
        results <- single(num_embeddings)
        indices <- integer(num_embeddings)
        
        # Call Zig function
        result <- .C("batch_similarity_with_threshold",
                    query = query_vec,
                    embeddings = embeddings_vec,
                    num_embeddings = as.integer(num_embeddings),
                    vector_dim = as.integer(vector_dim),
                    threshold = as.single(threshold),
                    results = results,
                    indices = indices,
                    count_out = as.integer(0))
        
        # Extract results based on the returned count
        count <- result$count_out
        
        if (count > 0) {
            return(list(
                similarities = result$results[1:count],
                indices = result$indices[1:count] + 1  # Convert to 1-based indexing
            ))
        } else {
            return(list(similarities = numeric(0), indices = integer(0)))
        }
    }, error = function(e) {
        warning(sprintf("Tessera threshold similarity failed: %s. Using R fallback.", e$message))
        return(r_batch_similarity_with_threshold(query, embeddings_matrix, threshold))
    })
}

# R fallback implementations (optimized)
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
    
    # Vectorized R implementation
    query_norm <- sqrt(sum(query^2))
    if (query_norm == 0) return(rep(0, nrow(embeddings_matrix)))
    
    # Normalize query
    query_normalized <- query / query_norm
    
    # Calculate norms for all embeddings
    embedding_norms <- sqrt(rowSums(embeddings_matrix^2))
    
    # Avoid division by zero
    valid_norms <- embedding_norms > 0
    results <- numeric(nrow(embeddings_matrix))
    
    if (any(valid_norms)) {
        # Vectorized dot product
        dot_products <- embeddings_matrix[valid_norms, , drop = FALSE] %*% query_normalized
        results[valid_norms] <- dot_products / embedding_norms[valid_norms]
    }
    
    return(results)
}

r_batch_similarity_with_threshold <- function(query, embeddings_matrix, threshold = 0.3) {
    similarities <- r_batch_cosine_similarity(query, embeddings_matrix)
    above_threshold <- similarities >= threshold
    
    return(list(
        similarities = similarities[above_threshold],
        indices = which(above_threshold)
    ))
}

# Enhanced functions that automatically choose best implementation
enhanced_cosine_similarity <- function(vec1, vec2) {
    if (.tessera_env$lib_loaded) {
        return(tessera_cosine_similarity(vec1, vec2))
    } else {
        return(r_cosine_similarity(vec1, vec2))
    }
}

enhanced_batch_cosine_similarity <- function(query, embeddings_matrix) {
    # Use Tessera for larger datasets where the overhead is worth it
    if (.tessera_env$lib_loaded && nrow(embeddings_matrix) > 50) {
        return(tessera_batch_cosine_similarity(query, embeddings_matrix))
    } else {
        return(r_batch_cosine_similarity(query, embeddings_matrix))
    }
}

enhanced_batch_similarity_with_threshold <- function(query, embeddings_matrix, threshold = 0.3) {
    if (.tessera_env$lib_loaded && nrow(embeddings_matrix) > 50) {
        return(tessera_batch_similarity_with_threshold(query, embeddings_matrix, threshold))
    } else {
        return(r_batch_similarity_with_threshold(query, embeddings_matrix, threshold))
    }
}

# Benchmarking function
tessera_benchmark <- function(vector_dim = 384, num_embeddings = 1000, iterations = 5) {
    message("🧪 Benchmarking Tessera vs R vector operations...")
    
    # Generate test data
    set.seed(42)
    query <- rnorm(vector_dim)
    embeddings <- matrix(rnorm(num_embeddings * vector_dim), nrow = num_embeddings)
    
    # Normalize vectors for proper cosine similarity
    query <- query / sqrt(sum(query^2))
    embeddings <- embeddings / sqrt(rowSums(embeddings^2))
    
    results <- list()
    
    if (.tessera_env$lib_loaded) {
        # Benchmark Tessera
        tessera_times <- numeric(iterations)
        for (i in 1:iterations) {
            tessera_times[i] <- system.time({
                tessera_results <- tessera_batch_cosine_similarity(query, embeddings)
            })[3]
        }
        
        # Benchmark R
        r_times <- numeric(iterations)
        for (i in 1:iterations) {
            r_times[i] <- system.time({
                r_results <- r_batch_cosine_similarity(query, embeddings)
            })[3]
        }
        
        # Check accuracy
        accuracy <- all.equal(tessera_results, r_results, tolerance = 1e-5)
        
        tessera_mean <- mean(tessera_times)
        r_mean <- mean(r_times)
        speedup <- r_mean / tessera_mean
        
        message(sprintf("📊 Results (averaged over %d iterations):", iterations))
        message(sprintf("   Vector dimension: %d", vector_dim))
        message(sprintf("   Number of embeddings: %d", num_embeddings))
        message(sprintf("   Tessera time: %.2f ± %.2f ms", tessera_mean * 1000, sd(tessera_times) * 1000))
        message(sprintf("   R time: %.2f ± %.2f ms", r_mean * 1000, sd(r_times) * 1000))
        message(sprintf("   Speedup: %.1fx", speedup))
        message(sprintf("   Results match: %s", if(isTRUE(accuracy)) "✅ Yes" else "❌ No"))
        
        results <- list(
            tessera_time = tessera_mean,
            r_time = r_mean,
            speedup = speedup,
            accuracy = accuracy,
            tessera_times = tessera_times,
            r_times = r_times
        )
    } else {
        message("❌ Tessera not available, only R timing:")
        r_times <- numeric(iterations)
        for (i in 1:iterations) {
            r_times[i] <- system.time({
                r_results <- r_batch_cosine_similarity(query, embeddings)
            })[3]
        }
        
        r_mean <- mean(r_times)
        message(sprintf("   R time: %.2f ± %.2f ms", r_mean * 1000, sd(r_times) * 1000))
        
        results <- list(r_time = r_mean, r_times = r_times)
    }
    
    return(invisible(results))
}

# Cleanup function
tessera_cleanup <- function() {
    if (.tessera_env$lib_loaded && !is.null(.tessera_env$lib_handle)) {
        tryCatch({
            dyn.unload(.tessera_env$lib_handle)
        }, error = function(e) {
            # Ignore errors during cleanup
        })
        .tessera_env$lib_loaded <- FALSE
        .tessera_env$lib_path <- NULL
        .tessera_env$lib_handle <- NULL
    }
}

# Auto-initialize when sourced
if (!exists(".tessera_init_attempted", envir = .GlobalEnv)) {
    assign(".tessera_init_attempted", TRUE, envir = .GlobalEnv)
    tessera_init(verbose = TRUE)
}

# Register cleanup on exit
reg.finalizer(.tessera_env, tessera_cleanup, onexit = TRUE)

# Export main functions
if (!exists("tessera_loaded", envir = .GlobalEnv)) {
    assign("tessera_loaded", TRUE, envir = .GlobalEnv)
    message("📦 Tessera Vector Operations for R loaded")
    if (.tessera_env$lib_loaded) {
        message("⚡ Zig acceleration available")
    } else {
        message("🔄 Using R fallback implementations")
    }
}
