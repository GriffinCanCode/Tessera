#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Mojolicious::Lite;
use JSON::XS;
use WikiCrawler;
use WikiCrawler::GeminiBot;
use Log::Log4perl;

# Initialize Log4perl early to prevent warnings
Log::Log4perl->easy_init($Log::Log4perl::INFO);

# Initialize WikiCrawler
my $wiki_crawler = WikiCrawler->new(
    config_file => "$FindBin::Bin/../config/crawler.yaml"
);

# Initialize JSON encoder
my $json = JSON::XS->new->utf8->pretty;

# Initialize Gemini Bot (optional - only if service is available)
my $gemini_bot;
eval {
    $gemini_bot = WikiCrawler::GeminiBot->new(
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
        name => 'WikiCrawler API',
        version => $WikiCrawler::VERSION,
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
    
    unless ($query) {
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
app->log->info("Starting WikiCrawler API server on http://$host:$port");
app->start('daemon', '-l', "http://$host:$port");

__END__

=head1 NAME

api_server.pl - WikiCrawler REST API Server

=head1 SYNOPSIS

    perl script/api_server.pl

=head1 DESCRIPTION

This script starts a Mojolicious-based REST API server for the WikiCrawler
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

WikiCrawler Project

=cut
