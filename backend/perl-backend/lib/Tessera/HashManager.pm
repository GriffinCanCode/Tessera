package Tessera::HashManager;

use strict;
use warnings;
use v5.20;

use Digest::SHA qw(sha1_hex sha256_hex sha512_hex);
use Digest::MD5 qw(md5_hex);
use Digest::CRC qw(crc32);
use MIME::Base64 qw(encode_base64url);
use Encode qw(encode_utf8);
use Log::Log4perl;
use Time::HiRes qw(time);

use Moo;
use namespace::clean;

# Attributes
has 'logger' => (
    is      => 'lazy',
    builder => '_build_logger',
);

# Hash algorithm configurations for different use cases
has 'hash_configs' => (
    is      => 'lazy',
    builder => '_build_hash_configs',
);

sub _build_logger {
    my $self = shift;
    return Log::Log4perl->get_logger(__PACKAGE__);
}

sub _build_hash_configs {
    return {
        # Content hashing - for detecting changes in article content/chunks
        content => {
            algorithm => 'sha256',
            encoding => 'hex',
            normalize => 1,  # Normalize whitespace and encoding
            description => 'Content change detection and deduplication'
        },
        
        # Cache keys - fast hashing for cache invalidation
        cache_key => {
            algorithm => 'sha1',
            encoding => 'base64url',
            normalize => 1,
            description => 'Cache key generation'
        },
        
        # Entity IDs - consistent hashing for entity identification
        entity_id => {
            algorithm => 'sha256',
            encoding => 'hex',
            normalize => 1,
            salt => 'tessera_entity',
            description => 'Entity identification and deduplication'
        },
        
        # Session/conversation IDs - shorter hashes for user-facing IDs
        session_id => {
            algorithm => 'sha1',
            encoding => 'base64url',
            truncate => 12,  # First 12 characters
            description => 'Session and conversation identifiers'
        },
        
        # File integrity - strong hashing for file verification
        file_integrity => {
            algorithm => 'sha512',
            encoding => 'hex',
            description => 'File integrity verification'
        },
        
        # Quick checksums - fast hashing for quick comparisons
        checksum => {
            algorithm => 'crc32',
            encoding => 'hex',
            description => 'Fast checksums for quick comparisons'
        },
        
        # Embedding vectors - specialized for high-dimensional data
        embedding => {
            algorithm => 'sha256',
            encoding => 'hex',
            serialize_method => 'json_canonical',
            description => 'Embedding vector hashing'
        },
        
        # URL/Link hashing - for deduplicating URLs and links
        url => {
            algorithm => 'sha1',
            encoding => 'hex',
            normalize => 1,
            url_normalize => 1,  # Special URL normalization
            description => 'URL and link deduplication'
        }
    };
}

# Main hashing interface - automatically selects best strategy
sub hash {
    my ($self, $data, $use_case, %options) = @_;
    
    return unless defined $data;
    
    # Default to content hashing if no use case specified
    $use_case ||= 'content';
    
    my $config = $self->hash_configs->{$use_case};
    unless ($config) {
        $self->logger->warn("Unknown hash use case: $use_case, falling back to content");
        $config = $self->hash_configs->{content};
    }
    
    # Merge options with config
    my %final_config = (%$config, %options);
    
    # Normalize data if requested
    if ($final_config{normalize}) {
        $data = $self->_normalize_data($data, \%final_config);
    }
    
    # Apply salt if configured
    if ($final_config{salt}) {
        $data = $final_config{salt} . '|' . $data;
    }
    
    # Generate hash based on algorithm
    my $hash = $self->_generate_hash($data, \%final_config);
    
    # Apply encoding and truncation
    $hash = $self->_format_hash($hash, \%final_config);
    
    $self->logger->debug("Generated $use_case hash: " . substr($hash, 0, 16) . "...");
    
    return $hash;
}

# Specialized methods for common use cases

# Content hashing - for article content, chunks, etc.
sub hash_content {
    my ($self, $content, %options) = @_;
    return $self->hash($content, 'content', %options);
}

# Cache key generation
sub hash_cache_key {
    my ($self, $key_data, %options) = @_;
    
    # If key_data is a hash reference, serialize it consistently
    if (ref $key_data eq 'HASH') {
        $key_data = $self->_serialize_hash_for_key($key_data);
    } elsif (ref $key_data eq 'ARRAY') {
        $key_data = join('|', @$key_data);
    }
    
    return $self->hash($key_data, 'cache_key', %options);
}

# Entity ID generation (for articles, projects, etc.)
sub hash_entity_id {
    my ($self, $entity_data, %options) = @_;
    return $self->hash($entity_data, 'entity_id', %options);
}

# Session/conversation ID generation
sub hash_session_id {
    my ($self, $session_data, %options) = @_;
    
    # Add timestamp for uniqueness if not provided
    unless ($options{no_timestamp}) {
        $session_data .= '|' . time() . '|' . int(rand(10000));
    }
    
    return $self->hash($session_data, 'session_id', %options);
}

# URL hashing with normalization
sub hash_url {
    my ($self, $url, %options) = @_;
    return $self->hash($url, 'url', %options);
}

# File integrity hashing
sub hash_file_content {
    my ($self, $file_content, %options) = @_;
    return $self->hash($file_content, 'file_integrity', %options);
}

# Quick checksum for fast comparisons
sub hash_checksum {
    my ($self, $data, %options) = @_;
    return $self->hash($data, 'checksum', %options);
}

# Embedding vector hashing
sub hash_embedding {
    my ($self, $embedding_vector, %options) = @_;
    
    # Serialize embedding vector consistently
    my $serialized;
    if (ref $embedding_vector eq 'ARRAY') {
        # Round to reasonable precision to avoid floating point issues
        my @rounded = map { sprintf("%.6f", $_) } @$embedding_vector;
        $serialized = join(',', @rounded);
    } else {
        $serialized = $embedding_vector;
    }
    
    return $self->hash($serialized, 'embedding', %options);
}

# Batch hashing for multiple items
sub hash_batch {
    my ($self, $items, $use_case, %options) = @_;
    
    return [] unless $items && @$items;
    
    my @hashes;
    for my $item (@$items) {
        push @hashes, $self->hash($item, $use_case, %options);
    }
    
    return \@hashes;
}

# Verify hash against data
sub verify_hash {
    my ($self, $data, $expected_hash, $use_case, %options) = @_;
    
    my $computed_hash = $self->hash($data, $use_case, %options);
    return $computed_hash eq $expected_hash;
}

# Private methods

sub _normalize_data {
    my ($self, $data, $config) = @_;
    
    # Ensure UTF-8 encoding
    $data = encode_utf8($data) if utf8::is_utf8($data);
    
    # URL-specific normalization
    if ($config->{url_normalize}) {
        $data = $self->_normalize_url($data);
    }
    
    # General text normalization
    if ($config->{normalize}) {
        # Normalize whitespace
        $data =~ s/\s+/ /g;
        $data =~ s/^\s+|\s+$//g;
        
        # Normalize line endings
        $data =~ s/\r\n|\r/\n/g;
        
        # Convert to lowercase for case-insensitive hashing
        if ($config->{case_insensitive}) {
            $data = lc($data);
        }
    }
    
    return $data;
}

sub _normalize_url {
    my ($self, $url) = @_;
    
    # Basic URL normalization
    $url = lc($url);
    $url =~ s/#.*$//;  # Remove fragment
    $url =~ s/\?.*$// if $url !~ /\?.*=/;  # Remove empty query string
    $url =~ s/\/+$//;  # Remove trailing slashes
    $url =~ s/\/+/\//g;  # Normalize multiple slashes
    
    return $url;
}

sub _generate_hash {
    my ($self, $data, $config) = @_;
    
    my $algorithm = $config->{algorithm};
    
    if ($algorithm eq 'sha256') {
        return sha256_hex($data);
    } elsif ($algorithm eq 'sha1') {
        return sha1_hex($data);
    } elsif ($algorithm eq 'sha512') {
        return sha512_hex($data);
    } elsif ($algorithm eq 'md5') {
        return md5_hex($data);
    } elsif ($algorithm eq 'crc32') {
        return sprintf("%08x", crc32($data));
    } else {
        $self->logger->error("Unknown hash algorithm: $algorithm");
        return sha256_hex($data);  # Fallback
    }
}

sub _format_hash {
    my ($self, $hash, $config) = @_;
    
    # Apply encoding
    if ($config->{encoding} eq 'base64url') {
        # Convert hex to binary then to base64url
        $hash = encode_base64url(pack('H*', $hash));
        $hash =~ s/=+$//;  # Remove padding
    }
    # 'hex' encoding is already applied by the hash functions
    
    # Apply truncation
    if ($config->{truncate} && length($hash) > $config->{truncate}) {
        $hash = substr($hash, 0, $config->{truncate});
    }
    
    return $hash;
}

sub _serialize_hash_for_key {
    my ($self, $hash_ref) = @_;
    
    # Sort keys for consistent serialization
    my @sorted_keys = sort keys %$hash_ref;
    my @key_value_pairs;
    
    for my $key (@sorted_keys) {
        my $value = $hash_ref->{$key};
        
        # Handle nested structures
        if (ref $value eq 'HASH') {
            $value = $self->_serialize_hash_for_key($value);
        } elsif (ref $value eq 'ARRAY') {
            $value = join(',', @$value);
        } elsif (!defined $value) {
            $value = '';
        }
        
        push @key_value_pairs, "$key:$value";
    }
    
    return join('|', @key_value_pairs);
}

# Utility methods

# Get hash configuration for a use case
sub get_hash_config {
    my ($self, $use_case) = @_;
    return $self->hash_configs->{$use_case};
}

# List available hash use cases
sub list_use_cases {
    my $self = shift;
    return sort keys %{$self->hash_configs};
}

# Get hash algorithm info
sub get_algorithm_info {
    my ($self, $use_case) = @_;
    
    my $config = $self->hash_configs->{$use_case} || return;
    
    return {
        use_case => $use_case,
        algorithm => $config->{algorithm},
        encoding => $config->{encoding},
        description => $config->{description},
        features => {
            normalize => $config->{normalize} || 0,
            salt => $config->{salt} ? 1 : 0,
            truncate => $config->{truncate} || 0,
        }
    };
}

# Performance benchmarking
sub benchmark_algorithms {
    my ($self, $test_data, $iterations) = @_;
    
    $iterations ||= 1000;
    $test_data ||= "This is a test string for benchmarking hash algorithms" x 10;
    
    my %results;
    
    for my $use_case ($self->list_use_cases) {
        my $start_time = time();
        
        for (1..$iterations) {
            $self->hash($test_data, $use_case);
        }
        
        my $elapsed = time() - $start_time;
        $results{$use_case} = {
            elapsed_seconds => $elapsed,
            hashes_per_second => $elapsed > 0 ? $iterations / $elapsed : $iterations,
            config => $self->get_algorithm_info($use_case)
        };
    }
    
    return \%results;
}

1;

__END__

=head1 NAME

Tessera::HashManager - Centralized hashing strategy manager for Tessera

=head1 SYNOPSIS

    use Tessera::HashManager;
    
    my $hasher = Tessera::HashManager->new();
    
    # Content hashing for change detection
    my $content_hash = $hasher->hash_content($article_content);
    
    # Cache key generation
    my $cache_key = $hasher->hash_cache_key({
        min_relevance => 0.3,
        max_depth => 3,
        timestamp => time()
    });
    
    # Entity identification
    my $entity_id = $hasher->hash_entity_id($article_title);
    
    # Session ID generation
    my $session_id = $hasher->hash_session_id("user_context");
    
    # URL deduplication
    my $url_hash = $hasher->hash_url($wikipedia_url);
    
    # Verify hash
    my $is_valid = $hasher->verify_hash($data, $expected_hash, 'content');

=head1 DESCRIPTION

Tessera::HashManager provides a centralized, optimized hashing strategy for
different use cases within the Tessera system. It automatically selects the
most appropriate hash algorithm, encoding, and normalization strategy based on
the intended use case.

=head1 USE CASES

=head2 content

For article content, chunks, and text that needs change detection.
- Algorithm: SHA-256
- Encoding: Hexadecimal
- Features: Content normalization, UTF-8 safe

=head2 cache_key

For cache key generation and invalidation.
- Algorithm: SHA-1
- Encoding: Base64URL
- Features: Fast, compact keys

=head2 entity_id

For consistent entity identification and deduplication.
- Algorithm: SHA-256 with salt
- Encoding: Hexadecimal
- Features: Salted for security, consistent across runs

=head2 session_id

For user-facing session and conversation identifiers.
- Algorithm: SHA-1
- Encoding: Base64URL, truncated to 12 characters
- Features: Short, URL-safe identifiers

=head2 file_integrity

For file integrity verification and strong content validation.
- Algorithm: SHA-512
- Encoding: Hexadecimal
- Features: Maximum security, collision resistance

=head2 checksum

For fast comparisons and quick integrity checks.
- Algorithm: CRC32
- Encoding: Hexadecimal
- Features: Very fast, suitable for non-security use cases

=head2 embedding

For hashing embedding vectors and high-dimensional data.
- Algorithm: SHA-256
- Features: Handles floating-point precision issues

=head2 url

For URL deduplication and normalization.
- Algorithm: SHA-1
- Features: URL-specific normalization (case, fragments, etc.)

=head1 METHODS

=head2 hash($data, $use_case, %options)

Main hashing method that automatically selects the best strategy.

=head2 hash_content($content, %options)

Specialized method for content hashing.

=head2 hash_cache_key($key_data, %options)

Generate cache keys from data structures.

=head2 hash_entity_id($entity_data, %options)

Generate consistent entity identifiers.

=head2 hash_session_id($session_data, %options)

Generate short session identifiers.

=head2 hash_url($url, %options)

Hash URLs with normalization.

=head2 verify_hash($data, $expected_hash, $use_case, %options)

Verify a hash against expected value.

=head2 benchmark_algorithms($test_data, $iterations)

Performance benchmark different algorithms.

=head1 PERFORMANCE

The hash manager is optimized for different performance characteristics:

- CRC32: Fastest, for quick checksums
- SHA-1: Fast, good for cache keys and short IDs
- SHA-256: Balanced security and performance, default choice
- SHA-512: Maximum security, for critical integrity checks

=head1 AUTHOR

Tessera Project

=cut
