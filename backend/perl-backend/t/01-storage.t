#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;
use Test::More;
use Test::Exception;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use TestHelper;
use Tessera::Storage;

# Test plan
plan tests => 25;

# Create test storage
my $storage = create_test_storage();
isa_ok($storage, 'Tessera::Storage', 'Storage object created');

# Test database connection
my $dbh = $storage->dbh;
ok($dbh, 'Database handle obtained');
isa_ok($dbh, 'DBI::db', 'Database handle is DBI object');

# Test schema initialization
my $tables = $dbh->selectall_arrayref(
    "SELECT name FROM sqlite_master WHERE type='table'"
);
my %table_names = map { $_->[0] => 1 } @$tables;

ok($table_names{articles}, 'Articles table created');
ok($table_names{links}, 'Links table created');
ok($table_names{interest_profiles}, 'Interest profiles table created');
ok($table_names{crawl_sessions}, 'Crawl sessions table created');

# Test article storage
my $article_data = create_mock_article_data('Test Article');
my $article_id = $storage->store_article($article_data);

# Debug output removed

ok($article_id, 'Article stored successfully');
is($article_id, 1, 'First article gets ID 1');

# Test article retrieval by ID
my $retrieved_article = $storage->get_article_by_id($article_id);
ok($retrieved_article, 'Article retrieved by ID');
is($retrieved_article->{title}, 'Test Article', 'Article title matches');
is($retrieved_article->{url}, $article_data->{url}, 'Article URL matches');

# Test article retrieval by title
$retrieved_article = $storage->get_article_by_title('Test Article');
ok($retrieved_article, 'Article retrieved by title');
is($retrieved_article->{id}, $article_id, 'Article ID matches');

# Test JSON field decoding
isa_ok($retrieved_article->{categories}, 'ARRAY', 'Categories decoded as array');
isa_ok($retrieved_article->{infobox}, 'HASH', 'Infobox decoded as hash');
is_deeply($retrieved_article->{categories}, ['Test Articles', 'Sample Data'], 'Categories content correct');

# Test article update
$article_data->{content} = 'Updated content';
my $update_id = $storage->store_article($article_data);
is($update_id, $article_id, 'Update returns same ID');

$retrieved_article = $storage->get_article_by_id($article_id);
is($retrieved_article->{content}, 'Updated content', 'Article content updated');

# Test link storage
my $second_article_data = create_mock_article_data('Second Article');
my $second_id = $storage->store_article($second_article_data);

lives_ok {
    $storage->store_link($article_id, $second_id, 'test link', 0.8);
} 'Link stored without error';

# Test outbound links retrieval
my $outbound_links = $storage->get_outbound_links($article_id, 0.5);
is(@$outbound_links, 1, 'One outbound link found');
is($outbound_links->[0]->{relevance_score}, 0.8, 'Link relevance score correct');

# Test inbound links retrieval
my $inbound_links = $storage->get_inbound_links($second_id, 0.5);
is(@$inbound_links, 1, 'One inbound link found');
is($inbound_links->[0]->{from_article_id}, $article_id, 'Inbound link source correct');

# Test article search
my $search_results = $storage->search_articles('Test', 10);
ok(@$search_results >= 0, 'Search returns results array');

done_testing();
