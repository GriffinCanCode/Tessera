package WikiCrawler::GeminiBot;

use strict;
use warnings;
use v5.20;

use LWP::UserAgent;
use JSON::XS;
use Log::Log4perl;
use Time::HiRes qw(time);
use HTTP::Request::Common qw(GET POST DELETE);
use Data::Dumper;

use Moo;
use namespace::clean;

# Attributes
has 'gemini_service_url' => (
    is      => 'ro',
    default => 'http://127.0.0.1:8001',
);

has 'embedding_service_url' => (
    is      => 'ro', 
    default => 'http://127.0.0.1:8002',
);

has 'logger' => (
    is      => 'lazy',
    builder => '_build_logger',
);

has 'ua' => (
    is      => 'lazy',
    builder => '_build_ua',
);

has 'json' => (
    is      => 'lazy',
    builder => '_build_json',
);

has 'storage' => (
    is       => 'ro',
    required => 1,
);

has 'knowledge_graph' => (
    is       => 'ro',
    required => 1,
);

has 'hash_manager' => (
    is      => 'lazy',
    builder => '_build_hash_manager',
);

sub _build_logger {
    my $self = shift;
    return Log::Log4perl->get_logger(__PACKAGE__);
}

sub _build_ua {
    my $self = shift;
    
    my $ua = LWP::UserAgent->new(
        timeout => 30,
        agent   => 'WikiCrawler-GeminiBot/1.0',
    );
    
    return $ua;
}

sub _build_json {
    my $self = shift;
    return JSON::XS->new->utf8->pretty;
}

sub _build_hash_manager {
    my $self = shift;
    require WikiCrawler::HashManager;
    return WikiCrawler::HashManager->new();
}

# Check if Gemini service is available
sub service_health_check {
    my $self = shift;
    
    my $health_url = $self->gemini_service_url . '/health';
    
    my $result;
    eval {
        my $response = $self->ua->get($health_url);
        if ($response->is_success) {
            my $data = $self->json->decode($response->decoded_content);
            $self->logger->info("Gemini service healthy: " . ($data->{status} || 'unknown'));
            $result = 1;
        } else {
            $self->logger->error("Gemini service health check failed: " . $response->status_line);
            $result = 0;
        }
    };
    
    if ($@) {
        $self->logger->error("Error checking Gemini service health: $@");
        return 0;
    }
    
    return $result;
}

# Start a chat conversation
sub chat {
    my ($self, $conversation_id, $message, %options) = @_;
    
    unless ($self->service_health_check()) {
        die "Gemini service is not available";
    }
    
    # Gather context from knowledge graph if requested
    my $context = $self->_gather_chat_context($message, %options);
    
    my $chat_data = {
        conversation_id => $conversation_id,
        message         => $message,
        context         => $context,
        max_tokens      => $options{max_tokens} || 1000,
        temperature     => $options{temperature} || 0.7,
    };
    
    my $chat_url = $self->gemini_service_url . '/chat';
    
    eval {
        my $request = POST($chat_url, 
            'Content-Type' => 'application/json',
            Content        => $self->json->encode($chat_data)
        );
        
        my $response = $self->ua->request($request);
        
        if ($response->is_success) {
            my $result = $self->json->decode($response->decoded_content);
            
            $self->logger->info("Chat response received for conversation: $conversation_id");
            
            return {
                success       => 1,
                conversation_id => $result->{conversation_id},
                message       => $result->{message},
                timestamp     => $result->{timestamp},
                context_used  => $result->{context_used} || 0,
            };
        } else {
            my $error = "Chat request failed: " . $response->status_line;
            if ($response->content) {
                eval {
                    my $error_data = $self->json->decode($response->decoded_content);
                    $error .= " - " . $error_data->{detail} if $error_data->{detail};
                };
            }
            
            $self->logger->error($error);
            return {
                success => 0,
                error   => $error,
            };
        }
    };
    
    if ($@) {
        my $error = "Error calling Gemini chat service: $@";
        $self->logger->error($error);
        return {
            success => 0,
            error   => $error,
        };
    }
}

# Knowledge-focused query
sub knowledge_query {
    my ($self, $query, %options) = @_;
    
    unless ($self->service_health_check()) {
        die "Gemini service is not available";
    }
    
    # Gather comprehensive context for knowledge queries
    my $context = $self->_gather_knowledge_context($query, %options);
    
    my $query_data = {
        query           => $query,
        context         => $context,
        conversation_id => $options{conversation_id},  # Optional
    };
    
    my $knowledge_url = $self->gemini_service_url . '/knowledge-query';
    
    eval {
        my $request = POST($knowledge_url,
            'Content-Type' => 'application/json',
            Content        => $self->json->encode($query_data)
        );
        
        my $response = $self->ua->request($request);
        
        if ($response->is_success) {
            my $result = $self->json->decode($response->decoded_content);
            
            $self->logger->info("Knowledge query completed: " . substr($query, 0, 50) . "...");
            
            return {
                success    => 1,
                query      => $result->{query},
                answer     => $result->{answer},
                sources    => $result->{sources} || [],
                confidence => $result->{confidence} || 0.8,
                reasoning  => $result->{reasoning},
            };
        } else {
            my $error = "Knowledge query failed: " . $response->status_line;
            if ($response->content) {
                eval {
                    my $error_data = $self->json->decode($response->decoded_content);
                    $error .= " - " . $error_data->{detail} if $error_data->{detail};
                };
            }
            
            $self->logger->error($error);
            return {
                success => 0,
                error   => $error,
            };
        }
    };
    
    if ($@) {
        my $error = "Error calling Gemini knowledge service: $@";
        $self->logger->error($error);
        return {
            success => 0,
            error   => $error,
        };
    }
}

# Get conversation history
sub get_conversation_history {
    my ($self, $conversation_id) = @_;
    
    my $history_url = $self->gemini_service_url . "/conversation/$conversation_id/history";
    
    eval {
        my $response = $self->ua->get($history_url);
        
        if ($response->is_success) {
            my $result = $self->json->decode($response->decoded_content);
            
            return {
                success       => 1,
                conversation_id => $result->{conversation_id},
                messages      => $result->{messages} || [],
                metadata      => $result->{metadata} || {},
            };
        } else {
            return {
                success => 0,
                error   => "Failed to get conversation history: " . $response->status_line,
            };
        }
    };
    
    if ($@) {
        return {
            success => 0,
            error   => "Error getting conversation history: $@",
        };
    }
}

# List all conversations
sub list_conversations {
    my $self = shift;
    
    my $conversations_url = $self->gemini_service_url . '/conversations';
    
    my $result;
    eval {
        my $response = $self->ua->get($conversations_url);
        
        if ($response->is_success) {
            my $data = $self->json->decode($response->decoded_content);
            
            # Debug: log what we received
            $self->logger->debug("Gemini conversations response: " . ($response->decoded_content || "empty"));
            
            $result = {
                success       => 1,
                conversations => $data->{conversations} || [],
                total         => $data->{total} || 0,
            };
        } else {
            $result = {
                success => 0,
                error   => "Failed to list conversations: " . $response->status_line,
            };
        }
    };
    
    if ($@) {
        $self->logger->error("Error in list_conversations: $@");
        return {
            success => 0,
            error   => "Error listing conversations: $@",
        };
    }
    
    return $result;
}

# Delete conversation
sub delete_conversation {
    my ($self, $conversation_id) = @_;
    
    my $delete_url = $self->gemini_service_url . "/conversation/$conversation_id";
    
    eval {
        my $response = $self->ua->delete($delete_url);
        
        if ($response->is_success) {
            my $result = $self->json->decode($response->decoded_content);
            
            return {
                success => 1,
                message => $result->{message},
            };
        } else {
            return {
                success => 0,
                error   => "Failed to delete conversation: " . $response->status_line,
            };
        }
    };
    
    if ($@) {
        return {
            success => 0,
            error   => "Error deleting conversation: $@",
        };
    }
}

# Get available models from Gemini service
sub get_available_models {
    my $self = shift;
    
    my $models_url = $self->gemini_service_url . '/models';
    
    eval {
        my $response = $self->ua->get($models_url);
        
        if ($response->is_success) {
            my $result = $self->json->decode($response->decoded_content);
            
            return {
                success => 1,
                models  => $result->{models} || [],
            };
        } else {
            return {
                success => 0,
                error   => "Failed to get available models: " . $response->status_line,
            };
        }
    };
    
    if ($@) {
        return {
            success => 0,
            error   => "Error getting available models: $@",
        };
    }
}

# Gather context for chat (lighter context)
sub _gather_chat_context {
    my ($self, $message, %options) = @_;
    
    my $context = {};
    
    # RAG: Try semantic search first, fallback to keyword search
    my $semantic_results = $self->_semantic_search($message, 5);
    if ($semantic_results && @$semantic_results) {
        $context->{semantic_chunks} = $semantic_results;
        $self->logger->debug("Found " . scalar(@$semantic_results) . " semantic chunks for chat");
    }
    
    # Traditional keyword search as backup
    if (length($message) > 3) {
        my $search_results = $self->storage->search_articles($message, 5);
        if ($search_results && @$search_results) {
            $context->{articles} = $search_results;
        }
    }
    
    # Add basic insights if available
    if ($options{include_insights}) {
        eval {
            my $insights = $self->knowledge_graph->get_knowledge_insights(
                min_relevance => 0.4
            );
            $context->{insights} = $insights->{current_state} if $insights;
        };
        if ($@) {
            $self->logger->warn("Failed to get insights for chat context: $@");
        }
    }
    
    return $context;
}

# Gather comprehensive context for knowledge queries
sub _gather_knowledge_context {
    my ($self, $query, %options) = @_;
    
    my $context = {};
    
    # RAG: Prioritize semantic search for knowledge queries
    my $semantic_results = $self->_semantic_search($query, 8);
    if ($semantic_results && @$semantic_results) {
        $context->{semantic_chunks} = $semantic_results;
        $self->logger->info("Found " . scalar(@$semantic_results) . " semantic chunks for knowledge query");
    }
    
    # Traditional search for broader article context
    my $search_results = $self->storage->search_articles($query, 5);
    if ($search_results && @$search_results) {
        $context->{articles} = $search_results;
        
        # Find connections between found articles
        if (@$search_results > 1) {
            $context->{connections} = $self->_find_article_connections($search_results);
        }
    }
    
    # Get knowledge insights
    eval {
        my $insights = $self->knowledge_graph->get_knowledge_insights(
            min_relevance => $options{min_relevance} || 0.3
        );
        
        if ($insights) {
            $context->{insights} = {
                total_articles    => $insights->{current_state}{total_nodes} || 0,
                knowledge_breadth => $insights->{personal_metrics}{knowledge_breadth} || 0,
                learning_velocity => $insights->{personal_metrics}{learning_velocity} || 0,
            };
        }
    };
    if ($@) {
        $self->logger->warn("Failed to get insights for knowledge context: $@");
    }
    
    # Get recent discoveries if relevant
    if ($options{include_recent}) {
        eval {
            my $discoveries = $self->storage->get_recent_discoveries(5);
            $context->{recent_discoveries} = $discoveries if $discoveries;
        };
        if ($@) {
            $self->logger->warn("Failed to get recent discoveries: $@");
        }
    }
    
    return $context;
}

# Find connections between articles
sub _find_article_connections {
    my ($self, $articles) = @_;
    
    my @connections;
    my $dbh = $self->storage->dbh;
    
    # Get article IDs
    my %article_ids = map { $_->{title} => $_->{id} } @$articles;
    my @ids = values %article_ids;
    
    return [] unless @ids > 1;
    
    # Find links between these articles
    my $placeholders = join(',', ('?') x @ids);
    my $links_query = qq{
        SELECT 
            a1.title as from_title,
            a2.title as to_title,
            l.relevance_score as relevance
        FROM links l
        JOIN articles a1 ON l.from_article_id = a1.id
        JOIN articles a2 ON l.to_article_id = a2.id
        WHERE l.from_article_id IN ($placeholders)
          AND l.to_article_id IN ($placeholders)
          AND l.from_article_id != l.to_article_id
          AND l.relevance_score > 0.3
        ORDER BY l.relevance_score DESC
        LIMIT 5
    };
    
    eval {
        my $links = $dbh->selectall_arrayref($links_query, { Slice => {} }, @ids, @ids);
        @connections = @$links if $links;
    };
    
    if ($@) {
        $self->logger->warn("Error finding article connections: $@");
    }
    
    return \@connections;
}

# RAG: Perform semantic search via embedding service
sub _semantic_search {
    my ($self, $query, $limit, $min_similarity) = @_;
    
    $limit ||= 10;
    $min_similarity ||= 0.3;
    
    # Call the embedding service for semantic search
    my $search_url = $self->embedding_service_url . '/search';
    
    my $search_data = {
        query => $query,
        limit => $limit,
        min_similarity => $min_similarity,
    };
    
    eval {
        my $request = POST($search_url,
            'Content-Type' => 'application/json',
            Content => $self->json->encode($search_data)
        );
        
        my $response = $self->ua->request($request);
        
        if ($response->is_success) {
            my $result = $self->json->decode($response->decoded_content);
            
            if ($result->{chunks} && @{$result->{chunks}}) {
                $self->logger->debug("Semantic search found " . scalar(@{$result->{chunks}}) . " chunks");
                return $result->{chunks};
            }
        } else {
            $self->logger->warn("Semantic search request failed: " . $response->status_line);
        }
    };
    
    if ($@) {
        $self->logger->warn("Semantic search error (falling back to keyword search): $@");
    }
    
    return undef;
}

# Generate conversation ID
sub generate_conversation_id {
    my $self = shift;
    my $session_data = "conversation_" . time() . "_" . int(rand(10000));
    return "conv_" . $self->hash_manager->hash_session_id($session_data);
}

1;

__END__

=head1 NAME

WikiCrawler::GeminiBot - Google Gemini API Integration for WikiCrawler

=head1 SYNOPSIS

    use WikiCrawler::GeminiBot;
    
    my $bot = WikiCrawler::GeminiBot->new(
        storage => $storage,
        knowledge_graph => $knowledge_graph
    );
    
    # Start a conversation
    my $conv_id = $bot->generate_conversation_id();
    my $response = $bot->chat($conv_id, "Tell me about artificial intelligence");
    
    # Knowledge-focused query
    my $result = $bot->knowledge_query(
        "What do I know about machine learning?",
        include_recent => 1
    );

=head1 DESCRIPTION

This module provides a clean Perl interface to the Google Gemini AI service.
It integrates with WikiCrawler's existing storage and knowledge graph systems to
provide intelligent, context-aware responses about crawled Wikipedia content.

=head1 FEATURES

=over 4

=item * Conversational chat interface with memory using Gemini 2.0 Flash

=item * Knowledge-based queries with comprehensive context

=item * Automatic context gathering from knowledge graph

=item * Connection discovery between related articles

=item * Conversation management and history

=item * Support for latest Gemini models and features

=back

=head1 METHODS

=head2 chat($conversation_id, $message, %options)

Start or continue a conversation with Gemini. The bot maintains conversation
memory and provides context from the knowledge graph.

Options:
- max_tokens: Maximum response length (default: 1000)
- temperature: Response creativity 0.0-2.0 (default: 0.7)
- include_insights: Include knowledge insights in context

=head2 knowledge_query($query, %options)

Perform a knowledge-focused query with comprehensive context gathering.
Best for factual questions about crawled content.

Options:
- conversation_id: Optional conversation to tie query to
- min_relevance: Minimum relevance for context articles (default: 0.3)
- include_recent: Include recent discoveries

=head2 get_conversation_history($conversation_id)

Get complete history of a conversation.

=head2 list_conversations()

List all active conversations.

=head2 delete_conversation($conversation_id)

Delete a conversation and its history.

=head2 get_available_models()

Get list of available Gemini models from the service.

=head2 service_health_check()

Check if Gemini service is running and accessible.

=head1 AUTHOR

WikiCrawler Project

=cut
