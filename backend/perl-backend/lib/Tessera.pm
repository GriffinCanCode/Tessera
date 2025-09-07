package Tessera;

use strict;
use warnings;
use v5.20;

our $VERSION = '1.0.0';

use YAML::XS qw(LoadFile);
use Log::Log4perl;
use File::Spec;
use Time::HiRes qw(time sleep);

use Tessera::Logger;
use Tessera::Crawler;
use Tessera::Parser;
use Tessera::Storage;
use Tessera::LinkAnalyzer;
use Tessera::KnowledgeGraph;
use Tessera::HashManager;

use Moo;
use namespace::clean;

# Attributes
has 'config_file' => (
    is      => 'ro',
    default => 'config/crawler.yaml',
);

has 'config' => (
    is      => 'lazy',
    builder => '_build_config',
);

has 'tessera_logger' => (
    is      => 'lazy',
    builder => '_build_tessera_logger',
);

has 'logger' => (
    is      => 'lazy',
    builder => '_build_logger',
);

has 'crawler' => (
    is      => 'lazy',
    builder => '_build_crawler',
);

has 'parser' => (
    is      => 'lazy',
    builder => '_build_parser',
);

has 'storage' => (
    is      => 'lazy',
    builder => '_build_storage',
);

has 'link_analyzer' => (
    is      => 'lazy',
    builder => '_build_link_analyzer',
);

has 'knowledge_graph' => (
    is      => 'lazy',
    builder => '_build_knowledge_graph',
);

has 'interests' => (
    is      => 'rw',
    default => sub { [] },
);

has 'session_stats' => (
    is      => 'rw',
    default => sub { {} },
);

# Build configuration from YAML file
sub _build_config {
    my $self = shift;
    
    my $config_path = $self->config_file;
    $config_path = File::Spec->rel2abs($config_path);
    
    die "Config file not found: $config_path" unless -f $config_path;
    
    my $config = LoadFile($config_path);
    
    # Set default values if missing
    $config->{crawler}{delay_between_requests} //= 1;
    $config->{crawler}{max_requests_per_minute} //= 30;
    $config->{crawler}{timeout} //= 30;
    $config->{database}{path} //= 'data/tessera_knowledge.db';
    $config->{logging}{level} //= 'INFO';
    
    return $config;
}

# Initialize enhanced Tessera logger
sub _build_tessera_logger {
    my $self = shift;
    
    my $log_level = $self->config->{logging}{level};
    
    return Tessera::Logger->get_logger(
        'Tessera Core',
        log_level => $log_level
    );
}

# Initialize legacy logger for compatibility
sub _build_logger {
    my $self = shift;
    return $self->tessera_logger->logger;
}

# Build component modules
sub _build_crawler {
    my $self = shift;
    return Tessera::Crawler->new(config => $self->config);
}

sub _build_parser {
    my $self = shift;
    return Tessera::Parser->new(config => $self->config);
}

sub _build_storage {
    my $self = shift;
    return Tessera::Storage->new(config => $self->config);
}

sub _build_link_analyzer {
    my $self = shift;
    return Tessera::LinkAnalyzer->new(config => $self->config);
}

sub _build_knowledge_graph {
    my $self = shift;
    my $kg = Tessera::KnowledgeGraph->new(
        config => $self->config,
        storage => $self->storage,
    );
    
    # Register cache invalidation callback
    $self->storage->cache_invalidation_callback(sub {
        $kg->invalidate_cache();
    });
    
    return $kg;
}

# Main crawling orchestration
sub crawl {
    my ($self, %options) = @_;
    
    my $start_url = $options{start_url} or die "start_url required";
    my $max_depth = $options{max_depth} || $self->config->{wikipedia}{max_depth} || 3;
    my $max_articles = $options{max_articles} || $self->config->{wikipedia}{max_articles_per_session} || 100;
    my $interests = $options{interests} || $self->interests;
    my $project_id = $options{project_id}; # Optional project context
    
    $self->logger->info("Starting crawl from: $start_url");
    $self->logger->info("Max depth: $max_depth, Max articles: $max_articles");
    $self->logger->info("Interests: " . join(", ", @$interests)) if @$interests;
    
    # Set interests on link analyzer
    $self->link_analyzer->set_interests($interests) if @$interests;
    
    # Initialize session stats
    $self->session_stats({
        start_time => time(),
        articles_crawled => 0,
        articles_processed => 0,
        links_analyzed => 0,
        start_url => $start_url,
        max_depth => $max_depth,
        max_articles => $max_articles,
    });
    
    # BFS crawling with interest-based filtering
    my %visited;
    my @queue = ({ url => $start_url, depth => 0 });
    my $articles_crawled = 0;
    
    while (@queue && $articles_crawled < $max_articles) {
        my $current = shift @queue;
        my $url = $current->{url};
        my $depth = $current->{depth};
        
        # Skip if already visited or max depth reached
        next if $visited{$url} || $depth > $max_depth;
        $visited{$url} = 1;
        
        $self->logger->info("Processing ($depth/$max_depth): $url");
        
        # Crawl the page
        my $page_data = $self->crawler->crawl_page($url);
        unless ($page_data) {
            $self->logger->warn("Failed to crawl: $url");
            next;
        }
        
        # Parse the content
        my $article_data = $self->parser->parse_page($page_data->{content}, $url);
        unless ($article_data) {
            $self->logger->warn("Failed to parse: $url");
            next;
        }
        
        $articles_crawled++;
        $self->session_stats->{articles_crawled} = $articles_crawled;
        
        # Store article with project context
        my $article_id = $self->storage->store_article($article_data, $project_id);
        unless ($article_id) {
            $self->logger->warn("Failed to store article: " . $article_data->{title});
            next;
        }
        
        $self->session_stats->{articles_processed}++;
        
        # For the first article, extract interests to make crawling adaptive
        if ($articles_crawled == 1) {
            $self->link_analyzer->extract_interests_from_article($article_data);
        }
        
        # Analyze links for relevance
        if ($article_data->{links} && @{$article_data->{links}}) {
            my $relevant_links = $self->link_analyzer->analyze_links(
                $article_data->{links},
                $article_data
            );
            
            $self->session_stats->{links_analyzed} += @{$article_data->{links}};
            
            # Store links and queue relevant ones for crawling
            for my $link (@$relevant_links) {
                # Check if target article exists
                my $target_title = $link->{title};
                my $target_article = $self->storage->get_article_by_title($target_title);
                
                my $target_id;
                if ($target_article) {
                    $target_id = $target_article->{id};
                } else {
                    # Create placeholder article
                    my $placeholder = {
                        title => $target_title,
                        url => $link->{url},
                        content => '',
                        summary => '',
                        parsed_at => time(),
                    };
                    $target_id = $self->storage->store_article($placeholder);
                }
                
                # Store the link
                if ($target_id) {
                    $self->storage->store_link(
                        $article_id,
                        $target_id,
                        $link->{anchor_text},
                        $link->{relevance_score}
                    );
                }
                
                # Queue for crawling if within depth limit and is valid Wikipedia article
                if ($depth < $max_depth && $self->crawler->is_wikipedia_article($link->{url})) {
                    push @queue, {
                        url => $link->{url},
                        depth => $depth + 1,
                    };
                }
            }
        }
        
        # Progress update every 10 articles
        if ($articles_crawled % 10 == 0) {
            $self->_log_progress();
        }
        
        # Optional: sleep between articles to be nice to Wikipedia
        sleep(0.5);
    }
    
    # Final stats
    $self->session_stats->{end_time} = time();
    $self->session_stats->{duration} = $self->session_stats->{end_time} - $self->session_stats->{start_time};
    
    # Force final cache invalidation to ensure consistency
    $self->storage->force_cache_invalidation();
    
    $self->logger->info("Crawl completed!");
    $self->_log_progress(final => 1);
    
    return $self->session_stats;
}

# Log crawling progress
sub _log_progress {
    my ($self, %options) = @_;
    
    my $stats = $self->session_stats;
    my $elapsed = time() - $stats->{start_time};
    my $rate = $elapsed > 0 ? $stats->{articles_crawled} / $elapsed : 0;
    
    my $message = sprintf(
        "%sArticles: %d processed, %d crawled | Links analyzed: %d | Time: %.1fs | Rate: %.2f articles/sec",
        $options{final} ? "FINAL - " : "",
        $stats->{articles_processed},
        $stats->{articles_crawled},
        $stats->{links_analyzed},
        $elapsed,
        $rate
    );
    
    if ($options{final}) {
        $self->logger->info($message);
        
        # Database stats
        my $db_stats = $self->storage->get_stats();
        $self->logger->info(sprintf(
            "Database: %d total articles, %d total links, %.1f avg links per article",
            $db_stats->{total_articles},
            $db_stats->{total_links},
            $db_stats->{avg_links_per_article}
        ));
    } else {
        $self->logger->info($message);
    }
}

# Crawl from Wikipedia title instead of URL
sub crawl_from_title {
    my ($self, $title, %options) = @_;
    
    my $url = $self->crawler->title_to_url($title);
    
    return $self->crawl(
        start_url => $url,
        %options
    );
}

# Build and return knowledge graph
sub build_knowledge_graph {
    my ($self, %options) = @_;
    
    $self->logger->info("Building knowledge graph...");
    
    my $graph = $self->knowledge_graph->build_graph(%options);
    
    $self->logger->info(sprintf(
        "Knowledge graph built: %d nodes, %d edges",
        scalar(keys %{$graph->{nodes}}),
        scalar(@{$graph->{edges}})
    ));
    
    return $graph;
}

# Search for articles
sub search {
    my ($self, $query, $limit) = @_;
    
    # Handle both old style (scalar limit) and new style (hash options)
    if (ref $limit eq 'HASH') {
        my %options = %$limit;
        return $self->storage->search_articles($query, $options{limit});
    } else {
        # Legacy style - second parameter is limit
        return $self->storage->search_articles($query, $limit);
    }
}

# Get article by title
sub get_article {
    my ($self, $title) = @_;
    
    return $self->storage->get_article_by_title($title);
}

# Get database statistics
sub get_stats {
    my $self = shift;
    
    my $db_stats = $self->storage->get_stats();
    $db_stats->{session_stats} = $self->session_stats if %{$self->session_stats};
    
    return $db_stats;
}

# Get knowledge hubs (most connected articles)
sub get_knowledge_hubs {
    my ($self, $limit) = @_;
    
    return $self->storage->get_knowledge_hubs($limit);
}

# Get recent discoveries
sub get_recent_discoveries {
    my ($self, $limit) = @_;
    
    return $self->storage->get_recent_discoveries($limit);
}

# Cleanup old data
sub cleanup {
    my ($self, $keep_days) = @_;
    
    return $self->storage->cleanup($keep_days);
}

# Export knowledge graph
sub export_graph {
    my ($self, $format, $filename, %graph_options) = @_;
    
    my $graph = $self->build_knowledge_graph(%graph_options);
    
    return $self->knowledge_graph->export_graph($graph, $format, $filename);
}

1;

__END__

=head1 NAME

Tessera - Personal Wikipedia Knowledge Graph Builder

=head1 SYNOPSIS

    use Tessera;
    
    my $crawler = Tessera->new(
        config_file => 'config/crawler.yaml'
    );
    
    # Set interests
    $crawler->interests(['artificial intelligence', 'machine learning']);
    
    # Crawl starting from a Wikipedia article
    my $stats = $crawler->crawl_from_title(
        'Artificial Intelligence',
        max_depth => 3,
        max_articles => 50
    );
    
    # Build knowledge graph
    my $graph = $crawler->build_knowledge_graph(min_relevance => 0.5);
    
    # Export graph
    $crawler->export_graph('json', 'data/knowledge_graph.json');

=head1 DESCRIPTION

Tessera is a modern Perl-based system for crawling Wikipedia, following
personalized interests, and building knowledge graphs. It provides intelligent
link analysis, rate limiting, and multiple export formats.

=head1 FEATURES

=over 4

=item * Intelligent web crawling with rate limiting

=item * HTML parsing and content extraction

=item * Interest-based link analysis and filtering

=item * Knowledge graph construction and analysis

=item * SQLite database storage

=item * Multiple export formats (JSON, GraphML, DOT)

=item * REST API server

=item * Configurable crawling parameters

=back

=head1 METHODS

=head2 crawl(%options)

Main crawling method. Options include:
- start_url: Starting Wikipedia URL
- max_depth: Maximum link depth to follow
- max_articles: Maximum articles to crawl
- interests: Array of interest keywords

=head2 crawl_from_title($title, %options)

Convenience method to crawl starting from article title.

=head2 build_knowledge_graph(%options)

Builds and returns knowledge graph from crawled data.

=head2 search($query, %options)

Searches for articles matching query.

=head2 export_graph($format, $filename, %options)

Exports knowledge graph to specified format.

=head1 CONFIGURATION

Tessera uses YAML configuration files. See config/crawler.yaml for options.

=head1 AUTHOR

Tessera Project

=head1 LICENSE

This is free software; you can redistribute it and/or modify it under the same
terms as the Perl 5 programming language system itself.

=cut
