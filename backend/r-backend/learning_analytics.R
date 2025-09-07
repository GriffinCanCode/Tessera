#!/usr/bin/env Rscript

# Learning Analytics for Personal Learning Tracker
# Analyzes learning progress, subject relationships, and knowledge acquisition patterns

suppressPackageStartupMessages({
    library(igraph)
    library(jsonlite)
    library(cluster)
    library(stats)
})

# Main function to analyze learning patterns
analyze_learning_data <- function(json_input) {
    tryCatch({
        # Parse input data
        data <- fromJSON(json_input)
        
        # Handle empty data case
        if (is.null(data$content) || length(data$content) == 0) {
            return(create_empty_analysis())
        }
        
        # Analyze different aspects of learning
        result <- list(
            subject_analysis = analyze_subjects(data),
            progress_analysis = analyze_progress(data),
            content_clustering = cluster_content(data),
            learning_velocity = calculate_velocity(data),
            knowledge_gaps = identify_gaps(data),
            recommendations = generate_recommendations(data)
        )
        
        return(toJSON(result, pretty = TRUE, auto_unbox = TRUE))
        
    }, error = function(e) {
        error_result <- list(error = paste("Learning Analytics Error:", e$message))
        return(toJSON(error_result, auto_unbox = TRUE))
    })
}

# Analyze subjects and their relationships
analyze_subjects <- function(data) {
    subjects <- data$subjects
    content <- data$content
    progress <- data$progress
    
    if (is.null(subjects) || length(subjects) == 0) {
        return(list(
            total_subjects = 0,
            subject_progress = list(),
            subject_connections = list(),
            mastery_levels = list()
        ))
    }
    
    # Calculate subject progress
    subject_progress <- lapply(subjects, function(subject) {
        subject_content <- content[sapply(content, function(c) subject$id %in% c$subject_ids)]
        
        if (length(subject_content) == 0) {
            return(list(
                subject_id = subject$id,
                subject_name = subject$name,
                total_content = 0,
                completed_content = 0,
                avg_completion = 0,
                time_invested = 0,
                difficulty_distribution = list()
            ))
        }
        
        completions <- sapply(subject_content, function(c) c$completion_percentage %||% 0)
        times <- sapply(subject_content, function(c) c$actual_time_minutes %||% 0)
        difficulties <- sapply(subject_content, function(c) c$difficulty_level %||% 1)
        
        list(
            subject_id = subject$id,
            subject_name = subject$name,
            total_content = length(subject_content),
            completed_content = sum(completions >= 100),
            avg_completion = mean(completions),
            time_invested = sum(times),
            difficulty_distribution = table(difficulties)
        )
    })
    
    # Detect subject connections based on shared content
    subject_connections <- detect_subject_connections(content, subjects)
    
    # Calculate mastery levels
    mastery_levels <- calculate_mastery_levels(subject_progress)
    
    return(list(
        total_subjects = length(subjects),
        subject_progress = subject_progress,
        subject_connections = subject_connections,
        mastery_levels = mastery_levels
    ))
}

# Analyze learning progress over time
analyze_progress <- function(data) {
    progress <- data$progress
    content <- data$content
    
    if (is.null(progress) || length(progress) == 0) {
        return(list(
            total_sessions = 0,
            avg_session_time = 0,
            learning_streak = 0,
            progress_trend = list(),
            weekly_summary = list()
        ))
    }
    
    # Convert timestamps and analyze patterns
    session_dates <- as.Date(sapply(progress, function(p) as.POSIXct(p$session_date, origin="1970-01-01")))
    session_times <- sapply(progress, function(p) p$time_spent_minutes %||% 0)
    
    # Calculate learning streak
    learning_streak <- calculate_learning_streak(session_dates)
    
    # Analyze progress trend
    progress_trend <- analyze_progress_trend(progress, content)
    
    # Weekly summary
    weekly_summary <- calculate_weekly_summary(progress)
    
    return(list(
        total_sessions = length(progress),
        avg_session_time = mean(session_times),
        learning_streak = learning_streak,
        progress_trend = progress_trend,
        weekly_summary = weekly_summary
    ))
}

# Cluster content based on similarity
cluster_content <- function(data) {
    content <- data$content
    
    if (is.null(content) || length(content) < 3) {
        return(list(clusters = list(), method = "insufficient_data"))
    }
    
    # Use TF-IDF text similarity for clustering
    return(cluster_by_tfidf(content))
}

# Cluster content using embeddings
cluster_by_embeddings <- function(content, embeddings) {
    tryCatch({
        # Convert embeddings to matrix
        embedding_matrix <- do.call(rbind, embeddings)
        
        # Perform k-means clustering
        k <- min(5, nrow(embedding_matrix) - 1)  # Max 5 clusters or n-1
        if (k < 2) return(list(clusters = list(), cluster_analysis = list()))
        
        kmeans_result <- kmeans(embedding_matrix, centers = k, nstart = 10)
        
        # Assign clusters to content
        clusters <- split(seq_along(content), kmeans_result$cluster)
        names(clusters) <- paste("Cluster", seq_along(clusters))
        
        # Analyze clusters
        cluster_analysis <- lapply(clusters, function(cluster_indices) {
            cluster_content <- content[cluster_indices]
            subjects <- unique(unlist(lapply(cluster_content, function(c) c$subjects)))
            types <- table(sapply(cluster_content, function(c) c$content_type))
            avg_difficulty <- mean(sapply(cluster_content, function(c) c$difficulty_level %||% 1))
            
            list(
                size = length(cluster_indices),
                subjects = subjects,
                content_types = types,
                avg_difficulty = avg_difficulty
            )
        })
        
        return(list(
            clusters = clusters,
            cluster_analysis = cluster_analysis,
            total_clusters = k
        ))
        
    }, error = function(e) {
        return(list(clusters = list(), cluster_analysis = list(), error = e$message))
    })
}

# Cluster content by metadata
cluster_by_metadata <- function(content) {
    # Create feature matrix based on subjects and content types
    all_subjects <- unique(unlist(lapply(content, function(c) c$subjects)))
    all_types <- unique(sapply(content, function(c) c$content_type))
    
    # Create binary feature matrix
    feature_matrix <- matrix(0, nrow = length(content), ncol = length(all_subjects) + length(all_types))
    
    for (i in seq_along(content)) {
        # Subject features
        content_subjects <- content[[i]]$subjects
        if (!is.null(content_subjects)) {
            subject_indices <- which(all_subjects %in% content_subjects)
            feature_matrix[i, subject_indices] <- 1
        }
        
        # Type features
        content_type <- content[[i]]$content_type
        if (!is.null(content_type)) {
            type_index <- which(all_types == content_type) + length(all_subjects)
            if (length(type_index) > 0) {
                feature_matrix[i, type_index] <- 1
            }
        }
    }
    
    # Perform hierarchical clustering
    if (nrow(feature_matrix) > 1) {
        dist_matrix <- dist(feature_matrix, method = "binary")
        hclust_result <- hclust(dist_matrix, method = "ward.D2")
        
        # Cut tree to get clusters
        k <- min(4, nrow(feature_matrix) - 1)
        cluster_assignments <- cutree(hclust_result, k = k)
        
        clusters <- split(seq_along(content), cluster_assignments)
        names(clusters) <- paste("Group", seq_along(clusters))
        
        return(list(
            clusters = clusters,
            method = "metadata_based",
            total_clusters = k
        ))
    }
    
    return(list(clusters = list(), method = "insufficient_data"))
}

# Calculate learning velocity based on relative knowledge depth changes
calculate_velocity <- function(data) {
    content <- data$content
    
    if (is.null(content) || length(content) < 2) {
        return(list(
            knowledge_velocity = 0,
            trend = "insufficient_data",
            consistency = 0
        ))
    }
    
    # Calculate content weights and relative knowledge depth
    weights <- sapply(content, calculate_content_weight)
    consumed_weights <- weights * (sapply(content, function(c) c$completion_percentage %||% 0) / 100)
    
    # Group by subject and calculate relative knowledge depth (RKD)
    subjects <- unique(sapply(content, function(c) c$subject_id %||% "unknown"))
    rkd_by_subject <- list()
    
    for (subject in subjects) {
        subject_content <- content[sapply(content, function(c) (c$subject_id %||% "unknown") == subject)]
        subject_weights <- weights[sapply(content, function(c) (c$subject_id %||% "unknown") == subject)]
        subject_consumed <- consumed_weights[sapply(content, function(c) (c$subject_id %||% "unknown") == subject)]
        
        # Relative Knowledge Depth = consumed_weight / total_available_weight
        rkd <- sum(subject_consumed) / sum(subject_weights)
        rkd_by_subject[[subject]] <- rkd
    }
    
    # Calculate overall knowledge velocity (average RKD across subjects)
    knowledge_velocity <- mean(unlist(rkd_by_subject))
    
    # Determine trend based on completion distribution
    completions <- sapply(content, function(c) c$completion_percentage %||% 0)
    high_completion <- sum(completions > 70) / length(completions)
    
    trend <- if (high_completion > 0.6) "accelerating" 
             else if (high_completion > 0.3) "steady" 
             else "building"
    
    # Calculate consistency (how evenly distributed learning is across subjects)
    consistency <- 1 - (sd(unlist(rkd_by_subject)) / mean(unlist(rkd_by_subject)))
    consistency <- max(0, min(1, consistency))  # Clamp to [0,1]
    
    return(list(
        knowledge_velocity = knowledge_velocity,
        trend = trend,
        consistency = consistency,
        subject_depths = rkd_by_subject
    ))
}

# Calculate content weight based on length and complexity
calculate_content_weight <- function(content_item) {
    # Base weight
    base_weight <- 1.0
    
    # Length factor (log scale to prevent huge articles from dominating)
    content_length <- nchar(content_item$content %||% content_item$summary %||% "")
    if (content_length == 0) content_length <- 100  # Default for empty content
    
    length_factor <- log(content_length + 1) / log(1000)  # Normalized to ~1000 char baseline
    
    # Difficulty factor
    difficulty_factor <- (content_item$difficulty_level %||% 3) / 3.0
    
    # Content type factor
    type_factor <- switch(content_item$content_type %||% "article",
        "book" = 2.0,
        "course" = 1.8,
        "article" = 1.0,
        "video" = 0.8,
        "youtube" = 0.6,
        "text" = 0.4,
        "poetry" = 0.3,
        1.0  # default
    )
    
    return(base_weight * length_factor * difficulty_factor * type_factor)
}

# Identify knowledge gaps
identify_gaps <- function(data) {
    subjects <- data$subjects
    content <- data$content
    
    if (is.null(subjects) || is.null(content)) {
        return(list(gaps = list(), recommendations = list()))
    }
    
    gaps <- list()
    
    for (subject in subjects) {
        subject_content <- content[sapply(content, function(c) subject$id %in% c$subject_ids)]
        
        if (length(subject_content) == 0) {
            gaps[[length(gaps) + 1]] <- list(
                subject_id = subject$id,
                subject_name = subject$name,
                gap_type = "no_content",
                severity = "high",
                description = "No learning content available"
            )
            next
        }
        
        # Check difficulty progression
        difficulties <- sapply(subject_content, function(c) c$difficulty_level %||% 1)
        completions <- sapply(subject_content, function(c) c$completion_percentage %||% 0)
        
        # Identify missing difficulty levels
        available_levels <- unique(difficulties)
        expected_levels <- 1:5
        missing_levels <- setdiff(expected_levels, available_levels)
        
        if (length(missing_levels) > 0) {
            gaps[[length(gaps) + 1]] <- list(
                subject_id = subject$id,
                subject_name = subject$name,
                gap_type = "difficulty_gap",
                missing_levels = missing_levels,
                severity = if (length(missing_levels) > 2) "high" else "medium",
                description = paste("Missing difficulty levels:", paste(missing_levels, collapse = ", "))
            )
        }
        
        # Check for incomplete content
        incomplete_content <- subject_content[completions < 100 & completions > 0]
        if (length(incomplete_content) > 0) {
            gaps[[length(gaps) + 1]] <- list(
                subject_id = subject$id,
                subject_name = subject$name,
                gap_type = "incomplete_content",
                count = length(incomplete_content),
                severity = "medium",
                description = paste(length(incomplete_content), "pieces of content partially completed")
            )
        }
    }
    
    return(list(
        gaps = gaps,
        total_gaps = length(gaps)
    ))
}

# Generate learning recommendations
generate_recommendations <- function(data) {
    subjects <- data$subjects
    content <- data$content
    progress <- data$progress
    
    recommendations <- list()
    
    if (is.null(subjects) || is.null(content)) {
        return(list(recommendations = recommendations))
    }
    
    for (subject in subjects) {
        subject_content <- content[sapply(content, function(c) subject$id %in% c$subject_ids)]
        
        if (length(subject_content) == 0) next
        
        completions <- sapply(subject_content, function(c) c$completion_percentage %||% 0)
        difficulties <- sapply(subject_content, function(c) c$difficulty_level %||% 1)
        
        # Recommend next content based on difficulty progression
        completed_content <- subject_content[completions >= 100]
        incomplete_content <- subject_content[completions < 100 & completions > 0]
        unstarted_content <- subject_content[completions == 0]
        
        if (length(completed_content) > 0) {
            max_completed_difficulty <- max(sapply(completed_content, function(c) c$difficulty_level %||% 1))
            next_difficulty <- min(max_completed_difficulty + 1, 5)
            
            next_content <- unstarted_content[sapply(unstarted_content, function(c) (c$difficulty_level %||% 1) == next_difficulty)]
            
            if (length(next_content) > 0) {
                recommendations[[length(recommendations) + 1]] <- list(
                    subject_id = subject$id,
                    subject_name = subject$name,
                    type = "progression",
                    content_ids = sapply(next_content, function(c) c$id),
                    priority = "high",
                    reason = paste("Ready for difficulty level", next_difficulty)
                )
            }
        }
        
        # Recommend completing partially finished content
        if (length(incomplete_content) > 0) {
            recommendations[[length(recommendations) + 1]] <- list(
                subject_id = subject$id,
                subject_name = subject$name,
                type = "completion",
                content_ids = sapply(incomplete_content, function(c) c$id),
                priority = "medium",
                reason = "Complete partially finished content"
            )
        }
    }
    
    return(list(
        recommendations = recommendations,
        total_recommendations = length(recommendations)
    ))
}

# Helper functions
detect_subject_connections <- function(content, subjects) {
    connections <- list()
    
    for (i in seq_along(subjects)) {
        for (j in seq_along(subjects)) {
            if (i >= j) next
            
            subject1 <- subjects[[i]]
            subject2 <- subjects[[j]]
            
            # Count shared content
            shared_content <- content[sapply(content, function(c) {
                subject1$id %in% c$subject_ids && subject2$id %in% c$subject_ids
            })]
            
            if (length(shared_content) > 0) {
                connections[[length(connections) + 1]] <- list(
                    from_subject = subject1$name,
                    to_subject = subject2$name,
                    shared_content_count = length(shared_content),
                    strength = length(shared_content) / max(1, length(content))
                )
            }
        }
    }
    
    return(connections)
}

calculate_mastery_levels <- function(subject_progress) {
    lapply(subject_progress, function(sp) {
        if (sp$total_content == 0) {
            return(list(subject_name = sp$subject_name, mastery_level = "novice", mastery_score = 0))
        }
        
        completion_rate <- sp$completed_content / sp$total_content
        avg_completion <- sp$avg_completion / 100
        
        mastery_score <- (completion_rate * 0.7) + (avg_completion * 0.3)
        
        mastery_level <- if (mastery_score >= 0.9) "expert" else
                        if (mastery_score >= 0.7) "advanced" else
                        if (mastery_score >= 0.4) "intermediate" else
                        if (mastery_score >= 0.1) "beginner" else "novice"
        
        return(list(
            subject_name = sp$subject_name,
            mastery_level = mastery_level,
            mastery_score = mastery_score
        ))
    })
}

calculate_learning_streak <- function(session_dates) {
    if (length(session_dates) == 0) return(0)
    
    unique_dates <- sort(unique(session_dates))
    if (length(unique_dates) == 1) return(1)
    
    # Calculate consecutive days
    streak <- 1
    max_streak <- 1
    
    for (i in 2:length(unique_dates)) {
        if (as.numeric(unique_dates[i] - unique_dates[i-1]) == 1) {
            streak <- streak + 1
            max_streak <- max(max_streak, streak)
        } else {
            streak <- 1
        }
    }
    
    return(max_streak)
}

analyze_progress_trend <- function(progress, content) {
    if (length(progress) < 2) return(list(trend = "insufficient_data"))
    
    # Sort by date
    progress_sorted <- progress[order(sapply(progress, function(p) p$session_date))]
    
    dates <- sapply(progress_sorted, function(p) as.POSIXct(p$session_date, origin="1970-01-01"))
    deltas <- sapply(progress_sorted, function(p) p$progress_delta %||% 0)
    
    # Calculate trend using linear regression
    if (length(deltas) >= 3) {
        time_numeric <- as.numeric(dates - min(dates))
        trend_model <- lm(deltas ~ time_numeric)
        slope <- coef(trend_model)[2]
        
        trend_direction <- if (slope > 0.01) "improving" else if (slope < -0.01) "declining" else "stable"
    } else {
        trend_direction <- "insufficient_data"
    }
    
    return(list(
        trend = trend_direction,
        recent_progress = mean(tail(deltas, 5))
    ))
}

calculate_weekly_summary <- function(progress) {
    if (length(progress) == 0) return(list())
    
    dates <- as.Date(sapply(progress, function(p) as.POSIXct(p$session_date, origin="1970-01-01")))
    times <- sapply(progress, function(p) p$time_spent_minutes %||% 0)
    
    # Group by week
    weeks <- format(dates, "%Y-W%U")
    weekly_data <- aggregate(times, by = list(weeks), FUN = function(x) list(total_time = sum(x), session_count = length(x)))
    
    return(list(
        weeks = weekly_data$Group.1,
        weekly_stats = weekly_data$x
    ))
}

create_empty_analysis <- function() {
    return(toJSON(list(
        subject_analysis = list(total_subjects = 0),
        progress_analysis = list(total_sessions = 0),
        content_clustering = list(clusters = list()),
        learning_velocity = list(knowledge_velocity = 0),
        knowledge_gaps = list(gaps = list()),
        recommendations = list(recommendations = list())
    ), auto_unbox = TRUE))
}

# Cluster content by TF-IDF text similarity
cluster_by_tfidf <- function(content) {
    # Extract text content for analysis
    texts <- sapply(content, function(c) {
        text <- paste(c$title %||% "", c$summary %||% "", c$content %||% "", collapse = " ")
        # Clean and normalize text
        text <- tolower(gsub("[^a-zA-Z0-9\\s]", " ", text))
        text <- gsub("\\s+", " ", text)
        return(trimws(text))
    })
    
    # Filter out empty texts
    valid_indices <- which(nchar(texts) > 10)
    if (length(valid_indices) < 3) {
        return(list(clusters = list(), method = "insufficient_text"))
    }
    
    texts <- texts[valid_indices]
    valid_content <- content[valid_indices]
    
    tryCatch({
        # Simple TF-IDF implementation
        all_words <- unique(unlist(strsplit(texts, "\\s+")))
        all_words <- all_words[nchar(all_words) > 2]  # Filter short words
        
        if (length(all_words) < 5) {
            return(list(clusters = list(), method = "insufficient_vocabulary"))
        }
        
        # Calculate TF-IDF matrix
        tfidf_matrix <- calculate_tfidf_matrix(texts, all_words)
        
        # Calculate cosine similarity
        similarity_matrix <- calculate_cosine_similarity(tfidf_matrix)
        
        # Convert similarity to distance for clustering
        distance_matrix <- 1 - similarity_matrix
        
        # Hierarchical clustering
        k <- min(3, length(valid_content) - 1)
        hc <- hclust(as.dist(distance_matrix), method = "ward.D2")
        cluster_assignments <- cutree(hc, k = k)
        
        # Group content by cluster
        clustered_content <- list()
        for (i in 1:k) {
            cluster_items <- valid_content[cluster_assignments == i]
            cluster_similarities <- similarity_matrix[cluster_assignments == i, cluster_assignments == i]
            avg_similarity <- mean(cluster_similarities[upper.tri(cluster_similarities)])
            
            clustered_content[[paste0("cluster_", i)]] <- list(
                items = cluster_items,
                size = sum(cluster_assignments == i),
                avg_similarity = ifelse(is.na(avg_similarity), 0, avg_similarity),
                coherence = calculate_cluster_coherence(cluster_items)
            )
        }
        
        return(list(
            clusters = clustered_content, 
            method = "tfidf_hierarchical", 
            k = k,
            overall_similarity = mean(similarity_matrix[upper.tri(similarity_matrix)])
        ))
        
    }, error = function(e) {
        return(list(clusters = list(), method = "error", error = e$message))
    })
}

# Calculate TF-IDF matrix
calculate_tfidf_matrix <- function(texts, vocabulary) {
    n_docs <- length(texts)
    n_terms <- length(vocabulary)
    
    tfidf_matrix <- matrix(0, nrow = n_docs, ncol = n_terms)
    colnames(tfidf_matrix) <- vocabulary
    
    # Calculate TF-IDF for each document
    for (i in 1:n_docs) {
        words <- unlist(strsplit(texts[i], "\\s+"))
        word_counts <- table(words)
        
        for (j in 1:n_terms) {
            term <- vocabulary[j]
            tf <- as.numeric(word_counts[term]) / length(words)
            tf[is.na(tf)] <- 0
            
            # Document frequency
            df <- sum(sapply(texts, function(text) grepl(paste0("\\b", term, "\\b"), text)))
            idf <- log(n_docs / (df + 1))
            
            tfidf_matrix[i, j] <- tf * idf
        }
    }
    
    return(tfidf_matrix)
}

# Calculate cosine similarity between documents
calculate_cosine_similarity <- function(matrix) {
    n <- nrow(matrix)
    similarity <- matrix(0, nrow = n, ncol = n)
    
    for (i in 1:n) {
        for (j in 1:n) {
            if (i == j) {
                similarity[i, j] <- 1
            } else {
                dot_product <- sum(matrix[i, ] * matrix[j, ])
                norm_i <- sqrt(sum(matrix[i, ]^2))
                norm_j <- sqrt(sum(matrix[j, ]^2))
                
                if (norm_i > 0 && norm_j > 0) {
                    similarity[i, j] <- dot_product / (norm_i * norm_j)
                }
            }
        }
    }
    
    return(similarity)
}

# Calculate cluster coherence based on content weights and completion
calculate_cluster_coherence <- function(cluster_items) {
    if (length(cluster_items) < 2) return(1.0)
    
    weights <- sapply(cluster_items, calculate_content_weight)
    completions <- sapply(cluster_items, function(c) c$completion_percentage %||% 0)
    
    # Coherence = how evenly distributed the learning is within the cluster
    weight_distribution <- weights / sum(weights)
    completion_distribution <- completions / 100
    
    # Calculate weighted completion variance (lower = more coherent)
    weighted_completion <- sum(weight_distribution * completion_distribution)
    variance <- sum(weight_distribution * (completion_distribution - weighted_completion)^2)
    
    return(max(0, 1 - variance))  # Convert variance to coherence score
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

# Main execution
main <- function() {
    args <- commandArgs(trailingOnly = TRUE)
    
    if (length(args) == 0) {
        cat("Usage: Rscript learning_analytics.R '<json_input>'\n")
        cat("Input should include subjects, content, progress, and optionally embeddings\n")
        quit(status = 1)
    }
    
    result <- analyze_learning_data(args[1])
    cat(result)
}

if (sys.nframe() == 0) {
    main()
}
