#!/usr/bin/env Rscript

# Tessera Numerical Computing Service
# High-performance R service for vector operations and similarity computations
# Designed to be called from Perl for optimal performance delegation

library(jsonlite)
library(httr)
library(plumber)

# Load our optimized vector operations with intelligent selection
source('/Users/griffinstrier/projects/Wikilizer/backend/zig-backend/lib/ffi/r/zig_vector_ops.R')

# Initialize optimized vector operations (with intelligent fallback)
cat("🚀 Initializing Tessera Numerical Service with Optimal Vector Operations...\n")
init_result <- init_zig_ops()

# Set global optimization strategy based on analysis
zig_available <- init_result
if (zig_available) {
    cat("✅ Zig optimizations available - using intelligent selection\n")
    cat("📊 Strategy: R-BLAS for batch ops, Zig for specialized workloads\n")
} else {
    cat("⚠️  Using optimized R-BLAS implementations\n")
}

#* @apiTitle Tessera Numerical Computing Service
#* @apiDescription High-performance numerical operations for Tessera
#* @apiVersion 1.0.0

#* Health check endpoint
#* @get /health
function() {
    list(
        status = "healthy",
        service = "tessera-numerical",
        version = "1.0.0",
        zig_available = exists("zig_available") && zig_available,
        timestamp = Sys.time()
    )
}

#* Get service capabilities and performance info
#* @get /capabilities
function() {
    list(
        vector_operations = list(
            cosine_similarity = TRUE,
            batch_cosine_similarity = TRUE,
            similarity_with_threshold = TRUE,
            vector_normalization = TRUE
        ),
        optimizations = list(
            zig_simd = exists("zig_available") && zig_available,
            r_blas = TRUE,
            intelligent_selection = TRUE
        ),
        performance = list(
            estimated_throughput = if (exists("zig_available") && zig_available) "1,500,000 ops/sec" else "800,000 ops/sec",
            recommended_batch_size = 1000,
            max_vector_dimension = 4096
        )
    )
}

#* Compute cosine similarity between two vectors
#* @post /cosine_similarity
function(req) {
    tryCatch({
        data <- fromJSON(rawToChar(req$postBody))
        
        # Validate input
        if (!is.list(data) || !("vec1" %in% names(data)) || !("vec2" %in% names(data))) {
            return(list(error = "Invalid input: requires 'vec1' and 'vec2' arrays"))
        }
        
        vec1 <- as.numeric(data$vec1)
        vec2 <- as.numeric(data$vec2)
        
        if (length(vec1) != length(vec2)) {
            return(list(error = "Vectors must have the same length"))
        }
        
        if (length(vec1) == 0) {
            return(list(error = "Vectors cannot be empty"))
        }
        
        # Use enhanced cosine similarity (intelligent Zig/R selection)
        similarity <- enhanced_cosine_similarity(vec1, vec2)
        
        list(
            similarity = similarity,
            method = if (exists("zig_available") && zig_available && length(vec1) > 50) "zig" else "r",
            vector_length = length(vec1)
        )
        
    }, error = function(e) {
        list(error = paste("Computation error:", e$message))
    })
}

#* Compute batch cosine similarities between query and multiple embeddings
#* @post /batch_cosine_similarity
function(req) {
    tryCatch({
        data <- fromJSON(rawToChar(req$postBody))
        
        # Validate input
        if (!is.list(data) || !("query" %in% names(data)) || !("embeddings" %in% names(data))) {
            return(list(error = "Invalid input: requires 'query' and 'embeddings' arrays"))
        }
        
        query <- as.numeric(data$query)
        embeddings <- data$embeddings
        
        if (length(query) == 0) {
            return(list(error = "Query vector cannot be empty"))
        }
        
        if (!is.list(embeddings) && !is.matrix(embeddings)) {
            return(list(error = "Embeddings must be a list of vectors or matrix"))
        }
        
        # Convert to matrix if needed
        if (is.list(embeddings)) {
            # Validate all embeddings have same length as query
            embedding_lengths <- sapply(embeddings, length)
            if (!all(embedding_lengths == length(query))) {
                return(list(error = "All embeddings must have same length as query"))
            }
            embeddings_matrix <- do.call(rbind, lapply(embeddings, as.numeric))
        } else {
            embeddings_matrix <- as.matrix(embeddings)
        }
        
        if (ncol(embeddings_matrix) != length(query)) {
            return(list(error = "Embedding dimensions must match query dimension"))
        }
        
        # Use enhanced batch cosine similarity
        start_time <- Sys.time()
        similarities <- enhanced_batch_cosine_similarity(query, embeddings_matrix)
        end_time <- Sys.time()
        
        processing_time <- as.numeric(difftime(end_time, start_time, units = "secs")) * 1000
        
        list(
            similarities = similarities,
            count = length(similarities),
            processing_time_ms = round(processing_time, 2),
            throughput = round(length(similarities) / (processing_time / 1000)),
            method = if (exists("zig_available") && zig_available && nrow(embeddings_matrix) > 100) "zig" else "r",
            vector_dimension = length(query)
        )
        
    }, error = function(e) {
        list(error = paste("Batch computation error:", e$message))
    })
}

#* Compute batch similarities with threshold filtering
#* @post /batch_similarity_threshold
function(req) {
    tryCatch({
        data <- fromJSON(rawToChar(req$postBody))
        
        # Validate input
        required_fields <- c("query", "embeddings", "threshold")
        if (!all(required_fields %in% names(data))) {
            return(list(error = paste("Invalid input: requires", paste(required_fields, collapse = ", "))))
        }
        
        query <- as.numeric(data$query)
        embeddings <- data$embeddings
        threshold <- as.numeric(data$threshold)
        
        if (length(threshold) != 1 || threshold < -1 || threshold > 1) {
            return(list(error = "Threshold must be a single number between -1 and 1"))
        }
        
        # Convert embeddings to matrix
        if (is.list(embeddings)) {
            embedding_lengths <- sapply(embeddings, length)
            if (!all(embedding_lengths == length(query))) {
                return(list(error = "All embeddings must have same length as query"))
            }
            embeddings_matrix <- do.call(rbind, lapply(embeddings, as.numeric))
        } else {
            embeddings_matrix <- as.matrix(embeddings)
        }
        
        # Use enhanced threshold filtering
        start_time <- Sys.time()
        results <- enhanced_batch_similarity_with_threshold(query, embeddings_matrix, threshold)
        end_time <- Sys.time()
        
        processing_time <- as.numeric(difftime(end_time, start_time, units = "secs")) * 1000
        
        list(
            results = results,
            total_embeddings = nrow(embeddings_matrix),
            matches_found = length(results),
            threshold = threshold,
            processing_time_ms = round(processing_time, 2),
            method = if (exists("zig_available") && zig_available) "zig" else "r"
        )
        
    }, error = function(e) {
        list(error = paste("Threshold filtering error:", e$message))
    })
}

#* Normalize a vector
#* @post /normalize_vector
function(req) {
    tryCatch({
        data <- fromJSON(rawToChar(req$postBody))
        
        if (!is.list(data) || !("vector" %in% names(data))) {
            return(list(error = "Invalid input: requires 'vector' array"))
        }
        
        vec <- as.numeric(data$vector)
        
        if (length(vec) == 0) {
            return(list(error = "Vector cannot be empty"))
        }
        
        # Normalize vector
        norm <- sqrt(sum(vec^2))
        if (norm == 0) {
            normalized <- rep(0, length(vec))
        } else {
            normalized <- vec / norm
        }
        
        list(
            normalized_vector = normalized,
            original_norm = norm,
            length = length(vec)
        )
        
    }, error = function(e) {
        list(error = paste("Normalization error:", e$message))
    })
}

#* Benchmark service performance
#* @post /benchmark
function(req) {
    tryCatch({
        data <- fromJSON(rawToChar(req$postBody))
        
        # Default benchmark parameters
        vector_dim <- if ("vector_dim" %in% names(data)) as.integer(data$vector_dim) else 384
        num_embeddings <- if ("num_embeddings" %in% names(data)) as.integer(data$num_embeddings) else 1000
        
        if (vector_dim < 1 || vector_dim > 4096) {
            return(list(error = "Vector dimension must be between 1 and 4096"))
        }
        
        if (num_embeddings < 1 || num_embeddings > 10000) {
            return(list(error = "Number of embeddings must be between 1 and 10000"))
        }
        
        cat(sprintf("🔥 Running benchmark: %d embeddings × %d dimensions\n", num_embeddings, vector_dim))
        
        # Generate test data
        set.seed(42)
        query <- rnorm(vector_dim)
        query <- query / sqrt(sum(query^2))  # Normalize
        
        embeddings_matrix <- matrix(rnorm(num_embeddings * vector_dim), nrow = num_embeddings, ncol = vector_dim)
        # Normalize embeddings
        norms <- sqrt(rowSums(embeddings_matrix^2))
        embeddings_matrix <- embeddings_matrix / norms
        
        # Benchmark batch cosine similarity
        start_time <- Sys.time()
        similarities <- enhanced_batch_cosine_similarity(query, embeddings_matrix)
        end_time <- Sys.time()
        
        processing_time <- as.numeric(difftime(end_time, start_time, units = "secs")) * 1000
        throughput <- num_embeddings / (processing_time / 1000)
        
        list(
            benchmark_results = list(
                vector_dimension = vector_dim,
                num_embeddings = num_embeddings,
                processing_time_ms = round(processing_time, 2),
                throughput_ops_per_sec = round(throughput),
                method_used = if (exists("zig_available") && zig_available && num_embeddings > 100) "zig" else "r",
                average_similarity = round(mean(similarities), 4),
                min_similarity = round(min(similarities), 4),
                max_similarity = round(max(similarities), 4)
            ),
            service_info = list(
                zig_available = exists("zig_available") && zig_available,
                r_version = R.version.string,
                blas_library = sessionInfo()$BLAS
            )
        )
        
    }, error = function(e) {
        list(error = paste("Benchmark error:", e$message))
    })
}

# Start the service
cat("🌟 Starting Tessera Numerical Service on port 8001...\n")
cat("📊 Service endpoints:\n")
cat("  • GET  /health - Health check\n")
cat("  • GET  /capabilities - Service capabilities\n")
cat("  • POST /cosine_similarity - Single similarity\n")
cat("  • POST /batch_cosine_similarity - Batch similarities\n")
cat("  • POST /batch_similarity_threshold - Threshold filtering\n")
cat("  • POST /normalize_vector - Vector normalization\n")
cat("  • POST /benchmark - Performance benchmark\n")
cat("\n🚀 Ready to serve high-performance numerical operations!\n")

# This will be called when script is run directly
if (!interactive()) {
    pr() %>%
        pr_run(host = "127.0.0.1", port = 8001)
}
