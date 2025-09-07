package Tessera::VectorOps;

use strict;
use warnings;
use v5.20;

use Exporter 'import';
our @EXPORT_OK = qw(
    cosine_similarity
    batch_cosine_similarity
    normalize_vector
    dot_product
    vector_magnitude
);

=head1 NAME

Tessera::VectorOps - Optimized vector operations for Tessera

=head1 DESCRIPTION

Centralized, optimized vector operations to eliminate redundancy across the Tessera codebase.
Uses the most efficient implementation based on comprehensive benchmarking.

=head1 SYNOPSIS

    use Tessera::VectorOps qw(cosine_similarity batch_cosine_similarity);
    
    my $similarity = cosine_similarity($vec1, $vec2);
    my $results = batch_cosine_similarity($query, \@embeddings);

=cut

# OPTIMAL IMPLEMENTATION: Ultra-optimized using native Perl operations
# Based on comprehensive benchmarking - this is the fastest pure Perl approach
sub cosine_similarity {
    my ($vec1, $vec2) = @_;
    
    return 0 unless @$vec1 == @$vec2;
    return 0 unless @$vec1 > 0;
    
    # Pre-calculate array references for speed
    my $v1 = $vec1;
    my $v2 = $vec2;
    my $len = @$v1;
    
    my ($dot, $n1, $n2) = (0, 0, 0);
    
    # Unrolled loop for better performance - optimal for most vector sizes
    my $i = 0;
    while ($i + 3 < $len) {
        my ($a1, $a2, $a3, $a4) = @{$v1}[$i..$i+3];
        my ($b1, $b2, $b3, $b4) = @{$v2}[$i..$i+3];
        
        $dot += $a1*$b1 + $a2*$b2 + $a3*$b3 + $a4*$b4;
        $n1 += $a1*$a1 + $a2*$a2 + $a3*$a3 + $a4*$a4;
        $n2 += $b1*$b1 + $b2*$b2 + $b3*$b3 + $b4*$b4;
        
        $i += 4;
    }
    
    # Handle remaining elements
    while ($i < $len) {
        my $a = $v1->[$i];
        my $b = $v2->[$i];
        $dot += $a * $b;
        $n1 += $a * $a;
        $n2 += $b * $b;
        $i++;
    }
    
    my $norm_product = sqrt($n1 * $n2);
    return $norm_product > 0 ? $dot / $norm_product : 0;
}

# OPTIMAL BATCH IMPLEMENTATION: Optimized for multiple similarity calculations
sub batch_cosine_similarity {
    my ($query, $embeddings) = @_;
    
    return [] unless @$embeddings > 0;
    return [] unless @$query > 0;
    
    # Pre-normalize query once for efficiency
    my $query_normalized = normalize_vector($query);
    return [] unless defined $query_normalized;
    
    my @results;
    for my $embedding (@$embeddings) {
        # Skip invalid embeddings
        next unless @$embedding == @$query;
        
        my $embedding_normalized = normalize_vector($embedding);
        if (defined $embedding_normalized) {
            # Dot product of normalized vectors = cosine similarity
            push @results, dot_product($query_normalized, $embedding_normalized);
        } else {
            push @results, 0;
        }
    }
    
    return \@results;
}

# OPTIMAL: Fast dot product calculation
sub dot_product {
    my ($vec1, $vec2) = @_;
    
    return 0 unless @$vec1 == @$vec2;
    
    my $result = 0;
    my $len = @$vec1;
    my $i = 0;
    
    # Unrolled loop for performance
    while ($i + 3 < $len) {
        $result += $vec1->[$i] * $vec2->[$i] + 
                   $vec1->[$i+1] * $vec2->[$i+1] + 
                   $vec1->[$i+2] * $vec2->[$i+2] + 
                   $vec1->[$i+3] * $vec2->[$i+3];
        $i += 4;
    }
    
    # Handle remaining elements
    while ($i < $len) {
        $result += $vec1->[$i] * $vec2->[$i];
        $i++;
    }
    
    return $result;
}

# OPTIMAL: Fast vector magnitude calculation
sub vector_magnitude {
    my ($vec) = @_;
    
    return 0 unless @$vec > 0;
    
    my $sum_squares = 0;
    my $len = @$vec;
    my $i = 0;
    
    # Unrolled loop for performance
    while ($i + 3 < $len) {
        my ($v1, $v2, $v3, $v4) = @{$vec}[$i..$i+3];
        $sum_squares += $v1*$v1 + $v2*$v2 + $v3*$v3 + $v4*$v4;
        $i += 4;
    }
    
    # Handle remaining elements
    while ($i < $len) {
        my $v = $vec->[$i];
        $sum_squares += $v * $v;
        $i++;
    }
    
    return sqrt($sum_squares);
}

# OPTIMAL: Fast vector normalization
sub normalize_vector {
    my ($vec) = @_;
    
    return undef unless @$vec > 0;
    
    my $magnitude = vector_magnitude($vec);
    return undef if $magnitude == 0;
    
    return [map { $_ / $magnitude } @$vec];
}

1;

__END__

=head1 PERFORMANCE NOTES

This module uses the optimal vector operation implementations based on comprehensive
benchmarking across different approaches:

- Ultra-optimized unrolled loops for best performance
- Pre-normalization for batch operations
- Minimal memory allocation
- Cache-friendly access patterns

=head1 AUTHOR

Tessera Brain Visualization System

=cut
