#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Mojolicious::Lite;
use JSON::XS;
use Tessera;
use Tessera::Logger;
use Tessera::GeminiBot;
use Tessera::Services qw(get_numerical_client calculate_similarity batch_similarity similarity_with_threshold);
use Tessera::VectorOps qw(cosine_similarity batch_cosine_similarity);
use Log::Log4perl;
use LWP::UserAgent;
use LWP::ConnCache;
use Mojo::UserAgent;
use HTTP::Request::Common qw(POST GET);
use File::Temp;
use MIME::Base64;
use Time::HiRes qw(time);

# Initialize enhanced logging
my $api_logger = Tessera::Logger->get_logger('API Server');

# Initialize Tessera
my $wiki_crawler = Tessera->new(
    config_file => "$FindBin::Bin/../../config/crawler.yaml"
);

# Log service startup
$api_logger->log_service_start(port => 3000);

# Initialize JSON encoder
my $json = JSON::XS->new->utf8->pretty;

# Initialize Gemini Bot (optional - only if service is available)
my $gemini_bot;
eval {
    $gemini_bot = Tessera::GeminiBot->new(
        storage => $wiki_crawler->storage,
        knowledge_graph => $wiki_crawler->knowledge_graph
    );
    
    # Test if service is available
    unless ($gemini_bot->service_health_check()) {
        app->log->warn("Gemini service not available - bot features disabled");
        undef $gemini_bot;
    } else {
        app->log->info("Gemini bot initialized successfully");
    }
};

# Initialize numerical client for high-performance vector operations
my $numerical_client = get_numerical_client();
if ($numerical_client->is_available()) {
    app->log->info("R numerical service available - high-performance mode enabled");
} else {
    app->log->warn("R numerical service unavailable - using Perl fallback");
}
if ($@) {
    app->log->warn("Failed to initialize Gemini bot: $@");
    undef $gemini_bot;
}

# Enable CORS
hook before_dispatch => sub {
    my $c = shift;
    $c->res->headers->header('Access-Control-Allow-Origin' => '*');
    $c->res->headers->header('Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS');
    $c->res->headers->header('Access-Control-Allow-Headers' => 'Content-Type, Authorization');
};

# Handle preflight requests
options '*' => sub {
    my $c = shift;
    $c->render(text => '', status => 204);
};

# Root endpoint - API info
get '/' => sub {
    my $c = shift;
    
    my $stats = $wiki_crawler->get_stats();
    
    $c->render(json => {
        name => 'Tessera API',
        version => $Tessera::VERSION,
        description => 'Personal Wikipedia Knowledge Graph Builder API',
        endpoints => {
            '/stats' => 'GET - Database and system statistics',
            '/search' => 'GET - Search articles (q=query, limit=N)',
            '/article/:title' => 'GET - Get article by title',
            '/crawl' => 'POST - Start crawling (JSON body with start_url, interests, etc.)',
            '/graph' => 'GET - Build knowledge graph (min_relevance, max_depth, format)',
            '/export' => 'GET - Export knowledge graph (format=json|graphml|dot)',
            '/hubs' => 'GET - Get knowledge hubs (most connected articles, limit=N)',
            '/discoveries' => 'GET - Get recent discoveries (new connections, limit=N)',
            '/insights' => 'GET - Get personal knowledge insights (min_relevance)',
            '/temporal' => 'GET - Get temporal analysis and growth patterns (min_relevance)',
            '/layouts' => 'GET - Get advanced graph layouts (min_relevance, max_depth, center_article_id)',
            '/bot/chat' => 'POST - Chat with knowledge bot (JSON body with conversation_id, message)',
            '/bot/knowledge-query' => 'POST - Ask knowledge-focused question (JSON body with query)',
            '/bot/conversations' => 'GET - List active bot conversations',
            '/bot/conversation/:id/history' => 'GET - Get conversation history',
            '/bot/conversation/:id' => 'DELETE - Delete conversation',
            '/projects' => 'GET - List all projects',
            '/projects' => 'POST - Create new project',
            '/project/:id' => 'GET - Get project by ID',
            '/project/:id' => 'PUT - Update project',
            '/project/:id' => 'DELETE - Delete project',
            '/project/:id/articles' => 'GET - Get project articles',
            '/project/:id/search' => 'GET - Search within project',
            '/learning/subjects' => 'GET - Get all learning subjects with progress',
            '/learning/content' => 'GET - Get learning content',
            '/learning/content' => 'POST - Add new learning content',
            '/learning/progress/:content_id' => 'POST - Record learning progress',
            '/learning/analytics' => 'GET - Get learning analytics and brain data',
            '/ingest/youtube' => 'POST - Ingest YouTube video transcript',
            '/ingest/article' => 'POST - Ingest web article content',
            '/ingest/book' => 'POST - Upload and ingest book/document',
            '/ingest/poetry' => 'POST - Ingest poetry or creative writing',
            '/ingest/status/:job_id' => 'GET - Check ingestion job status',
        },
        stats => $stats,
    });
};

# Get database statistics
get '/stats' => sub {
    my $c = shift;
    
    my $stats = $wiki_crawler->get_stats();
    
    $c->render(json => {
        success => 1,
        data => $stats,
    });
};

# Search articles
get '/search' => sub {
    my $c = shift;
    
    my $query = $c->param('q');
    my $project_id = $c->param('project_id'); # Optional project context
    my $limit_param = $c->param('limit') || '20';
    # Ensure limit is a valid positive integer
    my $limit = ($limit_param && $limit_param =~ /^\d+$/) ? int($limit_param) : 20;
    $limit = 20 if $limit <= 0;
    
    $api_logger->log_api_request('GET', '/search', query => $query, limit => $limit);
    
    unless ($query) {
        $api_logger->log_api_response('GET', '/search', 400);
        return $c->render(json => {
            success => 0,
            error => 'Query parameter "q" is required',
        }, status => 400);
    }
    
    eval {
        my $results;
        if ($project_id) {
            # Search within project context
            $results = $wiki_crawler->storage->search_articles($query, $limit, $project_id);
        } else {
            # Global search
            $results = $wiki_crawler->search($query, limit => $limit);
        }
        
        $c->render(json => {
            success => 1,
            data => {
                query => $query,
                project_id => $project_id,
                count => scalar(@$results),
                results => $results,
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Search failed: $@",
        }, status => 500);
    }
};

# Get article by title
get '/article/:title' => sub {
    my $c = shift;
    my $title = $c->param('title');
    
    my $article = $wiki_crawler->get_article($title);
    
    unless ($article) {
        return $c->render(json => {
            success => 0,
            error => "Article not found: $title",
        }, status => 404);
    }
    
    $c->render(json => {
        success => 1,
        data => $article,
    });
};

# Start crawling
post '/crawl' => sub {
    my $c = shift;
    
    my $params = $c->req->json;
    
    unless ($params && $params->{start_url}) {
        return $c->render(json => {
            success => 0,
            error => 'JSON body with start_url is required',
        }, status => 400);
    }
    
    # Extract parameters
    my $start_url = $params->{start_url};
    my $interests = $params->{interests} || [];
    my $max_depth = $params->{max_depth} || 3;
    my $max_articles = $params->{max_articles} || 50;
    my $project_id = $params->{project_id}; # Optional project context
    
    # Set interests
    $wiki_crawler->interests($interests);
    
    # Start crawling in background (simplified - in production you'd want proper job queuing)
    eval {
        my %crawl_params = (
            start_url => $start_url,
            max_depth => $max_depth,
            max_articles => $max_articles,
            interests => $interests,
        );
        
        $crawl_params{project_id} = $project_id if $project_id;
        
        my $stats = $wiki_crawler->crawl(%crawl_params);
        
        $c->render(json => {
            success => 1,
            message => 'Crawling completed successfully',
            data => $stats,
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Crawling failed: $@",
        }, status => 500);
    }
};

# Build knowledge graph
get '/graph' => sub {
    my $c = shift;
    
    my $min_relevance = $c->param('min_relevance') || 0.3;
    my $max_depth = $c->param('max_depth') || 3;
    my $center_article_id = $c->param('center_article_id');
    my $format = $c->param('format') || 'json';
    
    eval {
        my %options = (
            min_relevance => $min_relevance + 0,
            max_depth => $max_depth + 0,
        );
        
        $options{center_article_id} = $center_article_id + 0 if $center_article_id;
        
        my $graph = $wiki_crawler->build_knowledge_graph(%options);
        
        if ($format eq 'json') {
            $c->render(json => {
                success => 1,
                data => $graph,
            });
        } elsif ($format eq 'graphml') {
            my $graphml = $wiki_crawler->knowledge_graph->_export_graphml($graph);
            $c->render(text => $graphml, format => 'xml');
        } elsif ($format eq 'dot') {
            my $dot = $wiki_crawler->knowledge_graph->_export_dot($graph);
            $c->render(text => $dot, format => 'txt');
        } else {
            $c->render(json => {
                success => 0,
                error => "Unsupported format: $format",
            }, status => 400);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Graph generation failed: $@",
        }, status => 500);
    }
};

# Export knowledge graph to file
get '/export' => sub {
    my $c = shift;
    
    my $format = $c->param('format') || 'json';
    my $min_relevance = $c->param('min_relevance') || 0.3;
    my $filename = $c->param('filename') || "knowledge_graph.$format";
    
    unless ($format =~ /^(json|graphml|dot)$/) {
        return $c->render(json => {
            success => 0,
            error => "Unsupported format: $format. Use json, graphml, or dot.",
        }, status => 400);
    }
    
    eval {
        my $export_path = "$FindBin::Bin/../data/exports/$filename";
        
        # Ensure export directory exists
        require File::Path;
        File::Path::make_path("$FindBin::Bin/../data/exports");
        
        my $content = $wiki_crawler->export_graph(
            $format,
            $export_path,
            min_relevance => $min_relevance + 0
        );
        
        $c->render(json => {
            success => 1,
            message => "Graph exported successfully",
            data => {
                format => $format,
                filename => $filename,
                path => $export_path,
                size => -s $export_path,
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Export failed: $@",
        }, status => 500);
    }
};

# Delete old data
del '/cleanup' => sub {
    my $c = shift;
    
    my $keep_days = $c->param('keep_days') || 30;
    
    eval {
        my $deleted = $wiki_crawler->cleanup($keep_days);
        
        $c->render(json => {
            success => 1,
            message => "Cleanup completed",
            data => {
                deleted_articles => $deleted,
                keep_days => $keep_days + 0,
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Cleanup failed: $@",
        }, status => 500);
    }
};

# Get knowledge hubs (most connected articles)
get '/hubs' => sub {
    my $c = shift;
    
    my $limit = $c->param('limit') || 10;
    
    my $hubs = $wiki_crawler->get_knowledge_hubs($limit);
    
    $c->render(json => {
        success => 1,
        data => {
            hubs => $hubs,
            count => scalar(@$hubs),
        },
    });
};

# Get recent discoveries (new links)
get '/discoveries' => sub {
    my $c = shift;
    
    my $limit = $c->param('limit') || 10;
    
    my $discoveries = $wiki_crawler->get_recent_discoveries($limit);
    
    $c->render(json => {
        success => 1,
        data => {
            discoveries => $discoveries,
            count => scalar(@$discoveries),
        },
    });
};

# Get personal knowledge insights
get '/insights' => sub {
    my $c = shift;
    
    my $min_relevance = $c->param('min_relevance') || 0.3;
    
    eval {
        my $storage = $wiki_crawler->storage;
        my $dbh = $storage->dbh;
        
        # Check if learning schema exists
        my $tables = $dbh->selectcol_arrayref("SELECT name FROM sqlite_master WHERE type='table'");
        my %table_exists = map { $_ => 1 } @$tables;
        
        if (!$table_exists{subjects}) {
            # Return empty insights if no learning data
            $c->render(json => {
                success => 1,
                data => {
                    personal_metrics => {
                        knowledge_breadth => 0,
                        knowledge_depth => 0.0,
                        learning_velocity => 0.0,
                        knowledge_coherence => 0.000
                    },
                    current_state => {
                        total_nodes => 0,
                        total_edges => 0,
                        density => 0,
                        average_degree => 0
                    },
                    recommendations => []
                }
            });
            return;
        }
        
        # Get learning analytics data
        my $analytics_sql = qq{
            SELECT 
                s.id, s.name, s.description, s.color, s.icon,
                COUNT(DISTINCT lc.id) as total_content,
                COUNT(DISTINCT CASE WHEN lc.completion_percentage >= 100 THEN lc.id END) as completed_content,
                COALESCE(AVG(lc.completion_percentage), 0) as avg_completion,
                COALESCE(SUM(lc.actual_time_minutes), 0) as total_time,
                COALESCE(SUM(CASE WHEN lc.completion_percentage > 0 THEN 1 ELSE 0 END), 0) as started_content
            FROM subjects s
            LEFT JOIN content_subjects cs ON s.id = cs.subject_id
            LEFT JOIN learning_content lc ON cs.content_id = lc.id
            GROUP BY s.id, s.name, s.description, s.color, s.icon
            ORDER BY avg_completion DESC
        };
        
        my $subjects = $dbh->selectall_arrayref($analytics_sql, { Slice => {} });
        
        # Calculate personal metrics
        my $total_weighted_knowledge = 0;
        my $total_possible_weight = 0;
        my $total_subjects_with_content = 0;
        my @subject_depths = ();
        
        for my $subject (@$subjects) {
            next if $subject->{total_content} == 0;  # Skip subjects with no content
            
            # Get content for this subject to calculate weights
            my $content_sql = qq{
                SELECT lc.*, cs.subject_id
                FROM learning_content lc
                JOIN content_subjects cs ON lc.id = cs.content_id
                WHERE cs.subject_id = ?
            };
            my $content = $dbh->selectall_arrayref($content_sql, { Slice => {} }, $subject->{id});
            
            my $subject_weighted_knowledge = 0;
            my $subject_total_weight = 0;
            
            for my $item (@$content) {
                my $weight = calculate_content_weight($item);
                my $completion = ($item->{completion_percentage} || 0) / 100;
                
                $subject_weighted_knowledge += $weight * $completion;
                $subject_total_weight += $weight;
            }
            
            # Calculate Relative Knowledge Depth (RKD) for this subject
            my $rkd = $subject_total_weight > 0 ? $subject_weighted_knowledge / $subject_total_weight : 0;
            push @subject_depths, $rkd;
            
            $total_weighted_knowledge += $subject_weighted_knowledge;
            $total_possible_weight += $subject_total_weight;
            $total_subjects_with_content++;
        }
        
        # Calculate personal metrics
        my $knowledge_breadth = $total_subjects_with_content;  # Number of different topics explored
        my $knowledge_depth = @subject_depths ? (sum(@subject_depths) / @subject_depths) : 0;  # Average RKD across subjects
        my $learning_velocity = $knowledge_depth;  # Use RKD as velocity measure
        
        # Calculate knowledge coherence (how evenly distributed learning is)
        my $knowledge_coherence = 0;
        if (@subject_depths > 1) {
            my $mean_depth = sum(@subject_depths) / @subject_depths;
            my $variance = sum(map { ($_ - $mean_depth) ** 2 } @subject_depths) / @subject_depths;
            my $std_dev = sqrt($variance);
            $knowledge_coherence = $mean_depth > 0 ? (1 - ($std_dev / $mean_depth)) : 0;
            $knowledge_coherence = $knowledge_coherence > 0 ? $knowledge_coherence : 0;
        } elsif (@subject_depths == 1) {
            $knowledge_coherence = 1.0;  # Perfect coherence with one subject
        }
        
        # Get current graph state from knowledge graph
        my $current_state = {
            total_nodes => 0,
            total_edges => 0,
            density => 0,
            average_degree => 0
        };
        
        # Try to get actual graph stats if available
        eval {
            my $stats = $wiki_crawler->get_stats();
            $current_state = {
                total_nodes => $stats->{total_articles} || 0,
                total_edges => $stats->{total_links} || 0,
                density => $stats->{network_density} || 0,
                average_degree => $stats->{avg_links_per_article} || 0
            };
        };
        
        # Generate basic recommendations
        my @recommendations = ();
        if ($knowledge_breadth < 3) {
            push @recommendations, "Consider exploring more diverse topics to increase knowledge breadth";
        }
        if ($knowledge_depth < 0.5) {
            push @recommendations, "Focus on completing more content in your current subjects to increase depth";
        }
        if ($knowledge_coherence < 0.5 && $knowledge_breadth > 1) {
            push @recommendations, "Try to balance your learning across subjects for better coherence";
        }
        
        $c->render(json => {
            success => 1,
            data => {
                personal_metrics => {
                    knowledge_breadth => $knowledge_breadth,
                    knowledge_depth => $knowledge_depth,
                    learning_velocity => $learning_velocity,
                    knowledge_coherence => $knowledge_coherence
                },
                current_state => $current_state,
                recommendations => \@recommendations
            }
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to generate insights: $@",
        }, status => 500);
    }
};

# Get temporal analysis
get '/temporal' => sub {
    my $c = shift;
    
    my $min_relevance = $c->param('min_relevance') || 0.3;
    
    eval {
        my $storage = $wiki_crawler->storage;
        my $dbh = $storage->dbh;
        
        # Check if learning schema exists
        my $tables = $dbh->selectcol_arrayref("SELECT name FROM sqlite_master WHERE type='table'");
        my %table_exists = map { $_ => 1 } @$tables;
        
        if (!$table_exists{subjects}) {
            # Return empty temporal analysis if no learning data
            $c->render(json => {
                success => 1,
                data => {
                    growth_analysis => {
                        dates => [],
                        articles_cumulative => []
                    },
                    learning_phases => {
                        phases => []
                    }
                }
            });
            return;
        }
        
        # Get temporal learning data
        my $progress_sql = qq{
            SELECT 
                DATE(session_date, 'unixepoch') as date,
                COUNT(*) as sessions,
                SUM(time_spent_minutes) as total_time
            FROM learning_progress 
            WHERE session_date IS NOT NULL
            GROUP BY DATE(session_date, 'unixepoch')
            ORDER BY date
        };
        
        my $progress_data = $dbh->selectall_arrayref($progress_sql, { Slice => {} });
        
        # Build cumulative growth data
        my @dates = ();
        my @articles_cumulative = ();
        my $cumulative_sessions = 0;
        
        for my $day (@$progress_data) {
            push @dates, $day->{date};
            $cumulative_sessions += $day->{sessions};
            push @articles_cumulative, $cumulative_sessions;
        }
        
        # Identify learning phases based on activity patterns
        my @phases = ();
        if (@$progress_data > 0) {
            # Simple phase detection based on activity levels
            my $total_sessions = sum(map { $_->{sessions} } @$progress_data);
            my $avg_sessions_per_day = $total_sessions / @$progress_data;
            
            if ($avg_sessions_per_day > 2) {
                push @phases, "intensive_learning";
            } elsif ($avg_sessions_per_day > 1) {
                push @phases, "regular_learning";
            } else {
                push @phases, "casual_learning";
            }
            
            # Check for recent activity
            my $recent_sql = qq{
                SELECT COUNT(*) as recent_sessions
                FROM learning_progress 
                WHERE session_date >= strftime('%s', 'now', '-7 days')
            };
            my ($recent_sessions) = $dbh->selectrow_array($recent_sql);
            
            if ($recent_sessions > 5) {
                push @phases, "current_active";
            } elsif ($recent_sessions > 0) {
                push @phases, "current_moderate";
            } else {
                push @phases, "current_inactive";
            }
        }
        
        $c->render(json => {
            success => 1,
            data => {
                growth_analysis => {
                    dates => \@dates,
                    articles_cumulative => \@articles_cumulative
                },
                learning_phases => {
                    phases => \@phases
                }
            }
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to analyze temporal patterns: $@",
        }, status => 500);
    }
};

# Get advanced graph layouts
get '/layouts' => sub {
    my $c = shift;
    
    my $min_relevance = $c->param('min_relevance') || 0.3;
    my $max_depth = $c->param('max_depth') || 3;
    my $center_article_id = $c->param('center_article_id');
    
    eval {
        my %options = (
            min_relevance => $min_relevance + 0,
            max_depth => $max_depth + 0,
        );
        
        $options{center_article_id} = $center_article_id + 0 if $center_article_id;
        
        # Build graph first
        my $graph = $wiki_crawler->build_knowledge_graph(%options);
        
        # Calculate advanced layouts using R
        my $layouts = $wiki_crawler->knowledge_graph->calculate_advanced_layouts($graph);
        
        $c->render(json => {
            success => 1,
            data => {
                graph => $graph,
                layouts => $layouts,
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to calculate layouts: $@",
        }, status => 500);
    }
};

# Claude Bot Endpoints

# Chat with Claude bot
post '/bot/chat' => sub {
    my $c = shift;
    
    unless ($gemini_bot) {
        return $c->render(json => {
            success => 0,
            error => 'Gemini bot service is not available',
        }, status => 503);
    }
    
    my $params = $c->req->json;
    
    unless ($params && $params->{conversation_id} && $params->{message}) {
        return $c->render(json => {
            success => 0,
            error => 'JSON body with conversation_id and message is required',
        }, status => 400);
    }
    
    # Add project context to the request if provided
    if ($params->{project_id}) {
        $params->{context} = {
            project_id => $params->{project_id},
            %{$params->{context} || {}}
        };
    }
    
    eval {
        my $result = $gemini_bot->chat(
            $params->{conversation_id},
            $params->{message},
            max_tokens => $params->{max_tokens} || 1000,
            temperature => $params->{temperature} || 0.7,
            include_insights => $params->{include_insights} || 0,
        );
        
        if ($result->{success}) {
            $c->render(json => {
                success => 1,
                data => {
                    conversation_id => $result->{conversation_id},
                    message => $result->{message},
                    timestamp => $result->{timestamp},
                    context_used => $result->{context_used},
                },
            });
        } else {
            $c->render(json => {
                success => 0,
                error => $result->{error},
            }, status => 500);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Bot chat failed: $@",
        }, status => 500);
    }
};

# Knowledge query
post '/bot/knowledge-query' => sub {
    my $c = shift;
    
    unless ($gemini_bot) {
        return $c->render(json => {
            success => 0,
            error => 'Gemini bot service is not available',
        }, status => 503);
    }
    
    my $params = $c->req->json;
    
    unless ($params && $params->{query}) {
        return $c->render(json => {
            success => 0,
            error => 'JSON body with query is required',
        }, status => 400);
    }
    
    eval {
        my $result = $gemini_bot->knowledge_query(
            $params->{query},
            conversation_id => $params->{conversation_id},
            min_relevance => $params->{min_relevance} || 0.3,
            include_recent => $params->{include_recent} || 0,
        );
        
        if ($result->{success}) {
            $c->render(json => {
                success => 1,
                data => {
                    query => $result->{query},
                    answer => $result->{answer},
                    sources => $result->{sources},
                    confidence => $result->{confidence},
                    reasoning => $result->{reasoning},
                },
            });
        } else {
            $c->render(json => {
                success => 0,
                error => $result->{error},
            }, status => 500);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Knowledge query failed: $@",
        }, status => 500);
    }
};

# List conversations
get '/bot/conversations' => sub {
    my $c = shift;
    
    unless ($gemini_bot) {
        return $c->render(json => {
            success => 0,
            error => 'Gemini bot service is not available',
        }, status => 503);
    }
    
    eval {
        my $result = $gemini_bot->list_conversations();
        
        if ($result->{success}) {
            $c->render(json => {
                success => 1,
                data => {
                    conversations => $result->{conversations},
                    total => $result->{total},
                },
            });
        } else {
            $c->render(json => {
                success => 0,
                error => $result->{error},
            }, status => 500);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to list conversations: $@",
        }, status => 500);
    }
};

# Get conversation history
get '/bot/conversation/:id/history' => sub {
    my $c = shift;
    my $conversation_id = $c->param('id');
    
    unless ($gemini_bot) {
        return $c->render(json => {
            success => 0,
            error => 'Gemini bot service is not available',
        }, status => 503);
    }
    
    eval {
        my $result = $gemini_bot->get_conversation_history($conversation_id);
        
        if ($result->{success}) {
            $c->render(json => {
                success => 1,
                data => {
                    conversation_id => $result->{conversation_id},
                    messages => $result->{messages},
                    metadata => $result->{metadata},
                },
            });
        } else {
            $c->render(json => {
                success => 0,
                error => $result->{error},
            }, status => 500);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to get conversation history: $@",
        }, status => 500);
    }
};

# Delete conversation
del '/bot/conversation/:id' => sub {
    my $c = shift;
    my $conversation_id = $c->param('id');
    
    unless ($gemini_bot) {
        return $c->render(json => {
            success => 0,
            error => 'Gemini bot service is not available',
        }, status => 503);
    }
    
    eval {
        my $result = $gemini_bot->delete_conversation($conversation_id);
        
        if ($result->{success}) {
            $c->render(json => {
                success => 1,
                message => $result->{message},
            });
        } else {
            $c->render(json => {
                success => 0,
                error => $result->{error},
            }, status => 500);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to delete conversation: $@",
        }, status => 500);
    }
};

# Generate new conversation ID
get '/bot/new-conversation' => sub {
    my $c = shift;
    
    unless ($gemini_bot) {
        return $c->render(json => {
            success => 0,
            error => 'Gemini bot service is not available',
        }, status => 503);
    }
    
    my $conversation_id = $gemini_bot->generate_conversation_id();
    
    $c->render(json => {
        success => 1,
        data => {
            conversation_id => $conversation_id,
        },
    });
};

# Project Management Endpoints

# List all projects
get '/projects' => sub {
    my $c = shift;
    
    eval {
        my $projects = $wiki_crawler->storage->project_manager->list_projects();
        
        $c->render(json => {
            success => 1,
            data => {
                projects => $projects,
                count => scalar(@$projects),
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to list projects: $@",
        }, status => 500);
    }
};

# Create new project
post '/projects' => sub {
    my $c = shift;
    
    my $params = $c->req->json;
    
    unless ($params && $params->{name}) {
        return $c->render(json => {
            success => 0,
            error => 'JSON body with name is required',
        }, status => 400);
    }
    
    eval {
        my $result = $wiki_crawler->storage->project_manager->create_project($params);
        
        if ($result->{success}) {
            $c->render(json => $result);
        } else {
            $c->render(json => $result, status => 400);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to create project: $@",
        }, status => 500);
    }
};

# Get project by ID
get '/project/:id' => sub {
    my $c = shift;
    my $project_id = $c->param('id');
    
    eval {
        my $project = $wiki_crawler->storage->project_manager->get_project($project_id);
        
        if ($project) {
            $c->render(json => {
                success => 1,
                data => $project,
            });
        } else {
            $c->render(json => {
                success => 0,
                error => 'Project not found',
            }, status => 404);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to get project: $@",
        }, status => 500);
    }
};

# Update project
put '/project/:id' => sub {
    my $c = shift;
    my $project_id = $c->param('id');
    my $params = $c->req->json;
    
    unless ($params) {
        return $c->render(json => {
            success => 0,
            error => 'JSON body is required',
        }, status => 400);
    }
    
    eval {
        my $result = $wiki_crawler->storage->project_manager->update_project($project_id, $params);
        
        if ($result->{success}) {
            $c->render(json => $result);
        } else {
            $c->render(json => $result, status => 400);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to update project: $@",
        }, status => 500);
    }
};

# Delete project
del '/project/:id' => sub {
    my $c = shift;
    my $project_id = $c->param('id');
    
    eval {
        my $result = $wiki_crawler->storage->project_manager->delete_project($project_id);
        
        if ($result->{success}) {
            $c->render(json => $result);
        } else {
            $c->render(json => $result, status => 400);
        }
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to delete project: $@",
        }, status => 500);
    }
};

# Get project articles
get '/project/:id/articles' => sub {
    my $c = shift;
    my $project_id = $c->param('id');
    my $limit = $c->param('limit') || 50;
    my $offset = $c->param('offset') || 0;
    
    eval {
        my $articles = $wiki_crawler->storage->project_manager->get_project_articles(
            $project_id, $limit, $offset
        );
        
        $c->render(json => {
            success => 1,
            data => {
                articles => $articles,
                count => scalar(@$articles),
                project_id => $project_id,
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to get project articles: $@",
        }, status => 500);
    }
};

# Search within project
get '/project/:id/search' => sub {
    my $c = shift;
    my $project_id = $c->param('id');
    my $query = $c->param('q');
    my $limit = $c->param('limit') || 20;
    
    unless ($query) {
        return $c->render(json => {
            success => 0,
            error => 'Query parameter "q" is required',
        }, status => 400);
    }
    
    eval {
        my $results = $wiki_crawler->storage->project_manager->search_project_articles(
            $project_id, $query, $limit
        );
        
        $c->render(json => {
            success => 1,
            data => {
                query => $query,
                project_id => $project_id,
                count => scalar(@$results),
                results => $results,
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to search project: $@",
        }, status => 500);
    }
};

# Health check endpoint
get '/health' => sub {
    my $c = shift;
    
    $c->render(json => {
        status => 'ok',
        timestamp => time(),
        uptime => time() - $^T,
    });
};

# Learning API endpoints

# Get all subjects with progress
get '/learning/subjects' => sub {
    my $c = shift;
    
    eval {
        my $storage = $wiki_crawler->storage;
        my $dbh = $storage->dbh;
        
        # Check if learning schema exists
        my $tables = $dbh->selectcol_arrayref("SELECT name FROM sqlite_master WHERE type='table'");
        my %table_exists = map { $_ => 1 } @$tables;
        
        if (!$table_exists{subjects}) {
            $c->render(json => {
                success => 0,
                error => 'Learning schema not found. Please run setup_learning_database.pl',
            }, status => 404);
            return;
        }
        
        # Get subjects with progress data
        my $subjects_sql = qq{
            SELECT 
                s.id, s.name, s.description, s.color, s.icon,
                COUNT(DISTINCT lc.id) as total_content,
                COUNT(DISTINCT CASE WHEN lc.completion_percentage >= 100 THEN lc.id END) as completed_content,
                COALESCE(AVG(lc.completion_percentage), 0) as avg_completion,
                COALESCE(SUM(lc.actual_time_minutes), 0) as total_time
            FROM subjects s
            LEFT JOIN content_subjects cs ON s.id = cs.subject_id
            LEFT JOIN learning_content lc ON cs.content_id = lc.id
            GROUP BY s.id, s.name, s.description, s.color, s.icon
            ORDER BY s.name
        };
        
        my $subjects = $dbh->selectall_arrayref($subjects_sql, { Slice => {} });
        
        $c->render(json => {
            success => 1,
            data => {
                subjects => $subjects,
                count => scalar(@$subjects),
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to get subjects: $@",
        }, status => 500);
    }
};

# Simple sum function for arrays
sub sum {
    my $total = 0;
    $total += $_ for @_;
    return $total;
}

# Calculate content weight based on length, difficulty, and type
sub calculate_content_weight {
    my ($content_item) = @_;
    
    my $base_weight = 1.0;
    
    # Length factor (log scale to prevent huge articles from dominating)
    my $content_text = $content_item->{content} || $content_item->{summary} || '';
    my $content_length = length($content_text);
    $content_length = 100 if $content_length == 0;  # Default for empty content
    
    my $length_factor = log($content_length + 1) / log(1000);  # Normalized to ~1000 char baseline
    
    # Difficulty factor
    my $difficulty_factor = ($content_item->{difficulty_level} || 3) / 3.0;
    
    # Content type factor
    my %type_factors = (
        'book' => 2.0,
        'course' => 1.8,
        'article' => 1.0,
        'video' => 0.8,
        'youtube' => 0.6,
        'text' => 0.4,
        'poetry' => 0.3,
    );
    my $type_factor = $type_factors{$content_item->{content_type} || 'article'} || 1.0;
    
    return $base_weight * $length_factor * $difficulty_factor * $type_factor;
}

# Get learning analytics for brain visualization
get '/learning/analytics' => sub {
    my $c = shift;
    
    eval {
        my $storage = $wiki_crawler->storage;
        my $dbh = $storage->dbh;
        
        # Check if learning schema exists
        my $tables = $dbh->selectcol_arrayref("SELECT name FROM sqlite_master WHERE type='table'");
        my %table_exists = map { $_ => 1 } @$tables;
        
        if (!$table_exists{subjects}) {
            $c->render(json => {
                success => 0,
                error => 'Learning schema not found. Please run setup_learning_database.pl',
            }, status => 404);
            return;
        }
        
        # Get comprehensive learning analytics
        my $analytics_sql = qq{
            SELECT 
                s.id, s.name, s.description, s.color, s.icon,
                COUNT(DISTINCT lc.id) as total_content,
                COUNT(DISTINCT CASE WHEN lc.completion_percentage >= 100 THEN lc.id END) as completed_content,
                COALESCE(AVG(lc.completion_percentage), 0) as avg_completion,
                COALESCE(SUM(lc.actual_time_minutes), 0) as total_time,
                COALESCE(SUM(CASE WHEN lc.completion_percentage > 0 THEN 1 ELSE 0 END), 0) as started_content
            FROM subjects s
            LEFT JOIN content_subjects cs ON s.id = cs.subject_id
            LEFT JOIN learning_content lc ON cs.content_id = lc.id
            GROUP BY s.id, s.name, s.description, s.color, s.icon
            ORDER BY avg_completion DESC
        };
        
        my $subjects = $dbh->selectall_arrayref($analytics_sql, { Slice => {} });
        
        # Calculate weighted brain stats using content weights
        my $total_weighted_knowledge = 0;
        my $total_possible_weight = 0;
        my $dominant_subject = '';
        my $max_weighted_completion = 0;
        my $total_time = 0;
        
        for my $subject (@$subjects) {
            # Get content for this subject to calculate weights
            my $content_sql = qq{
                SELECT lc.*, cs.subject_id
                FROM learning_content lc
                JOIN content_subjects cs ON lc.id = cs.content_id
                WHERE cs.subject_id = ?
            };
            my $content = $dbh->selectall_arrayref($content_sql, { Slice => {} }, $subject->{id});
            
            my $subject_weighted_knowledge = 0;
            my $subject_total_weight = 0;
            
            for my $item (@$content) {
                my $weight = calculate_content_weight($item);
                my $completion = ($item->{completion_percentage} || 0) / 100;
                
                $subject_weighted_knowledge += $weight * $completion;
                $subject_total_weight += $weight;
            }
            
            # Calculate Relative Knowledge Depth (RKD) for this subject
            my $rkd = $subject_total_weight > 0 ? $subject_weighted_knowledge / $subject_total_weight : 0;
            $subject->{weighted_completion} = $rkd * 100;  # Convert back to percentage for display
            
            $total_weighted_knowledge += $subject_weighted_knowledge;
            $total_possible_weight += $subject_total_weight;
            $total_time += $subject->{total_time};
            
            if ($rkd > $max_weighted_completion) {
                $max_weighted_completion = $rkd;
                $dominant_subject = $subject->{name};
            }
        }
        
        # Calculate balance score based on weighted completions
        my @weighted_completions = map { $_->{weighted_completion} || 0 } @$subjects;
        my $avg_weighted = @weighted_completions ? (sum(@weighted_completions) / @weighted_completions) : 0;
        my $variance = 0;
        for my $completion (@weighted_completions) {
            $variance += ($completion - $avg_weighted) ** 2;
        }
        $variance = @weighted_completions ? $variance / @weighted_completions : 0;
        my $balance_score = @weighted_completions ? int(100 - sqrt($variance)) : 0;
        $balance_score = $balance_score > 0 ? $balance_score : 0;
        
        # Get recent progress for growth rate calculation
        my $growth_sql = qq{
            SELECT COUNT(*) as recent_sessions
            FROM learning_progress 
            WHERE session_date >= strftime('%s', 'now', '-7 days')
        };
        my ($recent_sessions) = $dbh->selectrow_array($growth_sql);
        
        # Calculate overall knowledge velocity (RKD across all subjects)
        my $overall_rkd = $total_possible_weight > 0 ? $total_weighted_knowledge / $total_possible_weight : 0;
        
        $c->render(json => {
            success => 1,
            data => {
                subjects => $subjects,
                brain_stats => {
                    total_knowledge_points => int($overall_rkd * 1000),  # Scale for display
                    dominant_area => $dominant_subject,
                    balance_score => $balance_score,
                    growth_rate => ($recent_sessions || 0) * 2.5, # Mock calculation
                    total_time_minutes => int($total_time),
                    knowledge_velocity => $overall_rkd,
                },
                count => scalar(@$subjects),
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to get learning analytics: $@",
        }, status => 500);
    }
};

# Get learning content
get '/learning/content' => sub {
    my $c = shift;
    
    my $subject_id = $c->param('subject_id');
    my $limit = $c->param('limit') || 50;
    
    eval {
        my $storage = $wiki_crawler->storage;
        my $dbh = $storage->dbh;
        
        my $content_sql;
        my @params = ($limit);
        
        if ($subject_id) {
            $content_sql = qq{
                SELECT lc.*, GROUP_CONCAT(s.name) as subjects
                FROM learning_content lc
                LEFT JOIN content_subjects cs ON lc.id = cs.content_id
                LEFT JOIN subjects s ON cs.subject_id = s.id
                WHERE cs.subject_id = ?
                GROUP BY lc.id
                ORDER BY lc.updated_at DESC
                LIMIT ?
            };
            unshift @params, $subject_id;
        } else {
            $content_sql = qq{
                SELECT lc.*, GROUP_CONCAT(s.name) as subjects
                FROM learning_content lc
                LEFT JOIN content_subjects cs ON lc.id = cs.content_id
                LEFT JOIN subjects s ON cs.subject_id = s.id
                GROUP BY lc.id
                ORDER BY lc.updated_at DESC
                LIMIT ?
            };
        }
        
        my $content = $dbh->selectall_arrayref($content_sql, { Slice => {} }, @params);
        
        $c->render(json => {
            success => 1,
            data => {
                content => $content,
                count => scalar(@$content),
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to get learning content: $@",
        }, status => 500);
    }
};

# Add new learning content
post '/learning/content' => sub {
    my $c = shift;
    
    my $json = $c->req->json;
    
    unless ($json && $json->{title} && $json->{content_type}) {
        $c->render(json => {
            success => 0,
            error => 'Missing required fields: title, content_type',
        }, status => 400);
        return;
    }
    
    eval {
        # This would use the LearningManager module
        # For now, return a placeholder response
        $c->render(json => {
            success => 1,
            data => {
                content_id => int(rand(1000)) + 1,
                message => 'Content added successfully (placeholder - implement with LearningManager)',
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Failed to add learning content: $@",
        }, status => 500);
    }
};

# Initialize optimized HTTP client with connection pooling for Python service communication
my $ua = LWP::UserAgent->new(
    timeout => 120,
    agent => 'Tessera-Perl-API/1.0',
    keep_alive => 10,  # Keep connections alive for 10 requests
    max_redirect => 3,
    protocols_allowed => ['http', 'https'],
);

# Configure connection pooling
$ua->conn_cache(LWP::ConnCache->new());
$ua->conn_cache->total_capacity(20);  # Pool of 20 connections

# Initialize async Mojo UserAgent for non-blocking calls
my $mojo_ua = Mojo::UserAgent->new(
    connect_timeout => 30,
    request_timeout => 120,
    max_connections => 20,
    max_redirects   => 3,
);
$mojo_ua->transactor->name('Tessera-Perl-API-Async/1.0');

# Optimized helper function to call Python services with retry logic and circuit breaker
sub call_python_service {
    my ($service_name, $endpoint, $form_data, $method) = @_;
    $method ||= 'POST';
    
    # Service URLs with load balancing potential
    my %service_urls = (
        'ingestion' => 'http://127.0.0.1:8003',
        'gemini'    => 'http://127.0.0.1:8001', 
        'embedding' => 'http://127.0.0.1:8002',
    );
    
    my $base_url = $service_urls{$service_name} || $service_urls{'ingestion'};
    my $url = "$base_url$endpoint";
    
    app->log->info("Calling Python $service_name service: $url");
    
    # Retry logic with exponential backoff
    my $max_retries = 3;
    my $retry_delay = 1; # seconds
    
    my $result;
    for my $attempt (1..$max_retries) {
        eval {
            my $response;
            
            if ($method eq 'POST') {
                $response = $ua->post($url, $form_data);
            } elsif ($method eq 'GET') {
                $response = $ua->get($url);
            } else {
                die "Unsupported HTTP method: $method";
            }
            
            if ($response->is_success) {
                my $content = $response->content;
                $result = eval { $json->decode($content) };
                if ($@) {
                    die "Failed to parse Python service response: $@ (content: $content)";
                }
                # Success - break out of retry loop
                return;
            } else {
                # Check if it's a temporary error worth retrying
                my $status = $response->code;
                if ($status >= 500 || $status == 429) { # Server error or rate limit
                    die "Temporary error (attempt $attempt/$max_retries): " . $response->status_line;
                } else {
                    # Client error - don't retry
                    die "Python service error: " . $response->status_line . " - " . $response->content;
                }
            }
        };
        
        if ($@) {
            if ($attempt == $max_retries) {
                # Last attempt failed
                die $@;
            } else {
                app->log->warn("Python service call failed (attempt $attempt): $@");
                sleep($retry_delay);
                $retry_delay *= 2; # Exponential backoff
            }
        } else {
            # Success - exit retry loop
            last;
        }
    }
    
    return $result;
}

# Async version for non-blocking Python service calls
sub call_python_service_async {
    my ($service_name, $endpoint, $form_data, $method, $callback) = @_;
    $method ||= 'POST';
    
    # Service URLs
    my %service_urls = (
        'ingestion' => 'http://127.0.0.1:8003',
        'gemini'    => 'http://127.0.0.1:8001', 
        'embedding' => 'http://127.0.0.1:8002',
    );
    
    my $base_url = $service_urls{$service_name} || $service_urls{'ingestion'};
    my $url = "$base_url$endpoint";
    
    app->log->info("Async calling Python $service_name service: $url");
    
    # Make async request
    if ($method eq 'POST') {
        $mojo_ua->post($url => form => $form_data => sub {
            my ($ua, $tx) = @_;
            _handle_async_response($tx, $callback, $service_name);
        });
    } elsif ($method eq 'GET') {
        $mojo_ua->get($url => sub {
            my ($ua, $tx) = @_;
            _handle_async_response($tx, $callback, $service_name);
        });
    }
}

# Handle async response
sub _handle_async_response {
    my ($tx, $callback, $service_name) = @_;
    
    if (my $res = $tx->success) {
        eval {
            my $result = $json->decode($res->body);
            $callback->(undef, $result);
        };
        if ($@) {
            $callback->("Failed to parse $service_name response: $@", undef);
        }
    } else {
        my $err = $tx->error;
        my $error_msg = $err->{code} ? "$err->{code} response: $err->{message}" : "Connection error: $err->{message}";
        $callback->("$service_name service error: $error_msg", undef);
    }
}

# Backward compatibility wrapper
sub call_python_ingestion_service {
    my ($endpoint, $form_data) = @_;
    return call_python_service('ingestion', $endpoint, $form_data, 'POST');
}

# Ingest YouTube video transcript
post '/ingest/youtube' => sub {
    my $c = shift;
    
    my $url = $c->param('url');
    my $title = $c->param('title');
    my $description = $c->param('description');
    my $project_id = $c->param('project_id');
    
    unless ($url) {
        $c->render(json => {
            success => 0,
            error => 'Missing required parameter: url',
        }, status => 400);
        return;
    }
    
    eval {
        my $form_data = [
            url => $url,
            ($title ? (title => $title) : ()),
            ($description ? (description => $description) : ()),
            ($project_id ? (project_id => $project_id) : ()),
        ];
        
        my $result = call_python_ingestion_service('/ingest/youtube', $form_data);
        
        # Check if result is a valid hash reference
        if (ref($result) eq 'HASH') {
            $c->render(json => {
                success => $result->{success} ? 1 : 0,
                data => $result,
            });
        } else {
            die "Invalid response from Python service: " . (defined $result ? $result : 'undefined');
        }
    };
    
    if ($@) {
        app->log->error("YouTube ingestion failed: $@");
        $c->render(json => {
            success => 0,
            error => "Failed to ingest YouTube video: $@",
        }, status => 500);
    }
};

# Ingest web article
post '/ingest/article' => sub {
    my $c = shift;
    
    my $url = $c->param('url');
    my $title = $c->param('title');
    my $description = $c->param('description');
    my $project_id = $c->param('project_id');
    
    unless ($url) {
        $c->render(json => {
            success => 0,
            error => 'Missing required parameter: url',
        }, status => 400);
        return;
    }
    
    eval {
        my $form_data = [
            url => $url,
            ($title ? (title => $title) : ()),
            ($description ? (description => $description) : ()),
            ($project_id ? (project_id => $project_id) : ()),
        ];
        
        my $result = call_python_ingestion_service('/ingest/article', $form_data);
        
        # Check if result is a valid hash reference
        if (ref($result) eq 'HASH') {
            $c->render(json => {
                success => $result->{success} ? 1 : 0,
                data => $result,
            });
        } else {
            die "Invalid response from Python service: " . (defined $result ? (ref($result) ? ref($result) . " reference" : "scalar: $result") : 'undefined');
        }
    };
    
    if ($@) {
        app->log->error("Article ingestion failed: $@");
        $c->render(json => {
            success => 0,
            error => "Failed to ingest article: $@",
        }, status => 500);
    }
};

# Ingest book/document file
post '/ingest/book' => sub {
    my $c = shift;
    
    my $upload = $c->req->upload('file');
    my $title = $c->param('title');
    my $description = $c->param('description');
    my $project_id = $c->param('project_id');
    
    unless ($upload) {
        $c->render(json => {
            success => 0,
            error => 'Missing required file upload',
        }, status => 400);
        return;
    }
    
    eval {
        # Create temporary file for upload
        my $temp_file = File::Temp->new(SUFFIX => '.' . ($upload->filename =~ /\.([^.]+)$/)[0]);
        $upload->move_to($temp_file->filename);
        
        # Prepare multipart form data
        my $form_data = [
            file => [$temp_file->filename, $upload->filename, 'Content-Type' => $upload->headers->content_type],
            ($title ? (title => $title) : ()),
            ($description ? (description => $description) : ()),
            ($project_id ? (project_id => $project_id) : ()),
        ];
        
        my $result = call_python_ingestion_service('/ingest/book', $form_data);
        
        # Check if result is a valid hash reference
        if (ref($result) eq 'HASH') {
            $c->render(json => {
                success => $result->{success} ? 1 : 0,
                data => $result,
            });
        } else {
            die "Invalid response from Python service: " . (defined $result ? $result : 'undefined');
        }
    };
    
    if ($@) {
        app->log->error("Book ingestion failed: $@");
        $c->render(json => {
            success => 0,
            error => "Failed to ingest book: $@",
        }, status => 500);
    }
};

# Ingest poetry or creative writing
post '/ingest/poetry' => sub {
    my $c = shift;
    
    my $text = $c->param('text');
    my $title = $c->param('title');
    my $description = $c->param('description');
    my $project_id = $c->param('project_id');
    
    unless ($text) {
        $c->render(json => {
            success => 0,
            error => 'Missing required parameter: text',
        }, status => 400);
        return;
    }
    
    eval {
        my $form_data = [
            text => $text,
            ($title ? (title => $title) : ()),
            ($description ? (description => $description) : ()),
            ($project_id ? (project_id => $project_id) : ()),
        ];
        
        my $result = call_python_ingestion_service('/ingest/poetry', $form_data);
        
        # Check if result is a valid hash reference
        if (ref($result) eq 'HASH') {
            $c->render(json => {
                success => $result->{success} ? 1 : 0,
                data => $result,
            });
        } else {
            die "Invalid response from Python service: " . (defined $result ? $result : 'undefined');
        }
    };
    
    if ($@) {
        app->log->error("Poetry ingestion failed: $@");
        $c->render(json => {
            success => 0,
            error => "Failed to ingest poetry: $@",
        }, status => 500);
    }
};

# Check ingestion status (placeholder for future job tracking)
get '/ingest/status/:job_id' => sub {
    my $c = shift;
    my $job_id = $c->param('job_id');
    
    # For now, return a simple status
    $c->render(json => {
        success => 1,
        data => {
            job_id => $job_id,
            status => 'completed',
            message => 'Job status tracking not yet implemented',
        },
    });
};

# Vector Operations Endpoints (High-Performance R Integration)

# Calculate cosine similarity between two vectors
post '/vector/similarity' => sub {
    my $c = shift;
    my $params = $c->req->json;
    
    unless ($params && $params->{vec1} && $params->{vec2}) {
        return $c->render(json => {
            success => 0,
            error => 'Missing required parameters: vec1, vec2',
        }, status => 400);
    }
    
    eval {
        my $similarity = calculate_similarity($params->{vec1}, $params->{vec2});
        
        $c->render(json => {
            success => 1,
            data => {
                similarity => $similarity,
                method => $numerical_client->is_available() ? 'r-service' : 'perl-fallback',
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Similarity calculation failed: $@",
        }, status => 500);
    }
};

# Batch similarity calculation
post '/vector/batch_similarity' => sub {
    my $c = shift;
    my $params = $c->req->json;
    
    unless ($params && $params->{query} && $params->{embeddings}) {
        return $c->render(json => {
            success => 0,
            error => 'Missing required parameters: query, embeddings',
        }, status => 400);
    }
    
    eval {
        my $start_time = time();
        my $similarities = batch_similarity($params->{query}, $params->{embeddings});
        my $processing_time = (time() - $start_time) * 1000;
        
        $c->render(json => {
            success => 1,
            data => {
                similarities => $similarities,
                count => scalar(@$similarities),
                processing_time_ms => sprintf("%.2f", $processing_time),
                throughput => sprintf("%.0f", scalar(@$similarities) / ($processing_time / 1000)),
                method => $numerical_client->is_available() ? 'r-service' : 'perl-fallback',
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Batch similarity calculation failed: $@",
        }, status => 500);
    }
};

# Similarity with threshold filtering
post '/vector/similarity_threshold' => sub {
    my $c = shift;
    my $params = $c->req->json;
    
    unless ($params && $params->{query} && $params->{embeddings} && defined($params->{threshold})) {
        return $c->render(json => {
            success => 0,
            error => 'Missing required parameters: query, embeddings, threshold',
        }, status => 400);
    }
    
    eval {
        my $results = similarity_with_threshold(
            $params->{query}, 
            $params->{embeddings}, 
            $params->{threshold}
        );
        
        $c->render(json => {
            success => 1,
            data => {
                results => $results,
                matches_found => scalar(@$results),
                total_embeddings => scalar(@{$params->{embeddings}}),
                threshold => $params->{threshold},
                method => $numerical_client->is_available() ? 'r-service' : 'perl-fallback',
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Threshold similarity calculation failed: $@",
        }, status => 500);
    }
};

# Service status and capabilities
get '/vector/status' => sub {
    my $c = shift;
    
    eval {
        my $status = Tessera::Services::get_service_status();
        
        $c->render(json => {
            success => 1,
            data => {
                services => $status,
                performance => {
                    r_service_available => $numerical_client->is_available(),
                    estimated_throughput => $numerical_client->is_available() ? 
                        "100,000+ ops/sec" : "25,000 ops/sec",
                },
            },
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Status check failed: $@",
        }, status => 500);
    }
};

# Performance benchmark endpoint
post '/vector/benchmark' => sub {
    my $c = shift;
    my $params = $c->req->json || {};
    
    my $vector_dim = $params->{vector_dim} || 384;
    my $num_embeddings = $params->{num_embeddings} || 1000;
    
    eval {
        my $benchmark_result = $numerical_client->benchmark($vector_dim, $num_embeddings);
        
        $c->render(json => {
            success => 1,
            data => $benchmark_result,
        });
    };
    
    if ($@) {
        $c->render(json => {
            success => 0,
            error => "Benchmark failed: $@",
        }, status => 500);
    }
};

# 404 handler
any '*' => sub {
    my $c = shift;
    
    $c->render(json => {
        success => 0,
        error => 'Endpoint not found',
        path => $c->req->url->path,
    }, status => 404);
};

# Get configuration
my $config = $wiki_crawler->config;
my $host = $config->{api}{host} || 'localhost';
my $port = $config->{api}{port} || 3000;

# Start the server
app->log->info("Starting Tessera API server on http://$host:$port");
app->start('daemon', '-l', "http://$host:$port");

__END__

=head1 NAME

api_server.pl - Tessera REST API Server

=head1 SYNOPSIS

    perl script/api_server.pl

=head1 DESCRIPTION

This script starts a Mojolicious-based REST API server for the Tessera
system. It provides endpoints for crawling, searching, and knowledge graph
operations.

=head1 ENDPOINTS

=over 4

=item GET / - API information and statistics

=item GET /stats - Database statistics  

=item GET /search?q=query&limit=N - Search articles

=item GET /article/:title - Get article by title

=item POST /crawl - Start crawling (JSON body)

=item GET /graph - Build knowledge graph

=item GET /export - Export knowledge graph

=item DELETE /cleanup - Clean up old data

=item GET /health - Health check

=back

=head1 AUTHOR

Tessera Project

=cut
