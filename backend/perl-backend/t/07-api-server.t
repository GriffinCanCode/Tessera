#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use TestHelper;

plan tests => 8;

# Test that we can load the API server script without Test::Mojo
ok(-f "$FindBin::Bin/../script/api_server.pl", 'API server script exists');

# Test that we can create Tessera instance (needed by API)
my $config_file = "$FindBin::Bin/test_config.yaml";
$ENV{TESSERA_CONFIG} = $config_file;

require Tessera;
my $wiki_crawler = Tessera->new(config_file => $config_file);
isa_ok($wiki_crawler, 'Tessera', 'Tessera instance for API');

# Test API-related functionality that doesn't require HTTP server
my $stats = $wiki_crawler->get_stats();
isa_ok($stats, 'HASH', 'API stats endpoint data structure');
ok(exists $stats->{total_articles}, 'Stats contains total_articles');
ok(exists $stats->{total_links}, 'Stats contains total_links');

# Test search functionality used by API
my $search_results = $wiki_crawler->search('test');
isa_ok($search_results, 'ARRAY', 'API search endpoint returns array');

# Test knowledge graph functionality used by API
my $graph = $wiki_crawler->build_knowledge_graph(min_relevance => 0.3);
isa_ok($graph, 'HASH', 'API graph endpoint returns data structure');

# Test that the API server script exists and is syntactically correct
# We can't load it directly because it starts the server
my $api_script = "$FindBin::Bin/../script/api_server.pl";
my $syntax_check = `perl -c $api_script 2>&1`;
ok($syntax_check =~ /syntax OK/, 'API server script has valid syntax');

done_testing();
