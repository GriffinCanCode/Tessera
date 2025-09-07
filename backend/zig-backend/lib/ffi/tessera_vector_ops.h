#ifndef TESSERA_VECTOR_OPS_H
#define TESSERA_VECTOR_OPS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>
#include <stdint.h>

// Function declarations for R FFI compatibility
// All functions use C calling convention and are exported

/**
 * Calculate cosine similarity between two vectors
 * @param vec1 First vector (float array)
 * @param vec2 Second vector (float array) 
 * @param len Length of both vectors
 * @return Cosine similarity value between -1.0 and 1.0
 */
float cosine_similarity(const float* vec1, const float* vec2, size_t len);

/**
 * Calculate cosine similarity between a query vector and multiple embedding vectors
 * @param query Query vector (float array)
 * @param embeddings Flattened matrix of embeddings (row-major order)
 * @param num_embeddings Number of embedding vectors
 * @param vector_dim Dimension of each vector
 * @param results Output array for similarity results
 */
void batch_cosine_similarity(
    const float* query,
    const float* embeddings,
    size_t num_embeddings,
    size_t vector_dim,
    float* results
);

/**
 * Calculate cosine similarity with threshold filtering
 * @param query Query vector (float array)
 * @param embeddings Flattened matrix of embeddings (row-major order)
 * @param num_embeddings Number of embedding vectors
 * @param vector_dim Dimension of each vector
 * @param threshold Minimum similarity threshold
 * @param results Output array for similarity results (must be pre-allocated)
 * @param indices Output array for indices of results above threshold (must be pre-allocated)
 * @return Number of results above threshold
 */
size_t batch_similarity_with_threshold(
    const float* query,
    const float* embeddings,
    size_t num_embeddings,
    size_t vector_dim,
    float threshold,
    float* results,
    uint32_t* indices
);

/**
 * Normalize a vector in-place to unit length
 * @param vec Vector to normalize (modified in-place)
 * @param len Length of the vector
 */
void normalize_vector(float* vec, size_t len);

/**
 * Calculate the magnitude (L2 norm) of a vector
 * @param vec Input vector (float array)
 * @param len Length of the vector
 * @return Magnitude of the vector
 */
float vector_magnitude(const float* vec, size_t len);

/**
 * Get library version information
 * @return Version string
 */
const char* tessera_vector_ops_version(void);

/**
 * Check if SIMD optimizations are available
 * @return 1 if SIMD is available, 0 otherwise
 */
int tessera_has_simd(void);

#ifdef __cplusplus
}
#endif

#endif // TESSERA_VECTOR_OPS_H
