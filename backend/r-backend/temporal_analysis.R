#!/usr/bin/env Rscript

# Learning Progress Temporal Analysis
# Tracks learning journey evolution and knowledge acquisition patterns over time

suppressPackageStartupMessages({
    library(igraph)
    library(jsonlite)
})

# Main function to analyze learning temporal patterns
analyze_learning_patterns <- function(json_input) {
    tryCatch({
        # Parse input data (should include learning content and progress)
        learning_data <- fromJSON(json_input)
        
        # Handle empty data case gracefully
        if (is.null(learning_data$content) || length(learning_data$content) == 0) {
            result <- list(
                growth_analysis = list(
                    dates = character(0),
                    articles_cumulative = numeric(0),
                    links_cumulative = numeric(0)
                ),
                discovery_timeline = list(
                    discovery_timeline = list(),
                    major_discoveries = character(0),
                    category_evolution = list()
                ),
                knowledge_evolution = list(
                    depth_evolution = numeric(0),
                    complexity_evolution = numeric(0),
                    interconnectedness_evolution = numeric(0)
                ),
                learning_phases = list(
                    phases = character(0),
                    activity_patterns = list(),
                    intensity_scores = numeric(0)
                ),
                temporal_metrics = list(
                    total_days_active = 0,
                    avg_articles_per_day = 0,
                    peak_discovery_day = "N/A",
                    avg_links_per_day = 0,
                    peak_linking_day = "N/A"
                )
            )
        } else {
            # Analyze different temporal aspects
            growth_analysis <- analyze_growth_patterns(temporal_data)
            discovery_timeline <- analyze_discovery_timeline(temporal_data)
            knowledge_evolution <- analyze_knowledge_evolution(temporal_data)
            learning_phases <- identify_learning_phases(temporal_data)
            
            # Return comprehensive temporal analysis
            result <- list(
                growth_analysis = growth_analysis,
                discovery_timeline = discovery_timeline,
                knowledge_evolution = knowledge_evolution,
                learning_phases = learning_phases,
                temporal_metrics = calculate_temporal_metrics(temporal_data)
            )
        }
        
        return(toJSON(result, pretty = TRUE, auto_unbox = TRUE))
        
    }, error = function(e) {
        # Return valid JSON even for errors
        error_result <- list(
            error = paste("Temporal Analysis Error:", e$message),
            growth_analysis = list(dates = character(0), articles_cumulative = numeric(0)),
            discovery_timeline = list(major_discoveries = character(0)),
            knowledge_evolution = list(depth_evolution = numeric(0)),
            learning_phases = list(phases = character(0)),
            temporal_metrics = list(total_days_active = 0, avg_articles_per_day = 0)
        )
        return(toJSON(error_result, auto_unbox = TRUE))
    })
}

# Analyze how the knowledge graph grows over time
analyze_growth_patterns <- function(temporal_data) {
    growth_patterns <- list()
    
    # Extract temporal information
    articles <- temporal_data$articles
    links <- temporal_data$links
    
    if (is.null(articles) || is.null(links)) {
        return(list(error = "Missing temporal data"))
    }
    
    # Convert timestamps to dates with error handling
    article_dates <- tryCatch({
        if (is.null(articles) || length(articles) == 0 || !is.data.frame(articles)) {
            as.Date(character(0))
        } else {
            if ("created_at" %in% names(articles)) {
                timestamps <- articles$created_at
                # Handle different date formats
                dates <- as.Date(timestamps)
                dates[!is.na(dates)]
            } else {
                as.Date(character(0))
            }
        }
    }, error = function(e) as.Date(character(0)))
    
    link_dates <- tryCatch({
        if (is.null(links) || length(links) == 0 || !is.data.frame(links)) {
            as.Date(character(0))
        } else {
            if ("created_at" %in% names(links)) {
                timestamps <- links$created_at
                # Handle different date formats
                dates <- as.Date(timestamps)
                dates[!is.na(dates)]
            } else {
                as.Date(character(0))
            }
        }
    }, error = function(e) as.Date(character(0)))
    
    # Create daily time series with error handling
    date_range <- tryCatch({
        all_dates <- c(article_dates, link_dates)
        all_dates <- all_dates[!is.na(all_dates)]
        
        if (length(all_dates) == 0) {
            # Return empty range if no valid dates
            as.Date(character(0))
        } else {
            seq(from = min(all_dates), to = max(all_dates), by = "day")
        }
    }, error = function(e) {
        # Fallback to today's date if all else fails
        as.Date(Sys.Date())
    })
    
    # Calculate cumulative counts with handling for empty data
    if (length(date_range) == 0) {
        articles_cumulative <- numeric(0)
        links_cumulative <- numeric(0)
    } else {
        articles_cumulative <- sapply(date_range, function(d) sum(article_dates <= d, na.rm = TRUE))
        links_cumulative <- sapply(date_range, function(d) sum(link_dates <= d, na.rm = TRUE))
    }
    
    # Calculate daily additions and velocities with handling for empty data
    if (length(articles_cumulative) == 0) {
        articles_daily <- numeric(0)
        links_daily <- numeric(0)
        articles_velocity <- numeric(0)
        links_velocity <- numeric(0)
        articles_acceleration <- numeric(0)
        links_acceleration <- numeric(0)
    } else {
        articles_daily <- c(0, diff(articles_cumulative))
        links_daily <- c(0, diff(links_cumulative))
        
        # Growth velocity (rate of change)
        articles_velocity <- calculate_velocity(articles_cumulative)
        links_velocity <- calculate_velocity(links_cumulative)
        
        # Growth acceleration
        articles_acceleration <- c(0, diff(articles_velocity))
        links_acceleration <- c(0, diff(links_velocity))
    }
    
    growth_patterns <- list(
        dates = format(date_range, "%Y-%m-%d"),
        articles_cumulative = articles_cumulative,
        links_cumulative = links_cumulative,
        articles_daily = articles_daily,
        links_daily = links_daily,
        articles_velocity = articles_velocity,
        links_velocity = links_velocity,
        articles_acceleration = articles_acceleration,
        links_acceleration = links_acceleration,
        growth_rate = calculate_growth_rate(articles_cumulative, links_cumulative),
        knowledge_density_over_time = links_cumulative / pmax(articles_cumulative, 1)
    )
    
    return(growth_patterns)
}

# Analyze discovery timeline - when different topics were discovered
analyze_discovery_timeline <- function(temporal_data) {
    timeline <- list()
    
    articles <- temporal_data$articles
    if (is.null(articles)) return(list(error = "No articles data"))
    
    # Group by categories and time
    if (is.data.frame(articles)) {
        article_data <- articles
        # Ensure we have the required columns with defaults
        if (!"id" %in% names(article_data)) article_data$id <- 1:nrow(article_data)
        if (!"title" %in% names(article_data)) article_data$title <- "Unknown"
        if (!"created_at" %in% names(article_data)) article_data$created_at <- Sys.Date()
        if (!"categories" %in% names(article_data)) article_data$categories <- "General"
        
        article_data$created_at <- as.Date(article_data$created_at)
        article_data$category <- "General" # Simplified for now
    } else {
        # Fallback for old format
        article_data <- data.frame(
            id = sapply(articles, function(x) x$id %||% 1),
            title = sapply(articles, function(x) x$title %||% "Unknown"),
            created_at = as.Date(character(0)),
            category = sapply(articles, function(x) {
                cats <- x$categories
                if (is.null(cats) || length(cats) == 0) return("General")
                return(cats[1])
            }),
            stringsAsFactors = FALSE
        )
    }
    
    # Remove rows with invalid dates
    article_data <- article_data[!is.na(article_data$created_at), ]
    
    if (nrow(article_data) == 0) {
        return(list(error = "No valid temporal data"))
    }
    
    # Discovery milestones
    categories <- unique(article_data$category)
    milestones <- data.frame(
        category = categories,
        first_discovery = as.Date(sapply(categories, function(cat) {
            cat_data <- article_data[article_data$category == cat, ]
            min(cat_data$created_at)
        })),
        article_count = sapply(categories, function(cat) {
            sum(article_data$category == cat)
        }),
        representative_article = sapply(categories, function(cat) {
            cat_data <- article_data[article_data$category == cat, ]
            cat_data$title[which.min(cat_data$created_at)]
        }),
        stringsAsFactors = FALSE
    )
    milestones <- milestones[order(milestones$first_discovery), ]
    
    # Monthly discovery patterns
    article_data$year_month <- format(article_data$created_at, "%Y-%m")
    
    # Create monthly patterns data frame
    monthly_combinations <- unique(article_data[, c("year_month", "category")])
    monthly_discoveries <- data.frame(
        year_month = monthly_combinations$year_month,
        category = monthly_combinations$category,
        count = sapply(1:nrow(monthly_combinations), function(i) {
            sum(article_data$year_month == monthly_combinations$year_month[i] & 
                article_data$category == monthly_combinations$category[i])
        }),
        stringsAsFactors = FALSE
    )
    monthly_discoveries <- monthly_discoveries[order(monthly_discoveries$year_month), ]
    
    timeline <- list(
        discovery_milestones = milestones,
        monthly_patterns = monthly_discoveries,
        category_evolution = analyze_category_evolution(article_data),
        exploration_phases = identify_exploration_phases(article_data)
    )
    
    return(timeline)
}

# Analyze how knowledge structure evolves
analyze_knowledge_evolution <- function(temporal_data) {
    evolution <- list()
    
    # This would analyze how the graph structure changes over time
    # For now, provide basic evolution metrics
    articles <- temporal_data$articles
    links <- temporal_data$links
    
    if (is.null(articles) || is.null(links)) {
        return(list(error = "Missing data for evolution analysis"))
    }
    
    # Calculate knowledge depth evolution (avg links per article over time)
    dates <- unique(as.Date(c(
        if (is.data.frame(articles)) articles$created_at else character(0),
        if (is.data.frame(links)) links$created_at else character(0)
    )))
    dates <- dates[!is.na(dates)]
    dates <- sort(dates)
    
    depth_evolution <- sapply(dates, function(d) {
        articles_by_date <- if (is.data.frame(articles)) sum(as.Date(articles$created_at) <= d, na.rm = TRUE) else 0
        links_by_date <- if (is.data.frame(links)) sum(as.Date(links$created_at) <= d, na.rm = TRUE) else 0
        if (articles_by_date > 0) return(links_by_date / articles_by_date)
        return(0)
    })
    
    evolution <- list(
        dates = format(dates, "%Y-%m-%d"),
        knowledge_depth_evolution = depth_evolution,
        complexity_score = calculate_complexity_evolution(dates, articles, links),
        interconnectedness = calculate_interconnectedness_evolution(dates, articles, links)
    )
    
    return(evolution)
}

# Identify distinct learning phases
identify_learning_phases <- function(temporal_data) {
    phases <- list()
    
    articles <- temporal_data$articles
    if (is.null(articles)) return(list(error = "No articles data"))
    
    # Create time series of discovery activity
    article_dates <- if (is.data.frame(articles)) as.Date(articles$created_at) else as.Date(character(0))
    article_dates <- article_dates[!is.na(article_dates)]
    
    if (length(article_dates) < 10) {
        return(list(message = "Not enough data to identify learning phases"))
    }
    
    # Calculate activity levels over time windows
    date_range <- seq(from = min(article_dates), to = max(article_dates), by = "week")
    weekly_activity <- sapply(date_range, function(d) {
        sum(article_dates >= d & article_dates < (d + 7))
    })
    
    # Use changepoint detection or simple threshold-based approach
    activity_threshold <- median(weekly_activity)
    
    # Identify phases based on activity levels
    phase_changes <- which(diff(weekly_activity > activity_threshold) != 0)
    
    if (length(phase_changes) == 0) {
        phases <- list(
            phase_count = 1,
            phases = list(list(
                start_date = format(min(date_range), "%Y-%m-%d"),
                end_date = format(max(date_range), "%Y-%m-%d"),
                activity_level = if (mean(weekly_activity) > activity_threshold) "high" else "low",
                description = if (mean(weekly_activity) > activity_threshold) "Active Learning" else "Steady Exploration"
            ))
        )
    } else {
        # Create phases based on change points
        phase_starts <- c(1, phase_changes + 1)
        phase_ends <- c(phase_changes, length(date_range))
        
        phase_list <- list()
        for (i in 1:length(phase_starts)) {
            start_idx <- phase_starts[i]
            end_idx <- min(phase_ends[i], length(date_range))
            
            phase_activity <- mean(weekly_activity[start_idx:end_idx])
            activity_level <- if (phase_activity > activity_threshold) "high" else "low"
            
            phase_list[[i]] <- list(
                start_date = format(date_range[start_idx], "%Y-%m-%d"),
                end_date = format(date_range[end_idx], "%Y-%m-%d"),
                activity_level = activity_level,
                avg_articles_per_week = round(phase_activity, 1),
                description = if (activity_level == "high") {
                    "Intensive Learning"
                } else if (activity_level == "low") {
                    "Exploration Phase"
                } else {
                    "Steady Learning"
                }
            )
        }
        
        phases <- list(
            phase_count = length(phase_list),
            phases = phase_list
        )
    }
    
    return(phases)
}

# Helper function to calculate temporal metrics
calculate_temporal_metrics <- function(temporal_data) {
    metrics <- list()
    
    articles <- temporal_data$articles
    links <- temporal_data$links
    
    if (!is.null(articles)) {
        article_dates <- if (is.data.frame(articles)) as.Date(articles$created_at) else as.Date(character(0))
        article_dates <- article_dates[!is.na(article_dates)]
        
        if (length(article_dates) > 0) {
            metrics$total_days_active <- as.numeric(max(article_dates) - min(article_dates) + 1)
            metrics$avg_articles_per_day <- length(article_dates) / metrics$total_days_active
        } else {
            metrics$total_days_active <- 0
            metrics$avg_articles_per_day <- 0
        }
        metrics$peak_discovery_day <- if (length(article_dates) > 0) names(sort(table(article_dates), decreasing = TRUE))[1] else "N/A"
    }
    
    if (!is.null(links)) {
        link_dates <- if (is.data.frame(links)) as.Date(links$created_at) else as.Date(character(0))
        link_dates <- link_dates[!is.na(link_dates)]
        
        if (length(link_dates) > 0 && metrics$total_days_active > 0) {
            metrics$avg_links_per_day <- length(link_dates) / metrics$total_days_active
        } else {
            metrics$avg_links_per_day <- 0
        }
        metrics$peak_linking_day <- if (length(link_dates) > 0) names(sort(table(link_dates), decreasing = TRUE))[1] else "N/A"
    }
    
    return(metrics)
}

# Helper functions
calculate_velocity <- function(cumulative_data) {
    if (length(cumulative_data) < 2) return(rep(0, length(cumulative_data)))
    return(c(0, diff(cumulative_data)))
}

calculate_growth_rate <- function(articles, links) {
    if (length(articles) < 2) return(rep(0, length(articles)))
    
    article_rate <- c(0, diff(articles) / pmax(articles[-length(articles)], 1))
    link_rate <- c(0, diff(links) / pmax(links[-length(links)], 1))
    
    return((article_rate + link_rate) / 2)
}

analyze_category_evolution <- function(article_data) {
    article_data$year_month <- format(article_data$created_at, "%Y-%m")
    months <- unique(article_data$year_month)
    
    evolution <- data.frame(
        year_month = months,
        unique_categories = sapply(months, function(m) {
            month_data <- article_data[article_data$year_month == m, ]
            length(unique(month_data$category))
        }),
        dominant_category = sapply(months, function(m) {
            month_data <- article_data[article_data$year_month == m, ]
            cat_table <- table(month_data$category)
            names(sort(cat_table, decreasing = TRUE))[1]
        }),
        stringsAsFactors = FALSE
    )
    evolution <- evolution[order(evolution$year_month), ]
    
    return(evolution)
}

identify_exploration_phases <- function(article_data) {
    # Simple heuristic: periods of high category diversity = exploration
    article_data$year_month <- format(article_data$created_at, "%Y-%m")
    months <- unique(article_data$year_month)
    
    monthly_stats <- data.frame(
        year_month = months,
        article_count = sapply(months, function(m) {
            sum(article_data$year_month == m)
        }),
        category_diversity = sapply(months, function(m) {
            month_data <- article_data[article_data$year_month == m, ]
            length(unique(month_data$category))
        }),
        stringsAsFactors = FALSE
    )
    
    monthly_stats$diversity_ratio <- monthly_stats$category_diversity / monthly_stats$article_count
    monthly_stats <- monthly_stats[order(monthly_stats$year_month), ]
    
    # Identify exploration vs. focus phases
    if (length(monthly_stats$diversity_ratio) > 0 && !all(is.na(monthly_stats$diversity_ratio))) {
        high_diversity_threshold <- quantile(monthly_stats$diversity_ratio, 0.7, na.rm = TRUE)
    } else {
        high_diversity_threshold <- 0.5  # Default threshold
    }
    
    monthly_stats$phase_type <- ifelse(
        monthly_stats$diversity_ratio >= high_diversity_threshold,
        "exploration",
        "focus"
    )
    
    return(monthly_stats)
}

calculate_complexity_evolution <- function(dates, articles, links) {
    # Simplified complexity score based on link density and category diversity
    complexity_scores <- sapply(dates, function(d) {
        articles_by_date <- if (is.data.frame(articles)) sum(as.Date(articles$created_at) <= d, na.rm = TRUE) else 0
        links_by_date <- if (is.data.frame(links)) sum(as.Date(links$created_at) <= d, na.rm = TRUE) else 0
        
        if (articles_by_date < 2) return(0)
        
        # Link density component
        max_possible_links <- articles_by_date * (articles_by_date - 1)
        link_density <- links_by_date / max(max_possible_links, 1)
        
        # Category diversity component (simplified)
        category_diversity <- min(articles_by_date / 5, 1)  # Assume max 5 categories initially
        
        return(link_density * category_diversity)
    })
    
    return(complexity_scores)
}

calculate_interconnectedness_evolution <- function(dates, articles, links) {
    # How well connected the graph becomes over time
    interconnectedness <- sapply(dates, function(d) {
        articles_by_date <- if (is.data.frame(articles)) sum(as.Date(articles$created_at) <= d, na.rm = TRUE) else 0
        links_by_date <- if (is.data.frame(links)) sum(as.Date(links$created_at) <= d, na.rm = TRUE) else 0
        
        if (articles_by_date < 2) return(0)
        return(links_by_date / articles_by_date)
    })
    
    return(interconnectedness)
}

`%||%` <- function(lhs, rhs) {
    if (is.null(lhs) || length(lhs) == 0) {
        rhs
    } else if (length(lhs) == 1 && any(is.na(lhs))) {
        rhs
    } else {
        lhs
    }
}

# Case-when helper function for R < 4.0
case_when <- function(...) {
    dots <- list(...)
    for (i in seq_along(dots)) {
        if (i %% 2 == 1) {  # condition
            condition <- dots[[i]]
            if (i + 1 <= length(dots)) {
                value <- dots[[i + 1]]
                if (any(condition, na.rm = TRUE)) {
                    return(rep(value, length(condition)))
                }
            }
        }
    }
    return(rep(NA, length(dots[[1]])))
}

# Main execution
main <- function() {
    args <- commandArgs(trailingOnly = TRUE)
    
    if (length(args) == 0) {
        cat("Usage: Rscript temporal_analysis.R '<json_input>'\n")
        cat("Input should include articles and links with timestamps\n")
        quit(status = 1)
    }
    
    result <- analyze_temporal_patterns(args[1])
    cat(result)
}

if (sys.nframe() == 0) {
    main()
}
