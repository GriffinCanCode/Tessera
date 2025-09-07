#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use TestHelper;
use WikiCrawler::KnowledgeGraph;

plan tests => 19;

# Create test storage with data
my $storage = create_test_storage();

# Add test articles
my $article1_data = create_mock_article_data('Article One');
my $article2_data = create_mock_article_data('Article Two');
my $article3_data = create_mock_article_data('Article Three');

my $article1_id = $storage->store_article($article1_data);
my $article2_id = $storage->store_article($article2_data);
my $article3_id = $storage->store_article($article3_data);

# Add test links
$storage->store_link($article1_id, $article2_id, 'link to two', 0.8);
$storage->store_link($article2_id, $article3_id, 'link to three', 0.6);
$storage->store_link($article1_id, $article3_id, 'link to three', 0.4);

# Create knowledge graph instance
my $config = get_test_config();
my $kg = WikiCrawler::KnowledgeGraph->new(config => $config, storage => $storage);
isa_ok($kg, 'WikiCrawler::KnowledgeGraph', 'KnowledgeGraph object created');

# Test complete graph building
my $graph = $kg->build_graph(min_relevance => 0.3);
isa_ok($graph, 'HASH', 'Graph returned as hash');

# Test graph structure
ok($graph->{nodes}, 'Graph has nodes');
ok($graph->{edges}, 'Graph has edges');
ok($graph->{metadata}, 'Graph has metadata');
ok($graph->{metrics}, 'Graph has metrics');

isa_ok($graph->{nodes}, 'HASH', 'Nodes is hash reference');
isa_ok($graph->{edges}, 'ARRAY', 'Edges is array reference');

# Test node count
is(scalar(keys %{$graph->{nodes}}), 3, 'All articles included as nodes');

# Test edge count (edges with relevance >= 0.3)
is(scalar(@{$graph->{edges}}), 3, 'All links included as edges');

# Test node structure
my $node = $graph->{nodes}{$article1_id};
ok($node, 'Node exists for article 1');
is($node->{title}, 'Article One', 'Node title correct');
ok(defined $node->{importance}, 'Node importance calculated');
ok($node->{node_type}, 'Node type assigned');

# Test centered graph
my $centered_graph = $kg->build_graph(
    center_article_id => $article1_id,
    max_depth => 2,
    min_relevance => 0.3
);

ok($centered_graph->{nodes}, 'Centered graph has nodes');
is($centered_graph->{metadata}{center_article_id}, $article1_id, 'Center article ID recorded');

# Test shortest path finding
my $path = $kg->find_shortest_path($graph, $article1_id, $article3_id);
isa_ok($path, 'ARRAY', 'Path returned as array');
ok(@$path >= 2, 'Path has at least 2 nodes (start and end)');

# Test neighbors finding
my $neighbors = $kg->get_neighbors($graph, $article1_id, 1);
isa_ok($neighbors, 'HASH', 'Neighbors returned as hash');

done_testing();
