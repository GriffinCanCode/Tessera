#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../t/lib";

use Benchmark qw(:all);
use Test::More;
use TestHelper;
use Tessera::KnowledgeGraph;
use Tessera::Storage;
use YAML::XS qw(LoadFile);
use Time::HiRes qw(time);
use Statistics::Descriptive;

# Load test configuration
my $config_file = "$FindBin::Bin/../t/test_config.yaml";
my $config = LoadFile($config_file);

# Initialize test storage with sample data
my $storage = Tessera::Storage->new(config => $config);
$storage->initialize_database();

# Create test helper for generating sample data
my $helper = TestHelper->new();

# Generate benchmark datasets of different sizes
my %datasets = (
    small => {
        articles => 50,
        links_per_article => 10,
        description => "Small dataset (50 articles, ~500 links)"
    },
    medium => {
        articles => 200,
        links_per_article => 15,
        description => "Medium dataset (200 articles, ~3000 links)"
    },
    large => {
        articles => 500,
        links_per_article => 20,
        description => "Large dataset (500 articles, ~10000 links)"
    }
);

print "=== Tessera KnowledgeGraph Benchmarks ===\n\n";

# Initialize KnowledgeGraph
my $kg = Tessera::KnowledgeGraph->new(
    config => $config,
    storage => $storage
);

# Test R integration first
print "Testing R integration...\n";
if ($kg->test_r_integration()) {
    print "✓ R integration working\n\n";
} else {
    print "⚠ R integration failed - some benchmarks may be skipped\n\n";
}

# Run benchmarks for each dataset size
for my $dataset_name (sort keys %datasets) {
    my $dataset = $datasets{$dataset_name};
    
    print "=== $dataset->{description} ===\n";
    
    # Setup test data
    setup_test_data($storage, $helper, $dataset);
    
    # Benchmark 1: Basic graph building
    print "\n1. Graph Building Performance:\n";
    benchmark_graph_building($kg, $dataset_name);
    
    # Benchmark 2: Graph metrics calculation
    print "\n2. Graph Metrics Calculation:\n";
    benchmark_graph_metrics($kg, $dataset_name);
    
    # Benchmark 3: Centrality measures (if R is available)
    print "\n3. Centrality Measures (R-enhanced):\n";
    benchmark_centrality_measures($kg, $dataset_name);
    
    # Benchmark 4: Community detection
    print "\n4. Community Detection:\n";
    benchmark_community_detection($kg, $dataset_name);
    
    # Benchmark 5: Path finding algorithms
    print "\n5. Path Finding Algorithms:\n";
    benchmark_path_finding($kg, $dataset_name);
    
    # Benchmark 6: Cache performance
    print "\n6. Cache Performance:\n";
    benchmark_cache_performance($kg, $dataset_name);
    
    print "\n" . "="x60 . "\n\n";
    
    # Clear data for next dataset
    $storage->clear_all_data();
}

print "Benchmark suite completed!\n";

# Benchmark functions

sub setup_test_data {
    my ($storage, $helper, $dataset) = @_;
    
    print "Setting up test data...\n";
    
    my $start_time = time();
    
    # Generate articles
    for my $i (1..$dataset->{articles}) {
        my $article = $helper->create_sample_article(
            id => $i,
            title => "Test Article $i",
            content => $helper->generate_sample_content(500 + int(rand(1000))),
            categories => $helper->generate_sample_categories(3 + int(rand(5)))
        );
        $storage->store_article($article);
    }
    
    # Generate links between articles
    my $total_links = 0;
    for my $from_id (1..$dataset->{articles}) {
        my $num_links = $dataset->{links_per_article} + int(rand(10)) - 5;
        $num_links = 1 if $num_links < 1;
        
        for my $link_num (1..$num_links) {
            my $to_id = 1 + int(rand($dataset->{articles}));
            next if $to_id == $from_id; # Skip self-links
            
            my $relevance = 0.3 + rand(0.7); # Random relevance 0.3-1.0
            
            $storage->store_link({
                from_article_id => $from_id,
                to_article_id => $to_id,
                relevance_score => $relevance,
                anchor_text => "Link to Article $to_id"
            });
            $total_links++;
        }
    }
    
    my $setup_time = time() - $start_time;
    printf "Setup completed: %d articles, %d links (%.2fs)\n", 
           $dataset->{articles}, $total_links, $setup_time;
}

sub benchmark_graph_building {
    my ($kg, $dataset_name) = @_;
    
    my $results = timethese(-3, {
        'complete_graph' => sub {
            my $graph = $kg->build_graph(min_relevance => 0.3);
        },
        'centered_graph' => sub {
            my $center_id = 1 + int(rand(50)); # Random center
            my $graph = $kg->build_graph(
                center_article_id => $center_id,
                max_depth => 3,
                min_relevance => 0.3
            );
        },
        'high_relevance' => sub {
            my $graph = $kg->build_graph(min_relevance => 0.7);
        }
    });
    
    print_benchmark_results($results, "Graph Building");
}

sub benchmark_graph_metrics {
    my ($kg, $dataset_name) = @_;
    
    # Build a graph once for metrics testing
    my $graph = $kg->build_graph(min_relevance => 0.3);
    
    my $results = timethese(-3, {
        'basic_metrics' => sub {
            my $metrics = $kg->_calculate_graph_metrics($graph);
        },
        'node_importance' => sub {
            for my $node_id (keys %{$graph->{nodes}}) {
                my $importance = $kg->_calculate_node_importance($node_id);
                last if keys %{$graph->{nodes}} > 20; # Limit for benchmarking
            }
        },
        'connected_components' => sub {
            my $components = $kg->_count_connected_components(
                $graph->{nodes}, 
                $graph->{edges}
            );
        }
    });
    
    print_benchmark_results($results, "Graph Metrics");
}

sub benchmark_centrality_measures {
    my ($kg, $dataset_name) = @_;
    
    # Skip if R integration is not working
    unless ($kg->test_r_integration()) {
        print "Skipped (R integration not available)\n";
        return;
    }
    
    my $graph = $kg->build_graph(min_relevance => 0.4);
    
    my $results = timethese(-2, { # Fewer iterations for R operations
        'pagerank_calculation' => sub {
            my $centrality = $kg->calculate_centrality_measures($graph);
        },
        'enhanced_metrics' => sub {
            my $enhanced = $kg->calculate_enhanced_metrics($graph);
        }
    });
    
    print_benchmark_results($results, "Centrality Measures");
}

sub benchmark_community_detection {
    my ($kg, $dataset_name) = @_;
    
    unless ($kg->test_r_integration()) {
        print "Skipped (R integration not available)\n";
        return;
    }
    
    my $graph = $kg->build_graph(min_relevance => 0.4);
    
    my $results = timethese(-2, {
        'community_detection' => sub {
            my $communities = $kg->detect_communities($graph);
        }
    });
    
    print_benchmark_results($results, "Community Detection");
}

sub benchmark_path_finding {
    my ($kg, $dataset_name) = @_;
    
    my $graph = $kg->build_graph(min_relevance => 0.3);
    my @node_ids = keys %{$graph->{nodes}};
    
    return unless @node_ids >= 2;
    
    my $results = timethese(-3, {
        'shortest_path' => sub {
            my $start = $node_ids[int(rand(@node_ids))];
            my $end = $node_ids[int(rand(@node_ids))];
            my $path = $kg->find_shortest_path($graph, $start, $end);
        },
        'get_neighbors' => sub {
            my $center = $node_ids[int(rand(@node_ids))];
            my $neighbors = $kg->get_neighbors($graph, $center, 2);
        }
    });
    
    print_benchmark_results($results, "Path Finding");
}

sub benchmark_cache_performance {
    my ($kg, $dataset_name) = @_;
    
    # Clear cache first
    $kg->invalidate_cache();
    
    my $results = timethese(-3, {
        'cache_miss' => sub {
            $kg->invalidate_cache();
            my $graph = $kg->build_graph(min_relevance => 0.3);
        },
        'cache_hit' => sub {
            # This should hit cache after first run
            my $graph = $kg->build_graph(min_relevance => 0.3);
        }
    });
    
    print_benchmark_results($results, "Cache Performance");
}

sub print_benchmark_results {
    my ($results, $category) = @_;
    
    print "\n$category Results:\n";
    print "-" x 50 . "\n";
    
    for my $test_name (sort keys %$results) {
        my $result = $results->{$test_name};
        my $rate = $result->iters / $result->cpu_a;
        my $time_per_op = $result->cpu_a / $result->iters;
        
        printf "%-20s: %6.2f ops/sec (%.4fs per op)\n", 
               $test_name, $rate, $time_per_op;
    }
}

# Memory usage tracking
sub get_memory_usage {
    my $pid = $$;
    if (-f "/proc/$pid/status") {
        open my $fh, '<', "/proc/$pid/status" or return 0;
        while (my $line = <$fh>) {
            if ($line =~ /^VmRSS:\s+(\d+)\s+kB/) {
                return $1 * 1024; # Convert to bytes
            }
        }
    }
    return 0;
}

# Performance profiling helper
sub profile_operation {
    my ($name, $operation) = @_;
    
    my $start_time = time();
    my $start_memory = get_memory_usage();
    
    my $result = $operation->();
    
    my $end_time = time();
    my $end_memory = get_memory_usage();
    
    my $duration = $end_time - $start_time;
    my $memory_delta = $end_memory - $start_memory;
    
    printf "%s: %.4fs, Memory: %+.2fMB\n", 
           $name, $duration, $memory_delta / (1024*1024);
    
    return $result;
}

1;

__END__

=head1 NAME

01-knowledgegraph-bench.pl - Benchmark suite for Tessera::KnowledgeGraph

=head1 DESCRIPTION

This benchmark suite tests the performance of various KnowledgeGraph operations:

- Graph building (complete and centered)
- Graph metrics calculation
- R-enhanced centrality measures
- Community detection algorithms
- Path finding algorithms
- Cache performance

=head1 USAGE

    cd backend/perl-backend
    perl benchmarks/01-knowledgegraph-bench.pl

=head1 BENCHMARKS

=head2 Graph Building

Tests performance of building knowledge graphs with different parameters:
- Complete graph construction
- Centered graph construction
- High relevance filtering

=head2 Graph Metrics

Tests calculation of various graph metrics:
- Basic metrics (density, degree distribution)
- Node importance calculation
- Connected components analysis

=head2 Centrality Measures

Tests R-enhanced centrality calculations:
- PageRank calculation
- Enhanced metrics computation

=head2 Community Detection

Tests community detection algorithms using R/igraph.

=head2 Path Finding

Tests graph traversal algorithms:
- Shortest path finding
- Neighbor discovery

=head2 Cache Performance

Tests caching effectiveness:
- Cache miss performance
- Cache hit performance

=head1 AUTHOR

Tessera Project

=cut
