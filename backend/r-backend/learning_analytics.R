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
    embeddings <- data$embeddings
    
    if (is.null(content) || length(content) < 2) {
        return(list(
            clusters = list(),
            cluster_analysis = list(),
            similarity_matrix = list()
        ))
    }
    
    # If embeddings are available, use them for clustering
    if (!is.null(embeddings) && length(embeddings) > 0) {
        return(cluster_by_embeddings(content, embeddings))
    }
    
    # Otherwise, cluster by metadata (subjects, difficulty, type)
    return(cluster_by_metadata(content))
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

# Calculate learning velocity
calculate_velocity <- function(data) {
    progress <- data$progress
    
    if (is.null(progress) || length(progress) < 2) {
        return(list(
            daily_velocity = 0,
            weekly_velocity = 0,
            acceleration = 0,
            trend = "insufficient_data"
        ))
    }
    
    # Sort progress by date
    progress_sorted <- progress[order(sapply(progress, function(p) p$session_date))]
    
    # Calculate daily progress
    dates <- as.Date(sapply(progress_sorted, function(p) as.POSIXct(p$session_date, origin="1970-01-01")))
    progress_deltas <- sapply(progress_sorted, function(p) p$progress_delta %||% 0)
    
    # Group by date and sum progress
    daily_progress <- aggregate(progress_deltas, by = list(dates), FUN = sum)
    
    if (nrow(daily_progress) < 2) {
        return(list(daily_velocity = mean(progress_deltas), weekly_velocity = sum(progress_deltas), acceleration = 0))
    }
    
    # Calculate velocity metrics
    daily_velocity <- mean(daily_progress$x)
    weekly_velocity <- daily_velocity * 7
    
    # Calculate acceleration (change in velocity over time)
    if (nrow(daily_progress) >= 3) {
        recent_velocity <- mean(tail(daily_progress$x, 3))
        older_velocity <- mean(head(daily_progress$x, 3))
        acceleration <- recent_velocity - older_velocity
    } else {
        acceleration <- 0
    }
    
    # Determine trend
    trend <- if (acceleration > 0.5) "accelerating" else if (acceleration < -0.5) "decelerating" else "stable"
    
    return(list(
        daily_velocity = daily_velocity,
        weekly_velocity = weekly_velocity,
        acceleration = acceleration,
        trend = trend
    ))
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
        learning_velocity = list(daily_velocity = 0),
        knowledge_gaps = list(gaps = list()),
        recommendations = list(recommendations = list())
    ), auto_unbox = TRUE))
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
