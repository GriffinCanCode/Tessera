#!/usr/bin/env Rscript

# Simple test to verify R scripts are working
library(jsonlite)

cat("=== Simple R Script Test ===\n")

# Test graph analysis
cat("Testing graph analysis...\n")
graph_json <- '{"nodes": {"A": {"id": "A", "title": "Node A"}, "B": {"id": "B", "title": "Node B"}}, "edges": [{"from": "A", "to": "B", "weight": 1.0}]}'
result <- system(paste("cd ../r_scripts && Rscript graph_analysis.R", shQuote(graph_json)), intern = TRUE)
graph_result <- fromJSON(paste(result, collapse = ""))

if ("error" %in% names(graph_result)) {
    cat("❌ Graph analysis failed:", graph_result$error, "\n")
} else {
    cat("✅ Graph analysis working - found", graph_result$enhanced_metrics$node_count, "nodes\n")
}

# Test layout algorithms
cat("Testing layout algorithms...\n")
result <- system(paste("cd ../r_scripts && Rscript layout_algorithms.R", shQuote(graph_json)), intern = TRUE)
layout_result <- fromJSON(paste(result, collapse = ""))

if ("error" %in% names(layout_result)) {
    cat("❌ Layout algorithms failed:", layout_result$error, "\n")
} else {
    cat("✅ Layout algorithms working - found", length(layout_result$layouts), "layouts\n")
}

# Test temporal analysis
cat("Testing temporal analysis...\n")
temporal_json <- '{"articles": [{"id": "1", "title": "Article 1", "created_at": "2024-01-01", "categories": ["Science"]}], "links": [{"from": "1", "to": "1", "created_at": "2024-01-01"}]}'
result <- system(paste("cd ../r_scripts && Rscript temporal_analysis.R", shQuote(temporal_json)), intern = TRUE)
temporal_result <- fromJSON(paste(result, collapse = ""))

if ("error" %in% names(temporal_result)) {
    cat("❌ Temporal analysis failed:", temporal_result$error, "\n")
} else {
    cat("✅ Temporal analysis working\n")
}

cat("\n=== Test Complete ===\n")
