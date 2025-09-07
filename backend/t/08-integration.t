#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use TestHelper;
use WikiCrawler;

plan tests => 17;

# Integration test for the complete workflow
my $test_config_file = "$FindBin::Bin/test_config.yaml";
my $wikicrawler = WikiCrawler->new(config_file => $test_config_file);

# Create and store some test articles for integration testing
my $storage = $wikicrawler->storage;

# Article 1: Computer Science
my $cs_article = create_mock_article_data(
    'Computer Science',
    content => 'Computer science is the study of algorithms, data structures, and artificial intelligence.',
    categories => ['Computer Science', 'Technology'],
    coordinates => {}
);

# Article 2: Artificial Intelligence  
my $ai_article = create_mock_article_data(
    'Artificial Intelligence',
    content => 'Artificial intelligence is a branch of computer science dealing with machine learning.',
    categories => ['Computer Science', 'Artificial Intelligence'],
    coordinates => {}
);

# Article 3: Machine Learning
my $ml_article = create_mock_article_data(
    'Machine Learning', 
    content => 'Machine learning is a subset of artificial intelligence focused on algorithms.',
    categories => ['Computer Science', 'Machine Learning'],
    coordinates => {}
);

# Store articles
my $cs_id = $storage->store_article($cs_article);
my $ai_id = $storage->store_article($ai_article);
my $ml_id = $storage->store_article($ml_article);

ok($cs_id && $ai_id && $ml_id, 'Test articles stored successfully');

# Create links between articles
$storage->store_link($cs_id, $ai_id, 'artificial intelligence', 0.9);
$storage->store_link($ai_id, $ml_id, 'machine learning', 0.8);
$storage->store_link($cs_id, $ml_id, 'algorithms', 0.7);

# Test link storage worked
my $cs_links = $storage->get_outbound_links($cs_id, 0.5);
is(@$cs_links, 2, 'Computer Science article has 2 outbound links');

# Test search functionality
my $search_results = $wikicrawler->search('computer', 10);
ok(@$search_results > 0, 'Search finds relevant articles');
ok((grep { $_->{title} eq 'Computer Science' } @$search_results), 'Computer Science found in search');

# Test article retrieval
my $retrieved_ai = $wikicrawler->get_article('Artificial Intelligence');
ok($retrieved_ai, 'AI article retrieved successfully');
is($retrieved_ai->{title}, 'Artificial Intelligence', 'Retrieved article has correct title');

# Set interests for link analysis
$wikicrawler->interests(['computer science', 'artificial intelligence']);
is_deeply($wikicrawler->interests, ['computer science', 'artificial intelligence'], 'Interests set for integration test');

# Test knowledge graph building with stored data
my $graph = $wikicrawler->build_knowledge_graph(min_relevance => 0.6);
ok($graph->{nodes}, 'Knowledge graph built with nodes');
ok($graph->{edges}, 'Knowledge graph built with edges');
is(scalar(keys %{$graph->{nodes}}), 3, 'All 3 articles included as nodes');
is(scalar(@{$graph->{edges}}), 3, 'All 3 high-relevance links included as edges');

# Test graph metrics
ok($graph->{metrics}, 'Graph metrics calculated');
is($graph->{metrics}{node_count}, 3, 'Metrics show correct node count');
ok($graph->{metrics}{avg_out_degree} > 0, 'Average out-degree calculated');

# Test graph export
my $json_export = $wikicrawler->export_graph('json', undef, min_relevance => 0.6);
ok($json_export, 'Graph exported to JSON');
like($json_export, qr/"nodes"/, 'JSON export contains nodes');

# Test database statistics
my $stats = $wikicrawler->get_stats();
is($stats->{total_articles}, 3, 'Statistics show correct article count');

done_testing();
