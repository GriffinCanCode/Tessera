#!/usr/bin/env perl

# Quick demo of WikiCrawler capabilities
# This is a minimal working example

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";

use WikiCrawler;

print "=== WikiCrawler Quick Demo ===\n\n";

# Initialize
my $crawler = WikiCrawler->new(config_file => "$FindBin::Bin/../config/crawler.yaml");

# Set interests focused on programming/technology
$crawler->interests(['programming', 'computer science', 'algorithms']);

print "1. Starting mini-crawl from Perl programming language...\n";

# Small test crawl
eval {
    my $stats = $crawler->crawl(
        start_url => 'https://en.wikipedia.org/wiki/Perl',
        max_depth => 1,          # Only follow links one level deep
        max_articles => 3,       # Just crawl 3 articles for demo
        interests => ['programming', 'computer science'],
    );
    
    printf "✓ Crawled %d articles in %.1f seconds\n\n", 
           $stats->{articles_crawled}, $stats->{duration};
    
} or do {
    print "Error: $@\n";
    exit 1;
};

print "2. Database contents:\n";
my $db_stats = $crawler->get_stats();
printf "   Articles: %d\n", $db_stats->{total_articles};
printf "   Links: %d\n\n", $db_stats->{total_links};

print "3. Searching for 'programming':\n";
my $results = $crawler->search('programming', limit => 5);
for my $result (@$results) {
    print "   - $result->{title}\n";
}

print "\n4. Building knowledge graph:\n";
my $graph = $crawler->build_knowledge_graph(min_relevance => 0.1);
printf "   Nodes: %d, Edges: %d\n\n", 
       scalar(keys %{$graph->{nodes}}), scalar(@{$graph->{edges}});

print "5. Sample API server test:\n";
print "   Run: perl script/api_server.pl\n";
print "   Visit: http://localhost:3000\n\n";

print "Demo completed! ✓\n";
print "Try: ./bin/wikicrawler --start-title 'Your Interest' --max-articles 10\n";
