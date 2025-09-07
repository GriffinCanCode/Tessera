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
use Log::Log4perl;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST GET);
use File::Temp;
use MIME::Base64;

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
        my $insights = $wiki_crawler->knowledge_graph->get_knowledge_insights(
            min_relevance => $min_relevance + 0
        );
        
        $c->render(json => {
            success => 1,
            data => $insights,
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
        my $temporal_analysis = $wiki_crawler->knowledge_graph->analyze_temporal_patterns(
            min_relevance => $min_relevance + 0
        );
        
        $c->render(json => {
            success => 1,
            data => $temporal_analysis,
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
        
        # Calculate brain stats
        my $total_knowledge = 0;
        my $dominant_subject = '';
        my $max_completion = 0;
        my $total_time = 0;
        
        for my $subject (@$subjects) {
            $total_knowledge += $subject->{avg_completion};
            $total_time += $subject->{total_time};
            
            if ($subject->{avg_completion} > $max_completion) {
                $max_completion = $subject->{avg_completion};
                $dominant_subject = $subject->{name};
            }
        }
        
        # Calculate balance score (how evenly distributed knowledge is)
        my $avg_completion = @$subjects ? $total_knowledge / @$subjects : 0;
        my $variance = 0;
        for my $subject (@$subjects) {
            $variance += ($subject->{avg_completion} - $avg_completion) ** 2;
        }
        $variance = @$subjects ? $variance / @$subjects : 0;
        my $balance_score = @$subjects ? int(100 - sqrt($variance)) : 0;
        $balance_score = $balance_score > 0 ? $balance_score : 0;
        
        # Get recent progress for growth rate calculation
        my $growth_sql = qq{
            SELECT COUNT(*) as recent_sessions
            FROM learning_progress 
            WHERE session_date >= strftime('%s', 'now', '-7 days')
        };
        my ($recent_sessions) = $dbh->selectrow_array($growth_sql);
        
        $c->render(json => {
            success => 1,
            data => {
                subjects => $subjects,
                brain_stats => {
                    total_knowledge_points => int($total_knowledge),
                    dominant_area => $dominant_subject,
                    balance_score => $balance_score,
                    growth_rate => ($recent_sessions || 0) * 2.5, # Mock calculation
                    total_time_minutes => int($total_time),
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

# Initialize HTTP client for Python service communication
my $ua = LWP::UserAgent->new(
    timeout => 120,
    agent => 'Tessera-Perl-API/1.0'
);

# Helper function to call Python data ingestion service
sub call_python_ingestion_service {
    my ($endpoint, $form_data) = @_;
    
    my $python_service_url = 'http://127.0.0.1:8003';
    my $url = "$python_service_url$endpoint";
    
    app->log->info("Calling Python ingestion service: $url");
    
    my $response = $ua->post($url, $form_data);
    
    unless ($response->is_success) {
        die "Python service error: " . $response->status_line . " - " . $response->content;
    }
    
    my $result = eval { $json->decode($response->content) };
    if ($@) {
        die "Failed to parse Python service response: $@";
    }
    
    return $result;
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
        
        $c->render(json => {
            success => $result->{success} ? 1 : 0,
            data => $result,
        });
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
        
        $c->render(json => {
            success => $result->{success} ? 1 : 0,
            data => $result,
        });
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
        
        $c->render(json => {
            success => $result->{success} ? 1 : 0,
            data => $result,
        });
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
        
        $c->render(json => {
            success => $result->{success} ? 1 : 0,
            data => $result,
        });
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
