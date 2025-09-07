#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use TestHelper;
use Tessera::LinkAnalyzer;

plan tests => 19;

# Create link analyzer instance
my $config = get_test_config();
my $analyzer = Tessera::LinkAnalyzer->new(config => $config);
isa_ok($analyzer, 'Tessera::LinkAnalyzer', 'LinkAnalyzer object created');

# Test initial configuration
is_deeply($analyzer->interests, ['test topic', 'sample interest'], 'Initial interests set from config');
is($analyzer->min_relevance, 0.2, 'Min relevance set from config');

# Test interest setting
$analyzer->set_interests(['artificial intelligence', 'machine learning']);
is_deeply($analyzer->interests, ['artificial intelligence', 'machine learning'], 'Interests updated');

# Create test links
my $links = [
    {
        title => 'Artificial Intelligence',
        url => 'https://en.wikipedia.org/wiki/Artificial_Intelligence',
        anchor_text => 'artificial intelligence',
    },
    {
        title => 'Machine Learning',
        url => 'https://en.wikipedia.org/wiki/Machine_Learning',
        anchor_text => 'machine learning',
    },
    {
        title => 'Random Topic',
        url => 'https://en.wikipedia.org/wiki/Random_Topic',
        anchor_text => 'random topic',
    },
];

# Create mock source article
my $source_article = create_mock_article_data(
    'AI Research',
    content => 'This article discusses artificial intelligence and machine learning research.',
    categories => ['Computer Science', 'Artificial Intelligence']
);

# Test link analysis
my $analyzed_links = $analyzer->analyze_links($links, $source_article);
isa_ok($analyzed_links, 'ARRAY', 'Analyzed links returned as array');

# Check that relevant links are found
ok(@$analyzed_links > 0, 'Some links found to be relevant');

# Check relevance scores
for my $link (@$analyzed_links) {
    ok($link->{relevance_score}, 'Link has relevance score');
    ok($link->{relevance_score} >= $analyzer->min_relevance, 'Link meets minimum relevance threshold');
}

# Test individual relevance calculation
my $test_link = {
    title => 'Artificial Intelligence',
    anchor_text => 'AI',
};

my $relevance = $analyzer->calculate_relevance($test_link, $source_article);
ok($relevance > 0, 'Relevance calculated for matching link');
ok($relevance <= 1.0, 'Relevance score within bounds');

# Test with non-matching link
my $non_matching_link = {
    title => 'Cooking Recipes',
    anchor_text => 'recipes',
};

my $low_relevance = $analyzer->calculate_relevance($non_matching_link, $source_article);
ok($low_relevance < $relevance, 'Non-matching link has lower relevance');

# Test boost keywords
$analyzer->add_boost_keywords(['algorithm', 'neural']);
ok(grep { $_ eq 'algorithm' } @{$analyzer->boost_keywords}, 'Boost keyword added');

# Test link filtering
my $all_links = [
    { title => 'High Relevance', relevance_score => 0.9 },
    { title => 'Medium Relevance', relevance_score => 0.6 },
    { title => 'Low Relevance', relevance_score => 0.1 },
];

my $filtered = $analyzer->filter_links($all_links, min_relevance => 0.5);
is(@$filtered, 2, 'Filtering by min relevance works');

$filtered = $analyzer->filter_links($all_links, max_count => 2);
is(@$filtered, 2, 'Filtering by max count works');

# Test deduplication
my $duplicate_links = [
    { title => 'Same Title', relevance_score => 0.8 },
    { title => 'Same Title', relevance_score => 0.7 },
    { title => 'Different Title', relevance_score => 0.6 },
];

my $deduplicated = $analyzer->filter_links($duplicate_links, deduplicate => 1);
is(@$deduplicated, 2, 'Deduplication works');

# Test recommendations
my $candidate_links = create_mock_links();
my $recommendations = $analyzer->get_recommendations($source_article, $candidate_links, limit => 2);
isa_ok($recommendations, 'ARRAY', 'Recommendations returned as array');
ok(@$recommendations <= 2, 'Recommendation limit respected');

done_testing();
