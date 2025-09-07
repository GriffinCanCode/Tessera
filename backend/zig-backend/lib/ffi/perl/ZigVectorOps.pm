package ZigVectorOps;

use strict;
use warnings;
use v5.20;

use FFI::Platypus;
use File::Spec;
use File::Basename;
use Log::Log4perl;

our $VERSION = '1.0.0';

# Global FFI instance and availability flag
my $ffi;
my $zig_available = 0;
my $logger = Log::Log4perl->get_logger(__PACKAGE__);

# Initialize Zig library on module load
sub import {
    my $class = shift;
    
    # Try to load Zig library
    eval {
        $ffi = FFI::Platypus->new( api => 1 );
        
        # Find library path relative to this module
        my $module_dir = dirname(__FILE__);
        my $lib_path = File::Spec->catfile($module_dir, '..', '..', '..', 'zig-out', 'lib', 'libtessera_vector_ops.so');
        
        # Try different possible paths
        my @possible_paths = (
            $lib_path,
            '/Users/griffinstrier/projects/Wikilizer/backend/zig-backend/zig-out/lib/libtessera_vector_ops_r.dylib',
            '/Users/griffinstrier/projects/Wikilizer/backend/zig-backend/zig-out/lib/libtessera_vector_ops.dylib',
            './zig-backend/zig-out/lib/libtessera_vector_ops_r.dylib',
            '../zig-backend/zig-out/lib/libtessera_vector_ops_r.dylib',
            './zig-backend/zig-out/lib/libtessera_vector_ops.dylib',
            '../zig-backend/zig-out/lib/libtessera_vector_ops.dylib',
        );
        
        my $loaded = 0;
        for my $path (@possible_paths) {
            if (-f $path) {
                $ffi->lib($path);
                $loaded = 1;
                $logger->info("Loaded Zig library from: $path");
                last;
            }
        }
        
        die "Zig library not found" unless $loaded;
        
        # Attach C wrapper functions (R-compatible interface)
        $ffi->attach('cosine_similarity' => ['opaque', 'opaque', 'int*', 'float*'] => 'void');
        $ffi->attach('batch_cosine_similarity' => ['opaque', 'opaque', 'int*', 'int*', 'opaque'] => 'void');
        $ffi->attach('normalize_vector' => ['opaque', 'int*'] => 'void');
        
        $zig_available = 1;
        $logger->info("Zig vector operations initialized successfully");
    };
    
    if ($@) {
        $logger->warn("Zig vector operations not available: $@");
        $zig_available = 0;
    }
}

sub is_available {
    return $zig_available;
}

sub cosine_similarity {
    my ($vec1, $vec2) = @_;
    
    return 0 unless $zig_available;
    return 0 unless @$vec1 == @$vec2;
    return 0 unless @$vec1 > 0;
    
    # Convert Perl arrays to packed float arrays
    my $vec1_packed = pack('f*', @$vec1);
    my $vec2_packed = pack('f*', @$vec2);
    my $len = pack('i', scalar(@$vec1));
    my $result = pack('f', 0.0);
    
    # Call C wrapper function
    $ffi->cosine_similarity($vec1_packed, $vec2_packed, \$len, \$result);
    
    return unpack('f', $result);
}

sub batch_cosine_similarity {
    my ($query, $embeddings) = @_;
    
    return [] unless $zig_available;
    return [] unless @$embeddings > 0;
    return [] unless @$query > 0;
    
    my $num_embeddings = @$embeddings;
    my $vector_dim = @$query;
    
    # Validate all embeddings have same dimension
    for my $embedding (@$embeddings) {
        return [] unless @$embedding == $vector_dim;
    }
    
    # Pack query vector
    my $query_packed = pack('f*', @$query);
    
    # Pack embeddings matrix (row-major)
    my @flat_embeddings;
    for my $embedding (@$embeddings) {
        push @flat_embeddings, @$embedding;
    }
    my $embeddings_packed = pack('f*', @flat_embeddings);
    
    # Pack parameters
    my $num_embeddings_packed = pack('i', $num_embeddings);
    my $vector_dim_packed = pack('i', $vector_dim);
    
    # Allocate results array
    my $results_packed = "\0" x ($num_embeddings * 4); # 4 bytes per float
    
    # Call C wrapper function
    $ffi->batch_cosine_similarity(
        $query_packed,
        $embeddings_packed, 
        \$num_embeddings_packed,
        \$vector_dim_packed,
        $results_packed
    );
    
    # Unpack results
    my @results = unpack('f*', $results_packed);
    return \@results;
}

sub batch_similarity_with_threshold {
    my ($query, $embeddings, $threshold) = @_;
    
    $threshold //= 0.3;
    
    return ([], []) unless $zig_available;
    return ([], []) unless @$embeddings > 0;
    return ([], []) unless @$query > 0;
    
    my $num_embeddings = @$embeddings;
    my $vector_dim = @$query;
    
    # Validate dimensions
    for my $embedding (@$embeddings) {
        return ([], []) unless @$embedding == $vector_dim;
    }
    
    # Pack data
    my $query_packed = pack('f*', @$query);
    
    my @flat_embeddings;
    for my $embedding (@$embeddings) {
        push @flat_embeddings, @$embedding;
    }
    my $embeddings_packed = pack('f*', @flat_embeddings);
    
    # Allocate result arrays (maximum possible size)
    my $results_packed = "\0" x ($num_embeddings * 4);
    my $indices_packed = "\0" x ($num_embeddings * 4);
    
    # Call Zig function
    my $count = $ffi->batch_similarity_with_threshold(
        $query_packed,
        $embeddings_packed,
        $num_embeddings,
        $vector_dim,
        $threshold,
        $results_packed,
        $indices_packed
    );
    
    # Unpack only the valid results
    my @all_results = unpack('f*', $results_packed);
    my @all_indices = unpack('L*', $indices_packed);
    
    my @results = @all_results[0..$count-1];
    my @indices = @all_indices[0..$count-1];
    
    return (\@results, \@indices);
}

# Fallback implementations using pure Perl
sub _fallback_cosine_similarity {
    my ($vec1, $vec2) = @_;
    
    return 0 unless @$vec1 == @$vec2;
    return 0 unless @$vec1 > 0;
    
    my ($dot_product, $norm1, $norm2) = (0, 0, 0);
    
    for my $i (0 .. $#$vec1) {
        $dot_product += $vec1->[$i] * $vec2->[$i];
        $norm1 += $vec1->[$i] * $vec1->[$i];
        $norm2 += $vec2->[$i] * $vec2->[$i];
    }
    
    $norm1 = sqrt($norm1);
    $norm2 = sqrt($norm2);
    
    return ($norm1 && $norm2) ? $dot_product / ($norm1 * $norm2) : 0;
}

sub _fallback_batch_cosine_similarity {
    my ($query, $embeddings) = @_;
    
    my @results;
    for my $embedding (@$embeddings) {
        push @results, _fallback_cosine_similarity($query, $embedding);
    }
    
    return \@results;
}

# Enhanced cosine similarity with automatic fallback
sub enhanced_cosine_similarity {
    my ($vec1, $vec2) = @_;
    
    if ($zig_available) {
        return cosine_similarity($vec1, $vec2);
    } else {
        return _fallback_cosine_similarity($vec1, $vec2);
    }
}

# Enhanced batch processing with automatic fallback
sub enhanced_batch_cosine_similarity {
    my ($query, $embeddings) = @_;
    
    if ($zig_available) {
        return batch_cosine_similarity($query, $embeddings);
    } else {
        return _fallback_batch_cosine_similarity($query, $embeddings);
    }
}

1;

__END__

=head1 NAME

ZigVectorOps - High-performance vector operations using Zig backend

=head1 SYNOPSIS

    use ZigVectorOps;
    
    # Check if Zig acceleration is available
    if (ZigVectorOps::is_available()) {
        print "Zig acceleration enabled!\n";
    }
    
    # Calculate cosine similarity
    my $vec1 = [1.0, 0.0, 0.0];
    my $vec2 = [1.0, 0.0, 0.0];
    my $similarity = ZigVectorOps::cosine_similarity($vec1, $vec2);
    
    # Batch processing
    my $query = [1.0, 0.0, 0.0];
    my $embeddings = [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [-1.0, 0.0, 0.0]
    ];
    my $results = ZigVectorOps::batch_cosine_similarity($query, $embeddings);
    
    # With threshold filtering
    my ($similarities, $indices) = ZigVectorOps::batch_similarity_with_threshold(
        $query, $embeddings, 0.5
    );
    
    # Enhanced functions with automatic fallback
    my $sim = ZigVectorOps::enhanced_cosine_similarity($vec1, $vec2);
    my $batch_results = ZigVectorOps::enhanced_batch_cosine_similarity($query, $embeddings);

=head1 DESCRIPTION

This module provides high-performance vector operations using a Zig backend library.
It automatically falls back to pure Perl implementations if the Zig library is not available.

=head1 FUNCTIONS

=head2 is_available()

Returns true if Zig acceleration is available.

=head2 cosine_similarity($vec1, $vec2)

Calculate cosine similarity between two vectors using Zig acceleration.

=head2 batch_cosine_similarity($query, $embeddings)

Calculate cosine similarity between a query vector and multiple embeddings.

=head2 batch_similarity_with_threshold($query, $embeddings, $threshold)

Calculate similarities and return only those above the threshold.

=head2 enhanced_cosine_similarity($vec1, $vec2)

Cosine similarity with automatic fallback to Perl if Zig unavailable.

=head2 enhanced_batch_cosine_similarity($query, $embeddings)

Batch cosine similarity with automatic fallback.

=head1 AUTHOR

Tessera Project

=head1 LICENSE

Same as Tessera project.

=cut
