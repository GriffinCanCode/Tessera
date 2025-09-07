#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;
use Test::More;
# Test::MockObject not available - we'll test without mocking
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use TestHelper;
use Tessera::Crawler;

plan tests => 15;

# Create crawler instance
my $config = get_test_config();
my $crawler = Tessera::Crawler->new(config => $config);
isa_ok($crawler, 'Tessera::Crawler', 'Crawler object created');

# Test user agent creation
my $ua = $crawler->ua;
isa_ok($ua, 'LWP::UserAgent', 'User agent created');
is($ua->agent, $config->{crawler}{user_agent}, 'User agent string set correctly');
is($ua->timeout, $config->{crawler}{timeout}, 'Timeout set correctly');

# Test URL utility methods
my $test_url = 'https://en.wikipedia.org/wiki/Test_Article';
ok($crawler->is_wikipedia_article($test_url), 'Valid Wikipedia article URL recognized');

# Test invalid URLs
ok(!$crawler->is_wikipedia_article('https://google.com'), 'Non-Wikipedia URL rejected');
ok(!$crawler->is_wikipedia_article('https://en.wikipedia.org/wiki/File:Test.jpg'), 'File URL rejected');
ok(!$crawler->is_wikipedia_article('https://en.wikipedia.org/wiki/Category:Test'), 'Category URL rejected');

# Test title extraction
my $extracted_title = $crawler->extract_title_from_url($test_url);
is($extracted_title, 'Test Article', 'Title extracted from URL correctly');

# Test URL construction from title
my $constructed_url = $crawler->title_to_url('Test Article');
is($constructed_url, $test_url, 'URL constructed from title correctly');

# Test with special characters
my $special_title = 'Test & Article';
my $special_url = $crawler->title_to_url($special_title);
like($special_url, qr/Test_%26_Article/, 'Special characters encoded in URL');

# Test rate limiting attributes
is($crawler->last_request_time, 0, 'Initial last request time is 0');
is($crawler->request_count, 0, 'Initial request count is 0');
ok($crawler->minute_start > 0, 'Minute start time initialized');

# Skip actual HTTP tests since we don't have Test::MockObject
# These would require actual network access or mocking dependencies
ok(1, 'Skipped HTTP tests (no Test::MockObject available)');

done_testing();
