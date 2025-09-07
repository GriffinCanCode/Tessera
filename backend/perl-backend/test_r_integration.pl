#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use lib 'lib';
use Tessera::KnowledgeGraph;
use Data::Dumper;
use Log::Log4perl;

# Initialize Log4perl for testing
Log::Log4perl->easy_init($Log::Log4perl::INFO);

# Mock configuration and storage for testing
my $mock_config = {};

# Create a simple mock storage
package MockStorage {
    sub new { bless {}, shift }
    sub dbh { return MockDBH->new }
}

package MockDBH {
    sub new { bless {}, shift }
    sub selectall_arrayref { 
        my ($self, $sql) = @_;
        
        # Return sample articles
        if ($sql =~ /SELECT.*FROM articles/) {
            return [
                { id => 1, title => "Machine Learning", url => "https://en.wikipedia.org/wiki/Machine_Learning", summary => "AI field focusing on algorithms" },
                { id => 2, title => "Artificial Intelligence", url => "https://en.wikipedia.org/wiki/Artificial_Intelligence", summary => "Computer science field" },
                { id => 3, title => "Neural Networks", url => "https://en.wikipedia.org/wiki/Neural_Networks", summary => "Computing systems inspired by biology" },
                { id => 4, title => "Deep Learning", url => "https://en.wikipedia.org/wiki/Deep_Learning", summary => "Machine learning with neural networks" }
            ];
        }
        
        # Return sample links
        if ($sql =~ /SELECT.*FROM links/) {
            return [
                { from_article_id => 1, to_article_id => 2, relevance_score => 0.8, anchor_text => "AI" },
                { from_article_id => 1, to_article_id => 3, relevance_score => 0.9, anchor_text => "neural networks" },
                { from_article_id => 3, to_article_id => 4, relevance_score => 0.85, anchor_text => "deep learning" },
                { from_article_id => 2, to_article_id => 4, relevance_score => 0.7, anchor_text => "advanced AI" }
            ];
        }
        
        return [];
    }
    
    sub selectrow_array { 
        my ($self, $sql, $attrs, $article_id) = @_;
        return int(rand(10) + 1); # Random count for links
    }
}

# Main test
say "Testing R Integration for Tessera Knowledge Graph";
say "=" x 50;

# Create knowledge graph instance
my $kg = Tessera::KnowledgeGraph->new(
    config  => $mock_config,
    storage => MockStorage->new
);

say "✓ Created KnowledgeGraph instance";

# Test R integration
say "\nTesting basic R integration...";
if ($kg->test_r_integration) {
    say "✓ R integration test passed";
} else {
    say "✗ R integration test failed";
    exit 1;
}

# Build basic graph
say "\nBuilding basic knowledge graph...";
my $basic_graph = $kg->build_graph(
    min_relevance => 0.5,
    max_depth => 2
);

say sprintf("✓ Built basic graph with %d nodes and %d edges", 
    scalar(keys %{$basic_graph->{nodes}}), 
    scalar(@{$basic_graph->{edges}})
);

# Test R-enhanced analysis
say "\nTesting R-enhanced analysis...";
my $enhanced_graph = $kg->build_graph(
    min_relevance => 0.5,
    max_depth => 2,
    enhanced_analysis => 1,
    include_enhanced_metrics => 1,
    include_centrality => 1,
    include_communities => 1,
    include_layouts => 1,
    include_clustering => 1
);

if ($enhanced_graph->{r_analysis_error}) {
    say "✗ R-enhanced analysis failed: " . $enhanced_graph->{r_analysis_error};
} else {
    say "✓ R-enhanced analysis completed successfully";
    
    # Show enhanced features
    if ($enhanced_graph->{enhanced_metrics}) {
        say "  ✓ Enhanced metrics calculated";
    }
    
    if ($enhanced_graph->{centrality_measures}) {
        say "  ✓ Centrality measures calculated";
        my $centrality = $enhanced_graph->{centrality_measures};
        if ($centrality->{pagerank}) {
            say "    - PageRank scores available";
        }
        if ($centrality->{betweenness}) {
            say "    - Betweenness centrality calculated";
        }
    }
    
    if ($enhanced_graph->{communities}) {
        say "  ✓ Community detection completed";
        for my $method (keys %{$enhanced_graph->{communities}}) {
            my $comm_data = $enhanced_graph->{communities}{$method};
            say "    - $method: " . ($comm_data->{communities_count} // 0) . " communities";
        }
    }
    
    if ($enhanced_graph->{advanced_layouts}) {
        say "  ✓ Advanced layouts calculated";
        my $layouts = $enhanced_graph->{advanced_layouts}{layouts} // {};
        for my $layout_name (keys %$layouts) {
            say "    - $layout_name layout available";
        }
    }
    
    if ($enhanced_graph->{cluster_analysis}) {
        say "  ✓ Cluster analysis completed";
    }
}

# Test specific R functions
say "\nTesting individual R functions...";

# Test enhanced metrics
eval {
    my $metrics = $kg->calculate_enhanced_metrics($basic_graph);
    say "✓ Enhanced metrics calculation successful";
};
if ($@) {
    say "✗ Enhanced metrics failed: $@";
}

# Test centrality measures  
eval {
    my $centrality = $kg->calculate_centrality_measures($basic_graph);
    say "✓ Centrality measures calculation successful";
};
if ($@) {
    say "✗ Centrality measures failed: $@";
}

# Test community detection
eval {
    my $communities = $kg->detect_communities($basic_graph);
    say "✓ Community detection successful";
};
if ($@) {
    say "✗ Community detection failed: $@";
}

# Test advanced layouts
eval {
    my $layouts = $kg->calculate_advanced_layouts($basic_graph);
    say "✓ Advanced layouts calculation successful";
};
if ($@) {
    say "✗ Advanced layouts failed: $@";
}

say "\n" . "=" x 50;
say "R Integration Test Complete!";

# Optional: Generate visualizations
say "\nGenerating R-based visualizations...";
eval {
    my $vis_files = $kg->generate_r_visualizations($basic_graph);
    say "✓ R visualizations generated:";
    for my $type (keys %$vis_files) {
        say "  - $type: $vis_files->{$type}";
    }
};
if ($@) {
    say "✗ Visualization generation failed: $@";
}

say "\nAll tests completed!";
