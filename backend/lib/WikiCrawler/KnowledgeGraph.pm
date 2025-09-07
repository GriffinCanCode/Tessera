package WikiCrawler::KnowledgeGraph;

use strict;
use warnings;
use v5.20;

use List::Util qw(sum max min uniq);
use Log::Log4perl;
use Data::Dumper;
use Statistics::R;
use JSON::XS;
use FindBin;
use File::Spec;
use File::Path qw(make_path);
use Storable qw(store retrieve);

use Moo;
use namespace::clean;

# Attributes
has 'config' => (
    is       => 'ro',
    required => 1,
);

has 'storage' => (
    is       => 'ro',
    required => 1,
);

has 'logger' => (
    is      => 'lazy',
    builder => '_build_logger',
);

has 'r_instance' => (
    is      => 'lazy',
    builder => '_build_r_instance',
);

has 'r_scripts_path' => (
    is      => 'lazy',
    builder => '_build_r_scripts_path',
);

has 'json' => (
    is      => 'lazy',
    builder => '_build_json',
);

has 'hash_manager' => (
    is      => 'lazy',
    builder => '_build_hash_manager',
);

# Cache attributes
has 'cache_dir' => (
    is      => 'lazy',
    builder => '_build_cache_dir',
);

has 'memory_cache' => (
    is      => 'rw',
    default => sub { {} },
);

has 'max_cache_entries' => (
    is      => 'ro',
    default => 50,
);

has 'cache_ttl_seconds' => (
    is      => 'ro',
    default => 3600, # 1 hour
);

sub _build_logger {
    my $self = shift;
    return Log::Log4perl->get_logger(__PACKAGE__);
}

sub _build_r_instance {
    my $self = shift;
    
    my $r = Statistics::R->new();
    
    # Load required libraries one by one
    eval {
        $r->run('library(igraph)');
        $r->run('library(networkD3)');  
        $r->run('library(visNetwork)');
        $r->run('library(jsonlite)');
    };
    
    if ($@) {
        $self->logger->warn("Some R libraries may not have loaded properly: $@");
    }
    
    $self->logger->info("R instance initialized with required libraries");
    return $r;
}

sub _build_r_scripts_path {
    my $self = shift;
    return File::Spec->catdir($FindBin::Bin, '..', 'r_scripts');
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

sub _build_cache_dir {
    my $self = shift;
    my $cache_dir = File::Spec->catdir($FindBin::Bin, '..', 'data', 'cache');
    make_path($cache_dir) unless -d $cache_dir;
    return $cache_dir;
}

# Cache Management Methods

# Generate cache key based on graph parameters and data modification time
sub _generate_cache_key {
    my ($self, %options) = @_;
    
    my $min_relevance = $options{min_relevance} || 0.3;
    my $max_depth = $options{max_depth} || 3;
    my $center_article_id = $options{center_article_id} || 'all';
    my $enhanced_analysis = $options{enhanced_analysis} ? 1 : 0;
    
    # Get database modification timestamp
    my $db_timestamp = $self->_get_db_modification_timestamp();
    
    # Create cache key from parameters and data state
    my $key_data = {
        min_relevance => $min_relevance,
        max_depth => $max_depth,
        center_article_id => $center_article_id,
        enhanced_analysis => $enhanced_analysis,
        db_timestamp => $db_timestamp
    };
    
    return $self->hash_manager->hash_cache_key($key_data);
}

# Get the latest modification timestamp from database
sub _get_db_modification_timestamp {
    my ($self) = @_;
    
    my $dbh = $self->storage->dbh;
    
    # Get max timestamp from both articles and links tables
    my ($max_article_ts) = $dbh->selectrow_array(
        "SELECT MAX(COALESCE(updated_at, created_at)) FROM articles"
    );
    
    my ($max_link_ts) = $dbh->selectrow_array(
        "SELECT MAX(created_at) FROM links"
    );
    
    # Return the latest timestamp
    return max($max_article_ts || 0, $max_link_ts || 0);
}

# Check if cached data exists and is valid
sub _is_cache_valid {
    my ($self, $cache_key) = @_;
    
    # Check memory cache first
    if (my $cached = $self->memory_cache->{$cache_key}) {
        my $age = time() - $cached->{timestamp};
        return $age < $self->cache_ttl_seconds;
    }
    
    # Check file cache
    my $cache_file = File::Spec->catfile($self->cache_dir, "$cache_key.cache");
    if (-f $cache_file) {
        my $age = time() - (stat($cache_file))[9]; # modification time
        return $age < $self->cache_ttl_seconds;
    }
    
    return 0;
}

# Load graph from cache
sub _load_from_cache {
    my ($self, $cache_key) = @_;
    
    # Try memory cache first
    if (my $cached = $self->memory_cache->{$cache_key}) {
        my $age = time() - $cached->{timestamp};
        if ($age < $self->cache_ttl_seconds) {
            $self->logger->debug("Cache hit (memory): $cache_key");
            return $cached->{data};
        }
    }
    
    # Try file cache
    my $cache_file = File::Spec->catfile($self->cache_dir, "$cache_key.cache");
    if (-f $cache_file) {
        my $age = time() - (stat($cache_file))[9];
        if ($age < $self->cache_ttl_seconds) {
            eval {
                my $data = retrieve($cache_file);
                # Also cache in memory for faster access
                $self->_store_in_memory_cache($cache_key, $data);
                $self->logger->debug("Cache hit (file): $cache_key");
                return $data;
            };
            if ($@) {
                $self->logger->warn("Failed to load cache file $cache_file: $@");
            }
        }
    }
    
    return;
}

# Save graph to cache
sub _save_to_cache {
    my ($self, $cache_key, $data) = @_;
    
    # Store in memory cache (with size limit)
    $self->_store_in_memory_cache($cache_key, $data);
    
    # Store in file cache
    my $cache_file = File::Spec->catfile($self->cache_dir, "$cache_key.cache");
    eval {
        store($data, $cache_file);
        $self->logger->debug("Cached graph: $cache_key");
    };
    if ($@) {
        $self->logger->warn("Failed to save cache file $cache_file: $@");
    }
}

# Store in memory cache with size management
sub _store_in_memory_cache {
    my ($self, $cache_key, $data) = @_;
    
    my $cache = $self->memory_cache;
    
    # Remove old entries if cache is full
    if (keys %$cache >= $self->max_cache_entries) {
        my @sorted_keys = sort { $cache->{$a}{timestamp} <=> $cache->{$b}{timestamp} } 
                          keys %$cache;
        my $to_remove = int(@sorted_keys / 3); # Remove oldest 1/3
        for my $old_key (@sorted_keys[0..$to_remove-1]) {
            delete $cache->{$old_key};
        }
    }
    
    $cache->{$cache_key} = {
        data => $data,
        timestamp => time(),
    };
}

# Invalidate all caches (called when data changes)
sub invalidate_cache {
    my ($self) = @_;
    
    $self->logger->info("Invalidating knowledge graph cache");
    
    # Clear memory cache
    $self->memory_cache({});
    
    # Remove cache files
    my $cache_dir = $self->cache_dir;
    if (-d $cache_dir) {
        opendir(my $dh, $cache_dir) or return;
        while (my $file = readdir($dh)) {
            next unless $file =~ /\.cache$/;
            my $path = File::Spec->catfile($cache_dir, $file);
            unlink $path or $self->logger->warn("Failed to remove cache file: $path");
        }
        closedir($dh);
    }
}

# Build knowledge graph from stored articles and links
sub build_graph {
    my ($self, %options) = @_;
    
    # Generate cache key based on parameters and data state
    my $cache_key = $self->_generate_cache_key(%options);
    
    # Try to load from cache first
    if (my $cached_graph = $self->_load_from_cache($cache_key)) {
        $self->logger->info(sprintf(
            "Loaded knowledge graph from cache with %d nodes and %d edges",
            scalar(keys %{$cached_graph->{nodes}}),
            scalar(@{$cached_graph->{edges}})
        ));
        return $cached_graph;
    }
    
    $self->logger->info("Building knowledge graph (cache miss)...");
    
    my $min_relevance = $options{min_relevance} || 0.3;
    my $max_depth = $options{max_depth} || 3;
    my $center_article_id = $options{center_article_id};
    
    my $graph = {
        nodes => {},
        edges => [],
        metadata => {
            created_at => time(),
            min_relevance => $min_relevance,
            max_depth => $max_depth,
            center_article => $center_article_id,
        },
    };
    
    if ($center_article_id) {
        # Build graph centered around specific article
        $graph = $self->_build_centered_graph($center_article_id, $max_depth, $min_relevance);
    } else {
        # Build complete graph
        $graph = $self->_build_complete_graph($min_relevance);
    }
    
    # Calculate graph metrics
    $graph->{metrics} = $self->_calculate_graph_metrics($graph);
    
    # Add R-enhanced analysis if requested
    if ($options{enhanced_analysis}) {
        $graph = $self->add_enhanced_analysis($graph, %options);
    }
    
    $self->logger->info(sprintf(
        "Built knowledge graph with %d nodes and %d edges",
        scalar(keys %{$graph->{nodes}}),
        scalar(@{$graph->{edges}})
    ));
    
    # Save to cache for future use
    $self->_save_to_cache($cache_key, $graph);
    
    return $graph;
}

# Build graph centered around a specific article
sub _build_centered_graph {
    my ($self, $center_id, $max_depth, $min_relevance) = @_;
    
    my $graph = {
        nodes => {},
        edges => [],
        metadata => {
            type => 'centered',
            center_article_id => $center_id,
        },
    };
    
    my %visited;
    my @queue = ({ id => $center_id, depth => 0 });
    
    while (@queue) {
        my $current = shift @queue;
        my $article_id = $current->{id};
        my $depth = $current->{depth};
        
        next if $visited{$article_id} || $depth > $max_depth;
        $visited{$article_id} = 1;
        
        # Get article data
        my $article = $self->storage->get_article_by_id($article_id);
        next unless $article;
        
        # Add node
        $graph->{nodes}{$article_id} = $self->_create_node($article, $depth);
        
        # Get outbound links
        my $links = $self->storage->get_outbound_links($article_id, $min_relevance);
        
        for my $link (@$links) {
            my $target_id = $link->{to_article_id};
            
            # Add edge
            push @{$graph->{edges}}, {
                from => $article_id,
                to => $target_id,
                weight => $link->{relevance_score},
                anchor_text => $link->{anchor_text},
            };
            
            # Queue target for processing if within depth limit
            if ($depth < $max_depth && !$visited{$target_id}) {
                push @queue, { id => $target_id, depth => $depth + 1 };
            }
        }
    }
    
    return $graph;
}

# Build complete graph from all articles
sub _build_complete_graph {
    my ($self, $min_relevance) = @_;
    
    my $graph = {
        nodes => {},
        edges => [],
        metadata => {
            type => 'complete',
        },
    };
    
    # Get all articles
    my $dbh = $self->storage->dbh;
    my $articles = $dbh->selectall_arrayref(
        "SELECT id, title, url, summary FROM articles ORDER BY id",
        { Slice => {} }
    );
    
    # Add all nodes
    for my $article (@$articles) {
        $graph->{nodes}{$article->{id}} = $self->_create_node($article, 0);
    }
    
    # Get all relevant links
    my $links = $dbh->selectall_arrayref(
        "SELECT * FROM links WHERE relevance_score >= ? ORDER BY relevance_score DESC",
        { Slice => {} },
        $min_relevance
    );
    
    # Add all edges
    for my $link (@$links) {
        push @{$graph->{edges}}, {
            from => $link->{from_article_id},
            to => $link->{to_article_id},
            weight => $link->{relevance_score},
            anchor_text => $link->{anchor_text},
        };
    }
    
    return $graph;
}

# Create a node representation for an article
sub _create_node {
    my ($self, $article, $depth) = @_;
    
    return {
        id => $article->{id},
        title => $article->{title},
        url => $article->{url},
        summary => $article->{summary},
        depth => $depth,
        categories => $article->{categories} || [],
        coordinates => $article->{coordinates} || {},
        node_type => $self->_classify_node($article),
        importance => $self->_calculate_node_importance($article->{id}),
    };
}

# Classify node type based on content
sub _classify_node {
    my ($self, $article) = @_;
    
    my $title = lc($article->{title} || '');
    my $categories = $article->{categories} || [];
    my $cat_text = lc(join(' ', @$categories));
    
    # Person
    if ($title =~ /\b(born|died)\b/ || $cat_text =~ /people|births|deaths/) {
        return 'person';
    }
    
    # Place/Location
    if ($article->{coordinates} && %{$article->{coordinates}} ||
        $cat_text =~ /cities|countries|places|geography/) {
        return 'place';
    }
    
    # Concept/Topic
    if ($cat_text =~ /concepts|theories|algorithms|methods/) {
        return 'concept';
    }
    
    # Organization
    if ($cat_text =~ /companies|organizations|institutions/) {
        return 'organization';
    }
    
    # Event
    if ($cat_text =~ /events|wars|battles|conferences/) {
        return 'event';
    }
    
    # Technology/Science
    if ($cat_text =~ /technology|science|computing|software/) {
        return 'technology';
    }
    
    return 'general';
}

# Calculate node importance based on connections
sub _calculate_node_importance {
    my ($self, $article_id) = @_;
    
    my $dbh = $self->storage->dbh;
    
    # Count inbound and outbound links
    my ($inbound_count) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM links WHERE to_article_id = ?",
        {}, $article_id
    );
    
    my ($outbound_count) = $dbh->selectrow_array(
        "SELECT COUNT(*) FROM links WHERE from_article_id = ?",
        {}, $article_id
    );
    
    # Weight inbound links more heavily (like PageRank)
    my $importance = ($inbound_count * 2 + $outbound_count) / 3;
    
    # Normalize to 0-1 scale (simple approach)
    return min(1.0, $importance / 10);
}

# Calculate various graph metrics
sub _calculate_graph_metrics {
    my ($self, $graph) = @_;
    
    my $nodes = $graph->{nodes};
    my $edges = $graph->{edges};
    
    my $node_count = keys %$nodes;
    my $edge_count = @$edges;
    
    # Build adjacency lists for analysis
    my %outbound = ();
    my %inbound = ();
    
    for my $edge (@$edges) {
        push @{$outbound{$edge->{from}}}, $edge->{to};
        push @{$inbound{$edge->{to}}}, $edge->{from};
    }
    
    # Calculate degree statistics
    my @out_degrees = map { scalar(@{$outbound{$_} || []}) } keys %$nodes;
    my @in_degrees = map { scalar(@{$inbound{$_} || []}) } keys %$nodes;
    
    my $metrics = {
        node_count => $node_count,
        edge_count => $edge_count,
        density => $node_count > 1 ? ($edge_count / ($node_count * ($node_count - 1))) : 0,
        
        # Degree statistics
        avg_out_degree => $node_count > 0 ? (sum(@out_degrees) / $node_count) : 0,
        avg_in_degree => $node_count > 0 ? (sum(@in_degrees) / $node_count) : 0,
        max_out_degree => max(@out_degrees) || 0,
        max_in_degree => max(@in_degrees) || 0,
        
        # Node type distribution
        node_types => $self->_get_node_type_distribution($nodes),
        
        # Average edge weight
        avg_edge_weight => @$edges ? (sum(map { $_->{weight} } @$edges) / @$edges) : 0,
        
        # Connectivity
        connected_components => $self->_count_connected_components($nodes, $edges),
    };
    
    return $metrics;
}

# Get distribution of node types
sub _get_node_type_distribution {
    my ($self, $nodes) = @_;
    
    my %distribution;
    
    for my $node (values %$nodes) {
        $distribution{$node->{node_type}}++;
    }
    
    return \%distribution;
}

# Count connected components (simplified version)
sub _count_connected_components {
    my ($self, $nodes, $edges) = @_;
    
    my %adjacency;
    my %visited;
    
    # Build adjacency list (treat as undirected)
    for my $edge (@$edges) {
        push @{$adjacency{$edge->{from}}}, $edge->{to};
        push @{$adjacency{$edge->{to}}}, $edge->{from};
    }
    
    my $components = 0;
    
    for my $node_id (keys %$nodes) {
        next if $visited{$node_id};
        
        # DFS to find connected component
        $components++;
        my @stack = ($node_id);
        
        while (@stack) {
            my $current = pop @stack;
            next if $visited{$current};
            $visited{$current} = 1;
            
            for my $neighbor (@{$adjacency{$current} || []}) {
                push @stack, $neighbor unless $visited{$neighbor};
            }
        }
    }
    
    return $components;
}

# Find shortest path between two nodes
sub find_shortest_path {
    my ($self, $graph, $start_id, $end_id) = @_;
    
    return [] unless $graph->{nodes}{$start_id} && $graph->{nodes}{$end_id};
    
    # Build adjacency list
    my %adjacency;
    for my $edge (@{$graph->{edges}}) {
        push @{$adjacency{$edge->{from}}}, {
            to => $edge->{to},
            weight => $edge->{weight},
        };
    }
    
    # BFS for shortest path
    my %visited = ($start_id => 1);
    my %parent;
    my @queue = ($start_id);
    
    while (@queue) {
        my $current = shift @queue;
        
        if ($current == $end_id) {
            # Reconstruct path
            my @path;
            my $node = $end_id;
            
            while (defined $node) {
                unshift @path, $node;
                $node = $parent{$node};
            }
            
            return \@path;
        }
        
        for my $neighbor (@{$adjacency{$current} || []}) {
            my $neighbor_id = $neighbor->{to};
            
            unless ($visited{$neighbor_id}) {
                $visited{$neighbor_id} = 1;
                $parent{$neighbor_id} = $current;
                push @queue, $neighbor_id;
            }
        }
    }
    
    return []; # No path found
}

# Get nodes within N degrees of a given node
sub get_neighbors {
    my ($self, $graph, $center_id, $max_distance) = @_;
    
    $max_distance ||= 1;
    
    my %neighbors;
    my %visited = ($center_id => 1);
    my @queue = ({ id => $center_id, distance => 0 });
    
    # Build adjacency list
    my %adjacency;
    for my $edge (@{$graph->{edges}}) {
        push @{$adjacency{$edge->{from}}}, $edge->{to};
        push @{$adjacency{$edge->{to}}}, $edge->{from}; # Treat as undirected
    }
    
    while (@queue) {
        my $current = shift @queue;
        my $node_id = $current->{id};
        my $distance = $current->{distance};
        
        if ($distance > 0) {
            $neighbors{$node_id} = {
                node => $graph->{nodes}{$node_id},
                distance => $distance,
            };
        }
        
        if ($distance < $max_distance) {
            for my $neighbor_id (@{$adjacency{$node_id} || []}) {
                unless ($visited{$neighbor_id}) {
                    $visited{$neighbor_id} = 1;
                    push @queue, { id => $neighbor_id, distance => $distance + 1 };
                }
            }
        }
    }
    
    return \%neighbors;
}

# Export graph to various formats
sub export_graph {
    my ($self, $graph, $format, $filename) = @_;
    
    $format ||= 'json';
    
    if ($format eq 'json') {
        return $self->_export_json($graph, $filename);
    } elsif ($format eq 'graphml') {
        return $self->_export_graphml($graph, $filename);
    } elsif ($format eq 'dot') {
        return $self->_export_dot($graph, $filename);
    } else {
        $self->logger->error("Unsupported export format: $format");
        return;
    }
}

# Export to JSON format
sub _export_json {
    my ($self, $graph, $filename) = @_;
    
    require JSON::XS;
    my $json = JSON::XS->new->utf8->pretty;
    
    my $json_data = $json->encode($graph);
    
    if ($filename) {
        open my $fh, '>', $filename or die "Cannot open $filename: $!";
        print $fh $json_data;
        close $fh;
        $self->logger->info("Exported graph to JSON: $filename");
    }
    
    return $json_data;
}

# Export to GraphML format (simplified)
sub _export_graphml {
    my ($self, $graph, $filename) = @_;
    
    my $xml = qq{<?xml version="1.0" encoding="UTF-8"?>\n};
    $xml .= qq{<graphml xmlns="http://graphml.graphdrawing.org/xmlns"\n};
    $xml .= qq{         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"\n};
    $xml .= qq{         xsi:schemaLocation="http://graphml.graphdrawing.org/xmlns\n};
    $xml .= qq{         http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd">\n};
    
    # Define attributes
    $xml .= qq{  <key id="title" for="node" attr.name="title" attr.type="string"/>\n};
    $xml .= qq{  <key id="weight" for="edge" attr.name="weight" attr.type="double"/>\n};
    
    $xml .= qq{  <graph id="WikiGraph" edgedefault="directed">\n};
    
    # Add nodes
    for my $node_id (keys %{$graph->{nodes}}) {
        my $node = $graph->{nodes}{$node_id};
        $xml .= qq{    <node id="$node_id">\n};
        $xml .= qq{      <data key="title">} . _xml_escape($node->{title}) . qq{</data>\n};
        $xml .= qq{    </node>\n};
    }
    
    # Add edges
    for my $edge (@{$graph->{edges}}) {
        $xml .= qq{    <edge source="$edge->{from}" target="$edge->{to}">\n};
        $xml .= qq{      <data key="weight">$edge->{weight}</data>\n};
        $xml .= qq{    </edge>\n};
    }
    
    $xml .= qq{  </graph>\n};
    $xml .= qq{</graphml>\n};
    
    if ($filename) {
        open my $fh, '>', $filename or die "Cannot open $filename: $!";
        print $fh $xml;
        close $fh;
        $self->logger->info("Exported graph to GraphML: $filename");
    }
    
    return $xml;
}

# Simple XML escaping
sub _xml_escape {
    my $text = shift;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/'/&apos;/g;
    return $text;
}

# Export to DOT format for Graphviz
sub _export_dot {
    my ($self, $graph, $filename) = @_;
    
    my $dot = "digraph WikiGraph {\n";
    $dot .= "  rankdir=LR;\n";
    $dot .= "  node [shape=ellipse];\n";
    
    # Add nodes
    for my $node_id (keys %{$graph->{nodes}}) {
        my $node = $graph->{nodes}{$node_id};
        my $label = $node->{title};
        $label =~ s/"/\\"/g;
        $dot .= qq{  "$node_id" [label="$label"];\n};
    }
    
    # Add edges
    for my $edge (@{$graph->{edges}}) {
        my $weight = sprintf("%.2f", $edge->{weight});
        $dot .= qq{  "$edge->{from}" -> "$edge->{to}" [label="$weight"];\n};
    }
    
    $dot .= "}\n";
    
    if ($filename) {
        open my $fh, '>', $filename or die "Cannot open $filename: $!";
        print $fh $dot;
        close $fh;
        $self->logger->info("Exported graph to DOT: $filename");
    }
    
    return $dot;
}

# Enhanced analysis using R integration
sub add_enhanced_analysis {
    my ($self, $graph, %options) = @_;
    
    $self->logger->info("Starting R-enhanced graph analysis");
    
    eval {
        # Add enhanced metrics
        if ($options{include_enhanced_metrics} // 1) {
            $graph->{enhanced_metrics} = $self->calculate_enhanced_metrics($graph);
        }
        
        # Add advanced centrality measures
        if ($options{include_centrality} // 1) {
            $graph->{centrality_measures} = $self->calculate_centrality_measures($graph);
        }
        
        # Add community detection
        if ($options{include_communities} // 1) {
            $graph->{communities} = $self->detect_communities($graph);
        }
        
        # Add advanced layouts
        if ($options{include_layouts} // 1) {
            $graph->{advanced_layouts} = $self->calculate_advanced_layouts($graph);
        }
        
        # Add cluster analysis
        if ($options{include_clustering} // 1) {
            $graph->{cluster_analysis} = $self->analyze_clusters($graph);
        }
        
        $self->logger->info("R-enhanced analysis completed successfully");
    };
    
    if ($@) {
        $self->logger->error("R-enhanced analysis failed: $@");
        $graph->{r_analysis_error} = $@;
    }
    
    return $graph;
}

# Calculate enhanced metrics using R
sub calculate_enhanced_metrics {
    my ($self, $graph) = @_;
    
    my $json_input = $self->json->encode($graph);
    
    my $r_script = File::Spec->catfile($self->r_scripts_path, 'graph_analysis.R');
    
    # Source the R script
    $self->r_instance->run(qq{source("$r_script")});
    
    # Call the R function
    $self->r_instance->set('json_input', $json_input);
    my $result = $self->r_instance->get('process_graph(json_input)');
    
    # Parse R result
    my $enhanced_data = eval { $self->json->decode($result) };
    if ($@) {
        $self->logger->error("Failed to parse R enhanced metrics result: $@");
        return {};
    }
    
    return $enhanced_data->{enhanced_metrics} // {};
}

# Calculate centrality measures using R
sub calculate_centrality_measures {
    my ($self, $graph) = @_;
    
    my $json_input = $self->json->encode($graph);
    
    my $r_script = File::Spec->catfile($self->r_scripts_path, 'graph_analysis.R');
    
    # Source the R script
    $self->r_instance->run(qq{source("$r_script")});
    
    # Call the R function
    $self->r_instance->set('json_input', $json_input);
    my $result = $self->r_instance->get('process_graph(json_input)');
    
    # Parse R result
    my $analysis_data = eval { $self->json->decode($result) };
    if ($@) {
        $self->logger->error("Failed to parse R centrality result: $@");
        return {};
    }
    
    my $centrality = $analysis_data->{centrality_measures} // {};
    
    # Update node importance scores with PageRank
    if ($centrality->{pagerank}) {
        my $pagerank = $centrality->{pagerank};
        for my $node_id (keys %{$graph->{nodes}}) {
            if (exists $pagerank->{$node_id}) {
                $graph->{nodes}{$node_id}{pagerank_score} = $pagerank->{$node_id};
                # Update importance with PageRank as primary measure
                $graph->{nodes}{$node_id}{importance} = $pagerank->{$node_id};
            }
        }
    }
    
    return $centrality;
}

# Detect communities using R
sub detect_communities {
    my ($self, $graph) = @_;
    
    my $json_input = $self->json->encode($graph);
    
    my $r_script = File::Spec->catfile($self->r_scripts_path, 'graph_analysis.R');
    
    # Source the R script
    $self->r_instance->run(qq{source("$r_script")});
    
    # Call the R function
    $self->r_instance->set('json_input', $json_input);
    my $result = $self->r_instance->get('process_graph(json_input)');
    
    # Parse R result
    my $analysis_data = eval { $self->json->decode($result) };
    if ($@) {
        $self->logger->error("Failed to parse R community detection result: $@");
        return {};
    }
    
    my $communities = $analysis_data->{communities} // {};
    
    # Add community membership to nodes
    for my $method (keys %$communities) {
        my $membership = $communities->{$method}{membership};
        if ($membership) {
            for my $node_id (keys %$membership) {
                $graph->{nodes}{$node_id}{"${method}_community"} = $membership->{$node_id};
            }
        }
    }
    
    return $communities;
}

# Calculate advanced layouts using R
sub calculate_advanced_layouts {
    my ($self, $graph) = @_;
    
    my $json_input = $self->json->encode($graph);
    
    my $r_script = File::Spec->catfile($self->r_scripts_path, 'layout_algorithms.R');
    
    # Source the R script
    $self->r_instance->run(qq{source("$r_script")});
    
    # Call the R function
    $self->r_instance->set('json_input', $json_input);
    my $result = $self->r_instance->get('calculate_advanced_layouts(json_input)');
    
    # Parse R result
    my $layout_data = eval { $self->json->decode($result) };
    if ($@) {
        $self->logger->error("Failed to parse R layout result: $@");
        return {};
    }
    
    return $layout_data // {};
}

# Analyze clusters using R
sub analyze_clusters {
    my ($self, $graph) = @_;
    
    my $json_input = $self->json->encode($graph);
    
    my $r_script = File::Spec->catfile($self->r_scripts_path, 'graph_analysis.R');
    
    # Source the R script
    $self->r_instance->run(qq{source("$r_script")});
    
    # Call the R function
    $self->r_instance->set('json_input', $json_input);
    my $result = $self->r_instance->get('process_graph(json_input)');
    
    # Parse R result
    my $analysis_data = eval { $self->json->decode($result) };
    if ($@) {
        $self->logger->error("Failed to parse R cluster analysis result: $@");
        return {};
    }
    
    return $analysis_data->{cluster_analysis} // {};
}

# Generate R-based visualizations
sub generate_r_visualizations {
    my ($self, $graph, %options) = @_;
    
    my $output_dir = $options{output_dir} || File::Spec->catdir($FindBin::Bin, '..', 'data', 'visualizations');
    
    # Create output directory if it doesn't exist
    unless (-d $output_dir) {
        mkdir $output_dir or die "Cannot create output directory $output_dir: $!";
    }
    
    my $json_input = $self->json->encode($graph);
    
    # Generate networkD3 visualization
    $self->r_instance->run(qq{
        library(networkD3)
        library(htmlwidgets)
        
        graph_data <- fromJSON('$json_input')
        
        # Create nodes data frame
        nodes_df <- data.frame(
            name = names(graph_data\$nodes),
            group = sapply(graph_data\$nodes, function(x) x\$node_type),
            stringsAsFactors = FALSE
        )
        
        # Create edges data frame  
        edges_df <- data.frame(
            source = sapply(graph_data\$edges, function(x) match(x\$from, nodes_df\$name) - 1),
            target = sapply(graph_data\$edges, function(x) match(x\$to, nodes_df\$name) - 1),
            value = sapply(graph_data\$edges, function(x) x\$weight),
            stringsAsFactors = FALSE
        )
        
        # Create force network
        network <- forceNetwork(
            Links = edges_df,
            Nodes = nodes_df,
            Source = "source",
            Target = "target",
            Value = "value",
            NodeID = "name",
            Group = "group",
            opacity = 0.8,
            fontSize = 12,
            fontFamily = "serif"
        )
        
        # Save visualization
        saveWidget(network, file.path("$output_dir", "force_network.html"))
    });
    
    # Generate visNetwork visualization
    $self->r_instance->run(qq{
        library(visNetwork)
        
        # Create visNetwork format
        vis_nodes <- data.frame(
            id = names(graph_data\$nodes),
            label = sapply(graph_data\$nodes, function(x) x\$title),
            group = sapply(graph_data\$nodes, function(x) x\$node_type),
            stringsAsFactors = FALSE
        )
        
        vis_edges <- data.frame(
            from = sapply(graph_data\$edges, function(x) x\$from),
            to = sapply(graph_data\$edges, function(x) x\$to),
            width = sapply(graph_data\$edges, function(x) x\$weight * 3),
            stringsAsFactors = FALSE
        )
        
        # Create interactive network
        vis_network <- visNetwork(vis_nodes, vis_edges) \%>\%
            visOptions(highlightNearest = TRUE, nodesIdSelection = TRUE) \%>\%
            visLayout(randomSeed = 123) \%>\%
            visPhysics(stabilization = FALSE)
        
        # Save visualization
        visSave(vis_network, file.path("$output_dir", "interactive_network.html"))
    });
    
    $self->logger->info("R visualizations saved to $output_dir");
    
    return {
        force_network => File::Spec->catfile($output_dir, 'force_network.html'),
        interactive_network => File::Spec->catfile($output_dir, 'interactive_network.html')
    };
}

# Analyze temporal patterns of knowledge graph evolution
sub analyze_temporal_patterns {
    my ($self, %options) = @_;
    
    # Generate cache key for temporal analysis
    my $temporal_cache_key = $self->_generate_cache_key(%options, temporal_analysis => 1);
    
    # Try to load from cache first
    if (my $cached_analysis = $self->_load_from_cache($temporal_cache_key)) {
        $self->logger->info("Loaded temporal analysis from cache");
        return $cached_analysis;
    }
    
    $self->logger->info("Analyzing temporal patterns (cache miss)...");
    
    # Get temporal data from database
    my $temporal_data = $self->_get_temporal_data(%options);
    
    my $json_input = $self->json->encode($temporal_data);
    
    my $r_script = File::Spec->catfile($self->r_scripts_path, 'temporal_analysis.R');
    
    # Source the R script
    $self->r_instance->run(qq{source("$r_script")});
    
    # Call the R function
    $self->r_instance->set('json_input', $json_input);
    my $result = $self->r_instance->get('analyze_temporal_patterns(json_input)');
    
    # Parse R result
    my $temporal_analysis = eval { $self->json->decode($result) };
    if ($@) {
        $self->logger->error("Failed to parse temporal analysis result: $@");
        return {};
    }
    
    # Cache the results
    $self->_save_to_cache($temporal_cache_key, $temporal_analysis);
    
    return $temporal_analysis;
}

# Get temporal data for analysis
sub _get_temporal_data {
    my ($self, %options) = @_;
    
    my $dbh = $self->storage->dbh;
    
    # Get articles with timestamps
    my $articles_query = "
        SELECT id, title, url, summary, categories, 
               strftime('%Y-%m-%d', created_at) as created_at
        FROM articles 
        ORDER BY created_at
    ";
    
    my $articles = $dbh->selectall_arrayref($articles_query, { Slice => {} });
    
    # Get links with timestamps
    my $links_query = "
        SELECT from_article_id, to_article_id, relevance_score, anchor_text,
               strftime('%Y-%m-%d', created_at) as created_at
        FROM links 
        WHERE relevance_score >= ?
        ORDER BY created_at
    ";
    
    my $min_relevance = $options{min_relevance} || 0.3;
    my $links = $dbh->selectall_arrayref($links_query, { Slice => {} }, $min_relevance);
    
    # Convert to proper format for R analysis
    my @article_data = map {
        {
            id => $_->{id},
            title => $_->{title},
            created_at => $_->{created_at},
            categories => eval { $self->json->decode($_->{categories} || '[]') } || []
        }
    } @$articles;
    
    my @link_data = map {
        {
            from => $_->{from_article_id},
            to => $_->{to_article_id},
            weight => $_->{relevance_score},
            created_at => $_->{created_at}
        }
    } @$links;
    
    return {
        articles => \@article_data,
        links => \@link_data,
        metadata => {
            total_articles => scalar(@article_data),
            total_links => scalar(@link_data),
            min_relevance => $min_relevance,
            analysis_date => time()
        }
    };
}

# Get knowledge evolution insights for personal dashboard
sub get_knowledge_insights {
    my ($self, %options) = @_;
    
    # Generate cache key for insights
    my $insights_cache_key = $self->_generate_cache_key(%options, knowledge_insights => 1);
    
    # Try to load from cache first
    if (my $cached_insights = $self->_load_from_cache($insights_cache_key)) {
        $self->logger->info("Loaded knowledge insights from cache");
        return $cached_insights;
    }
    
    $self->logger->info("Generating knowledge insights (cache miss)...");
    
    # Get basic graph metrics
    my $graph = $self->build_graph(%options);
    my $temporal_analysis = $self->analyze_temporal_patterns(%options);
    
    # Combine insights
    my $insights = {
        # Current state
        current_state => {
            total_nodes => scalar(keys %{$graph->{nodes}}),
            total_edges => scalar(@{$graph->{edges}}),
            density => $graph->{metrics}->{density} || 0,
            average_degree => $graph->{metrics}->{average_degree} || 0,
        },
        
        # Growth patterns
        growth_patterns => $temporal_analysis->{growth_analysis} || {},
        
        # Discovery timeline
        discovery_timeline => $temporal_analysis->{discovery_timeline} || {},
        
        # Learning phases
        learning_phases => $temporal_analysis->{learning_phases} || {},
        
        # Personal knowledge metrics
        personal_metrics => $self->_calculate_personal_metrics($graph, $temporal_analysis),
        
        # Recommendations
        recommendations => $self->_generate_insights_recommendations($graph, $temporal_analysis),
    };
    
    # Cache the results
    $self->_save_to_cache($insights_cache_key, $insights);
    
    return $insights;
}

# Calculate personalized knowledge metrics
sub _calculate_personal_metrics {
    my ($self, $graph, $temporal_analysis) = @_;
    
    my $metrics = {};
    
    # Knowledge breadth (number of different topics/categories)
    my %categories;
    for my $node (values %{$graph->{nodes}}) {
        for my $category (@{$node->{categories} || []}) {
            $categories{$category} = 1;
        }
    }
    $metrics->{knowledge_breadth} = scalar(keys %categories);
    
    # Knowledge depth (average connections per topic)
    $metrics->{knowledge_depth} = $graph->{metrics}->{average_degree} || 0;
    
    # Learning velocity (recent discovery rate)
    if ($temporal_analysis->{growth_analysis}) {
        my $growth = $temporal_analysis->{growth_analysis};
        if ($growth->{articles_velocity}) {
            my @velocities = @{$growth->{articles_velocity}};
            $metrics->{learning_velocity} = @velocities > 5 ? 
                (sum(@velocities[-5..-1]) / 5) : (sum(@velocities) / @velocities);
        }
    }
    
    # Knowledge coherence (how well connected different areas are)
    $metrics->{knowledge_coherence} = $graph->{metrics}->{density} || 0;
    
    return $metrics;
}

# Generate personalized recommendations
sub _generate_insights_recommendations {
    my ($self, $graph, $temporal_analysis) = @_;
    
    my @recommendations;
    
    # Based on learning patterns
    if ($temporal_analysis->{learning_phases}) {
        my $phases = $temporal_analysis->{learning_phases};
        if ($phases->{phases}) {
            my $last_phase = $phases->{phases}->[-1];
            if ($last_phase->{activity_level} eq 'low') {
                push @recommendations, {
                    type => 'motivation',
                    title => 'Reignite Your Learning',
                    message => 'Your recent learning activity has been low. Consider exploring a new topic!',
                    action => 'start_new_crawl'
                };
            }
        }
    }
    
    # Based on graph structure
    my $density = $graph->{metrics}->{density} || 0;
    if ($density < 0.1) {
        push @recommendations, {
            type => 'structure',
            title => 'Connect Your Knowledge',
            message => 'Your knowledge graph has low connectivity. Look for links between different topics.',
            action => 'find_connections'
        };
    }
    
    # Based on knowledge breadth
    my %categories;
    for my $node (values %{$graph->{nodes}}) {
        for my $category (@{$node->{categories} || []}) {
            $categories{$category} = 1;
        }
    }
    
    if (keys %categories < 3) {
        push @recommendations, {
            type => 'exploration',
            title => 'Broaden Your Horizons',
            message => 'You\'ve focused on few topics. Try exploring different domains!',
            action => 'explore_categories'
        };
    }
    
    return \@recommendations;
}

# Test R integration
sub test_r_integration {
    my ($self) = @_;
    
    $self->logger->info("Testing R integration...");
    
    eval {
        # Test basic R functionality
        my $result = $self->r_instance->get('2 + 2');
        die "Basic R test failed" unless $result == 4;
        
        # Test required packages (they should already be loaded)
        $self->r_instance->run('packageVersion("igraph")');
        $self->r_instance->run('packageVersion("networkD3")');
        $self->r_instance->run('packageVersion("visNetwork")');
        $self->r_instance->run('packageVersion("jsonlite")');
        
        $self->logger->info("R integration test passed");
    };
    
    if ($@) {
        $self->logger->error("R integration test failed: $@");
        return 0;
    }
    
    return 1;
}

1;

__END__

=head1 NAME

WikiCrawler::KnowledgeGraph - Knowledge graph builder and analyzer

=head1 SYNOPSIS

    use WikiCrawler::KnowledgeGraph;
    
    my $kg = WikiCrawler::KnowledgeGraph->new(
        config => $config,
        storage => $storage
    );
    
    my $graph = $kg->build_graph(min_relevance => 0.5);
    my $path = $kg->find_shortest_path($graph, $start_id, $end_id);

=head1 DESCRIPTION

This module builds and analyzes knowledge graphs from crawled Wikipedia data.
It provides functionality for graph construction, analysis, export, and R-enhanced
statistical analysis including advanced centrality measures, community detection,
and sophisticated layout algorithms.

=head1 METHODS

=head2 build_graph(%options)

Builds a knowledge graph from stored articles and links.

Options:
- enhanced_analysis: Enable R-enhanced analysis (default: false)
- include_enhanced_metrics: Include R-calculated advanced metrics
- include_centrality: Include centrality measures (PageRank, betweenness, etc.)
- include_communities: Include community detection algorithms
- include_layouts: Include advanced layout algorithms
- include_clustering: Include cluster analysis

=head2 add_enhanced_analysis($graph, %options)

Adds R-enhanced statistical analysis to the graph including:
- Advanced centrality measures (PageRank, betweenness, eigenvector)
- Community detection (Louvain, Walktrap, Fast Greedy)
- Sophisticated layout algorithms
- Cluster analysis and motif detection

=head2 calculate_enhanced_metrics($graph)

Calculates enhanced graph metrics using R/igraph.

=head2 calculate_centrality_measures($graph)

Calculates multiple centrality measures including PageRank.

=head2 detect_communities($graph)

Detects communities using multiple algorithms.

=head2 calculate_advanced_layouts($graph)

Calculates multiple advanced layout algorithms.

=head2 generate_r_visualizations($graph, %options)

Generates interactive visualizations using networkD3 and visNetwork.

=head2 test_r_integration()

Tests R integration and required packages.

=head2 find_shortest_path($graph, $start_id, $end_id)

Finds the shortest path between two nodes in the graph.

=head2 export_graph($graph, $format, $filename)

Exports the graph to various formats (JSON, GraphML, DOT).

=head1 AUTHOR

WikiCrawler Project

=cut
