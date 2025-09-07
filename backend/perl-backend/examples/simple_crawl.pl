#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Tessera;

# Simple example of using Tessera
print "Tessera Example\n";
print "==================\n";

# Initialize crawler
my $crawler = Tessera->new(
    config_file => "$FindBin::Bin/../config/crawler.yaml"
);

# Set interests
my @interests = ('artificial intelligence', 'machine learning', 'programming');
$crawler->interests(\@interests);

print "Interests set: " . join(", ", @interests) . "\n";

# Start with a simple crawl
print "Starting small test crawl...\n";

eval {
    my $stats = $crawler->crawl(
        start_url => 'https://en.wikipedia.org/wiki/Perl',
        max_depth => 1,
        max_articles => 5,
        interests => \@interests,
    );
    
    print "Crawl completed successfully!\n";
    print "Articles crawled: $stats->{articles_crawled}\n";
    print "Articles processed: $stats->{articles_processed}\n";
    print "Duration: " . sprintf("%.1f", $stats->{duration} || 0) . " seconds\n";
    
    # Show stats
    my $db_stats = $crawler->get_stats();
    print "\nDatabase stats:\n";
    print "Total articles: $db_stats->{total_articles}\n";
    print "Total links: $db_stats->{total_links}\n";
    
    # Try searching
    print "\nSearching for 'perl':\n";
    my $results = $crawler->search('perl', limit => 3);
    for my $result (@$results) {
        print "- $result->{title}\n";
    }
    
    # Build simple graph
    print "\nBuilding knowledge graph...\n";
    my $graph = $crawler->build_knowledge_graph(min_relevance => 0.1);
    print "Graph nodes: " . scalar(keys %{$graph->{nodes}}) . "\n";
    print "Graph edges: " . scalar(@{$graph->{edges}}) . "\n";
    
    print "\nExample completed successfully!\n";
    
} or do {
    print "Error during crawling: $@\n";
    
    # Check if it's a missing dependency issue
    if ($@ =~ /Can't locate (\S+)/) {
        print "Missing module: $1\n";
        print "Try running: cpanm --installdeps .\n";
    }
};
