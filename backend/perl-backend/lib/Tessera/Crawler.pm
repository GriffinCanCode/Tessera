package Tessera::Crawler;

use strict;
use warnings;
use v5.20;

use LWP::UserAgent;
use HTTP::Request;
use URI;
use URI::Escape;
use Time::HiRes qw(sleep time);
use JSON::XS;
use Log::Log4perl;
use Data::Dumper;

use Moo;
use namespace::clean;

# Attributes
has 'config' => (
    is       => 'ro',
    required => 1,
);

has 'ua' => (
    is      => 'lazy',
    builder => '_build_ua',
);

has 'logger' => (
    is      => 'lazy', 
    builder => '_build_logger',
);

has 'last_request_time' => (
    is      => 'rw',
    default => 0,
);

has 'request_count' => (
    is      => 'rw',
    default => 0,
);

has 'minute_start' => (
    is      => 'rw', 
    default => sub { time() },
);

has 'hash_manager' => (
    is      => 'lazy',
    builder => '_build_hash_manager',
);

# Build LWP::UserAgent with proper configuration
sub _build_ua {
    my $self = shift;
    
    my $ua = LWP::UserAgent->new(
        agent      => $self->config->{crawler}{user_agent},
        timeout    => $self->config->{crawler}{timeout},
        max_redirect => $self->config->{crawler}{max_redirects},
    );
    
    # SSL configuration to handle certificate verification
    $ua->ssl_opts(
        verify_hostname => 0, 
        SSL_verify_mode => 0x00,
        SSL_ca_file => undef,
        SSL_ca_path => undef,
    );
    
    # Set common headers
    $ua->default_headers->header(
        'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language' => 'en-US,en;q=0.5',
        'Accept-Encoding' => 'gzip, deflate',
        'DNT' => '1',
        'Connection' => 'keep-alive',
        'Upgrade-Insecure-Requests' => '1',
    );
    
    return $ua;
}

sub _build_logger {
    my $self = shift;
    return Log::Log4perl->get_logger(__PACKAGE__);
}

sub _build_hash_manager {
    my $self = shift;
    require Tessera::HashManager;
    return Tessera::HashManager->new();
}

# Crawl a Wikipedia page
sub crawl_page {
    my ($self, $url) = @_;
    
    # Rate limiting
    $self->_rate_limit();
    
    $self->logger->info("Crawling: $url");
    
    my $response = $self->ua->get($url);
    
    if (!$response->is_success) {
        $self->logger->error("Failed to fetch $url: " . $response->status_line);
        return;
    }
    
    my $content = $response->decoded_content;
    
    if (!$content) {
        $self->logger->warn("No content received for $url");
        return;
    }
    
    return {
        url => $url,
        content => $content,
        status => $response->code,
        headers => $response->headers,
        fetched_at => time(),
    };
}

# Get Wikipedia API data for an article
sub get_api_data {
    my ($self, $title) = @_;
    
    # Rate limiting
    $self->_rate_limit();
    
    my $api_url = $self->config->{wikipedia}{api_url};
    
    # Construct API URL for page info, extracts, categories, links
    my $uri = URI->new($api_url);
    $uri->query_form(
        action => 'query',
        format => 'json',
        titles => $title,
        prop => 'extracts|categories|links|pageimages',
        exintro => 1,
        explaintext => 1,
        exsectionformat => 'plain',
        cllimit => 50,
        pllimit => 50,
        piprop => 'thumbnail',
        pithumbsize => 300,
    );
    
    $self->logger->debug("API request: $uri");
    
    my $response = $self->ua->get($uri);
    
    if (!$response->is_success) {
        $self->logger->error("API request failed for '$title': " . $response->status_line);
        return;
    }
    
    my $data;
    eval {
        $data = decode_json($response->decoded_content);
    };
    
    if ($@) {
        $self->logger->error("Failed to decode JSON response for '$title': $@");
        return;
    }
    
    return $data;
}

# Extract title from Wikipedia URL
sub extract_title_from_url {
    my ($self, $url) = @_;
    
    my $uri = URI->new($url);
    my $path = $uri->path;
    
    # Extract title from /wiki/Article_Title
    if ($path =~ m{^/wiki/([^#?]+)}) {
        my $title = uri_unescape($1);
        $title =~ s/_/ /g;
        return $title;
    }
    
    return;
}

# Convert Wikipedia title to URL
sub title_to_url {
    my ($self, $title) = @_;
    
    my $encoded_title = $title;
    $encoded_title =~ s/ /_/g;
    $encoded_title = uri_escape_utf8($encoded_title);
    
    return $self->config->{wikipedia}{base_url} . "/wiki/" . $encoded_title;
}

# Check if URL is a valid Wikipedia article
sub is_wikipedia_article {
    my ($self, $url) = @_;
    
    return 0 unless $url;
    
    my $uri = URI->new($url);
    my $host = $uri->host || '';
    my $path = $uri->path || '';
    
    # Check if it's Wikipedia and an article page
    return $host =~ /wikipedia\.org$/ && $path =~ m{^/wiki/[^:]+$};
}

# Generate URL hash for deduplication
sub hash_url {
    my ($self, $url) = @_;
    return $self->hash_manager->hash_url($url);
}

# Rate limiting implementation
sub _rate_limit {
    my $self = shift;
    
    my $now = time();
    my $delay = $self->config->{crawler}{delay_between_requests};
    my $max_per_minute = $self->config->{crawler}{max_requests_per_minute};
    
    # Check if we need to wait between requests
    my $time_since_last = $now - $self->last_request_time;
    if ($time_since_last < $delay) {
        my $sleep_time = $delay - $time_since_last;
        $self->logger->debug("Rate limiting: sleeping for ${sleep_time}s");
        sleep($sleep_time);
        $now = time();
    }
    
    # Check requests per minute limit
    if ($now - $self->minute_start >= 60) {
        # Reset counter for new minute
        $self->minute_start($now);
        $self->request_count(0);
    }
    
    if ($self->request_count >= $max_per_minute) {
        my $sleep_until_next_minute = 60 - ($now - $self->minute_start);
        $self->logger->info("Hit rate limit, sleeping for ${sleep_until_next_minute}s");
        sleep($sleep_until_next_minute);
        $self->minute_start(time());
        $self->request_count(0);
    }
    
    $self->last_request_time(time());
    $self->request_count($self->request_count + 1);
}

1;

__END__

=head1 NAME

Tessera::Crawler - Wikipedia web crawler with rate limiting

=head1 SYNOPSIS

    use Tessera::Crawler;
    
    my $crawler = Tessera::Crawler->new(
        config => $config_hashref
    );
    
    my $page_data = $crawler->crawl_page('https://en.wikipedia.org/wiki/Perl');
    my $api_data = $crawler->get_api_data('Perl (programming language)');

=head1 DESCRIPTION

This module provides web crawling capabilities for Wikipedia with intelligent 
rate limiting and proper HTTP handling. It respects Wikipedia's terms of service
and implements best practices for web scraping.

=head1 METHODS

=head2 crawl_page($url)

Fetches a Wikipedia page and returns structured data including content, headers, and metadata.

=head2 get_api_data($title) 

Fetches article data via Wikipedia's API, including extracts, categories, and links.

=head2 extract_title_from_url($url)

Extracts the article title from a Wikipedia URL.

=head2 title_to_url($title)

Converts an article title to a proper Wikipedia URL.

=head2 is_wikipedia_article($url)

Checks if a URL points to a valid Wikipedia article.

=head1 AUTHOR

Tessera Project

=cut
