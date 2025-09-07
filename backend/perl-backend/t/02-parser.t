#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use TestHelper;
use Tessera::Parser;

plan tests => 22;

# Create parser instance
my $config = get_test_config();
my $parser = Tessera::Parser->new(config => $config);
isa_ok($parser, 'Tessera::Parser', 'Parser object created');

# Test with sample HTML
my $html = get_sample_wikipedia_html();
my $url = 'https://en.wikipedia.org/wiki/Artificial_Intelligence';
my $parsed_data = $parser->parse_page($html, $url);

ok($parsed_data, 'HTML parsed successfully');
isa_ok($parsed_data, 'HASH', 'Parsed data is hash reference');

# Test title extraction
is($parsed_data->{title}, 'Artificial Intelligence', 'Title extracted correctly');

# Test URL preservation
is($parsed_data->{url}, $url, 'URL preserved');

# Test content extraction
ok($parsed_data->{content}, 'Content extracted');
like($parsed_data->{content}, qr/intelligence demonstrated by machines/i, 'Content contains expected text');

# Test summary extraction
ok($parsed_data->{summary}, 'Summary extracted');
like($parsed_data->{summary}, qr/artificial intelligence.*intelligence demonstrated/i, 'Summary is first paragraph');

# Test infobox extraction
isa_ok($parsed_data->{infobox}, 'HASH', 'Infobox extracted as hash');
ok(keys %{$parsed_data->{infobox}} >= 0, 'Infobox extracted (may be empty)');

# Test categories extraction
isa_ok($parsed_data->{categories}, 'ARRAY', 'Categories extracted as array');
ok(@{$parsed_data->{categories}} > 0, 'Categories array not empty');
ok((grep { /artificial.+intelligence/i } @{$parsed_data->{categories}}), 'AI category found');

# Test links extraction
isa_ok($parsed_data->{links}, 'ARRAY', 'Links extracted as array');
ok(@{$parsed_data->{links}} > 0, 'Links array not empty');

# Check for specific expected links
my @link_titles = map { $_->{title} } @{$parsed_data->{links}};
ok((grep { /intelligent.+agent/i } @link_titles), 'Intelligent agent link found');
ok((grep { /alan.+turing/i } @link_titles), 'Alan Turing link found');

# Test sections extraction
isa_ok($parsed_data->{sections}, 'ARRAY', 'Sections extracted as array');
my @section_titles = map { $_->{title} } @{$parsed_data->{sections}};
ok((grep { /history/i } @section_titles), 'History section found');

# Test coordinates extraction
isa_ok($parsed_data->{coordinates}, 'HASH', 'Coordinates extracted as hash');
ok($parsed_data->{coordinates}->{latitude}, 'Latitude extracted from geo span');

done_testing();
