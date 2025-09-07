#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../t/lib";

use Benchmark qw(:all);
use Test::More;
use TestHelper;
use YAML::XS qw(LoadFile);
use Time::HiRes qw(time);
use List::Util qw(sum);

# Load test configuration
my $config_file = "$FindBin::Bin/../t/test_config.yaml";
my $config = LoadFile($config_file);

# Create test helper for generating sample data
my $helper = TestHelper->new();

# Test datasets for different API server calculations
my %datasets = (
    small => {
        content_items => 50,
        subjects => 5,
        description => "Small dataset (50 content items, 5 subjects)"
    },
    medium => {
        content_items => 200,
        subjects => 10,
        description => "Medium dataset (200 content items, 10 subjects)"
    },
    large => {
        content_items => 1000,
        subjects => 25,
        description => "Large dataset (1000 content items, 25 subjects)"
    }
);

print "=== Tessera API Server Calculation Benchmarks ===\n\n";

# Run benchmarks for each dataset size
for my $dataset_name (sort keys %datasets) {
    my $dataset = $datasets{$dataset_name};
    
    print "=== $dataset->{description} ===\n";
    
    # Setup test data
    my ($content_items, $subjects_data) = setup_test_data($helper, $dataset);
    
    # Benchmark 1: Content weight calculations
    print "\n1. Content Weight Calculation Performance:\n";
    benchmark_content_weight_calculation($content_items);
    
    # Benchmark 2: Learning analytics calculations
    print "\n2. Learning Analytics Performance:\n";
    benchmark_learning_analytics($content_items, $subjects_data);
    
    # Benchmark 3: Brain statistics calculations
    print "\n3. Brain Statistics Performance:\n";
    benchmark_brain_statistics($content_items, $subjects_data);
    
    # Benchmark 4: Weighted knowledge calculations
    print "\n4. Weighted Knowledge Calculations:\n";
    benchmark_weighted_knowledge($content_items, $subjects_data);
    
    # Benchmark 5: Balance score calculations
    print "\n5. Balance Score Calculations:\n";
    benchmark_balance_score($subjects_data);
    
    # Benchmark 6: Relative Knowledge Depth (RKD) calculations
    print "\n6. RKD Calculation Performance:\n";
    benchmark_rkd_calculations($content_items, $subjects_data);
    
    print "\n" . "="x60 . "\n\n";
}

print "Benchmark suite completed!\n";

# Benchmark functions

sub setup_test_data {
    my ($helper, $dataset) = @_;
    
    print "Setting up test data...\n";
    
    my $start_time = time();
    
    # Generate content items with various properties
    my @content_items;
    for my $i (1..$dataset->{content_items}) {
        my $content_item = {
            id => $i,
            title => "Test Content Item $i",
            content => generate_content_of_length(500 + int(rand(2000))),
            summary => generate_content_of_length(100 + int(rand(200))),
            content_type => choose_random(['book', 'course', 'article', 'video', 'youtube', 'text', 'poetry']),
            difficulty_level => 1 + int(rand(5)), # 1-5
            completion_percentage => int(rand(101)), # 0-100
            actual_time_minutes => int(rand(300)), # 0-300 minutes
        };
        push @content_items, $content_item;
    }
    
    # Generate subjects data
    my @subjects_data;
    for my $i (1..$dataset->{subjects}) {
        my $subject = {
            id => $i,
            name => "Subject $i",
            description => "Test subject $i for benchmarking",
            color => sprintf("#%06X", int(rand(0xFFFFFF))),
            icon => "test-icon-$i"
        };
        push @subjects_data, $subject;
    }
    
    # Assign content items to subjects randomly
    for my $content (@content_items) {
        my $subject_id = 1 + int(rand($dataset->{subjects}));
        $content->{subject_id} = $subject_id;
    }
    
    my $setup_time = time() - $start_time;
    printf "Setup completed: %d content items, %d subjects (%.2fs)\n", 
           $dataset->{content_items}, $dataset->{subjects}, $setup_time;
    
    return (\@content_items, \@subjects_data);
}

sub generate_content_of_length {
    my ($length) = @_;
    
    my @words = qw(
        learning education knowledge study research analysis development
        implementation understanding comprehension mastery expertise
        skill competency proficiency advancement progress achievement
        discovery exploration investigation examination methodology
        framework approach technique strategy process procedure
    );
    
    my $content = "";
    while (length($content) < $length) {
        my $word = $words[int(rand(@words))];
        $content .= "$word ";
    }
    
    return substr($content, 0, $length);
}

sub choose_random {
    my ($array_ref) = @_;
    return $array_ref->[int(rand(@$array_ref))];
}

sub benchmark_content_weight_calculation {
    my ($content_items) = @_;
    
    my $results = timethese(-3, {
        'single_weight_calc' => sub {
            my $item = $content_items->[int(rand(@$content_items))];
            my $weight = calculate_content_weight($item);
        },
        'batch_weight_10' => sub {
            for my $i (0..9) {
                my $item = $content_items->[$i % @$content_items];
                my $weight = calculate_content_weight($item);
            }
        },
        'batch_weight_100' => sub {
            for my $i (0..99) {
                my $item = $content_items->[$i % @$content_items];
                my $weight = calculate_content_weight($item);
            }
        },
        'all_weights' => sub {
            my $total_weight = 0;
            for my $item (@$content_items) {
                $total_weight += calculate_content_weight($item);
            }
        }
    });
    
    print_benchmark_results($results, "Content Weight Calculation");
}

sub benchmark_learning_analytics {
    my ($content_items, $subjects_data) = @_;
    
    my $results = timethese(-3, {
        'subject_analytics' => sub {
            for my $subject (@$subjects_data) {
                my @subject_content = grep { $_->{subject_id} == $subject->{id} } @$content_items;
                
                my $total_content = scalar(@subject_content);
                my $completed_content = scalar(grep { $_->{completion_percentage} >= 100 } @subject_content);
                my $avg_completion = $total_content > 0 ? 
                    (sum(map { $_->{completion_percentage} } @subject_content) / $total_content) : 0;
                my $total_time = sum(map { $_->{actual_time_minutes} || 0 } @subject_content);
            }
        },
        'completion_stats' => sub {
            my $total_items = @$content_items;
            my $completed_items = scalar(grep { $_->{completion_percentage} >= 100 } @$content_items);
            my $avg_completion = sum(map { $_->{completion_percentage} } @$content_items) / $total_items;
            my $total_time = sum(map { $_->{actual_time_minutes} || 0 } @$content_items);
        }
    });
    
    print_benchmark_results($results, "Learning Analytics");
}

sub benchmark_brain_statistics {
    my ($content_items, $subjects_data) = @_;
    
    my $results = timethese(-3, {
        'brain_stats_full' => sub {
            my $total_weighted_knowledge = 0;
            my $total_possible_weight = 0;
            my $dominant_subject = '';
            my $max_weighted_completion = 0;
            my $total_time = 0;
            
            for my $subject (@$subjects_data) {
                my @subject_content = grep { $_->{subject_id} == $subject->{id} } @$content_items;
                
                my $subject_weighted_knowledge = 0;
                my $subject_total_weight = 0;
                
                for my $item (@subject_content) {
                    my $weight = calculate_content_weight($item);
                    my $completion = ($item->{completion_percentage} || 0) / 100;
                    
                    $subject_weighted_knowledge += $weight * $completion;
                    $subject_total_weight += $weight;
                }
                
                my $rkd = $subject_total_weight > 0 ? $subject_weighted_knowledge / $subject_total_weight : 0;
                $subject->{weighted_completion} = $rkd * 100;
                
                $total_weighted_knowledge += $subject_weighted_knowledge;
                $total_possible_weight += $subject_total_weight;
                $total_time += sum(map { $_->{actual_time_minutes} || 0 } @subject_content);
                
                if ($rkd > $max_weighted_completion) {
                    $max_weighted_completion = $rkd;
                    $dominant_subject = $subject->{name};
                }
            }
            
            my $overall_rkd = $total_possible_weight > 0 ? $total_weighted_knowledge / $total_possible_weight : 0;
        },
        'knowledge_velocity' => sub {
            my $total_weighted_knowledge = 0;
            my $total_possible_weight = 0;
            
            for my $item (@$content_items) {
                my $weight = calculate_content_weight($item);
                my $completion = ($item->{completion_percentage} || 0) / 100;
                
                $total_weighted_knowledge += $weight * $completion;
                $total_possible_weight += $weight;
            }
            
            my $velocity = $total_possible_weight > 0 ? $total_weighted_knowledge / $total_possible_weight : 0;
        }
    });
    
    print_benchmark_results($results, "Brain Statistics");
}

sub benchmark_weighted_knowledge {
    my ($content_items, $subjects_data) = @_;
    
    my $results = timethese(-3, {
        'weighted_by_subject' => sub {
            my %subject_weights;
            
            for my $subject (@$subjects_data) {
                my @subject_content = grep { $_->{subject_id} == $subject->{id} } @$content_items;
                
                my $weighted_knowledge = 0;
                my $total_weight = 0;
                
                for my $item (@subject_content) {
                    my $weight = calculate_content_weight($item);
                    my $completion = ($item->{completion_percentage} || 0) / 100;
                    
                    $weighted_knowledge += $weight * $completion;
                    $total_weight += $weight;
                }
                
                $subject_weights{$subject->{id}} = {
                    weighted_knowledge => $weighted_knowledge,
                    total_weight => $total_weight,
                    rkd => $total_weight > 0 ? $weighted_knowledge / $total_weight : 0
                };
            }
        },
        'global_weighted' => sub {
            my $total_weighted = 0;
            my $total_possible = 0;
            
            for my $item (@$content_items) {
                my $weight = calculate_content_weight($item);
                my $completion = ($item->{completion_percentage} || 0) / 100;
                
                $total_weighted += $weight * $completion;
                $total_possible += $weight;
            }
            
            my $global_rkd = $total_possible > 0 ? $total_weighted / $total_possible : 0;
        }
    });
    
    print_benchmark_results($results, "Weighted Knowledge");
}

sub benchmark_balance_score {
    my ($subjects_data) = @_;
    
    # Pre-calculate weighted completions for subjects
    my @weighted_completions;
    for my $i (0..$#$subjects_data) {
        push @weighted_completions, 20 + rand(60); # Random completion 20-80%
    }
    
    my $results = timethese(-3, {
        'balance_calculation' => sub {
            my $avg_weighted = @weighted_completions ? (sum(@weighted_completions) / @weighted_completions) : 0;
            my $variance = 0;
            
            for my $completion (@weighted_completions) {
                $variance += ($completion - $avg_weighted) ** 2;
            }
            
            $variance = @weighted_completions ? $variance / @weighted_completions : 0;
            my $balance_score = @weighted_completions ? int(100 - sqrt($variance)) : 0;
            $balance_score = $balance_score > 0 ? $balance_score : 0;
        },
        'variance_only' => sub {
            my $avg = sum(@weighted_completions) / @weighted_completions;
            my $variance = 0;
            
            for my $val (@weighted_completions) {
                $variance += ($val - $avg) ** 2;
            }
            
            $variance /= @weighted_completions;
        },
        'standard_deviation' => sub {
            my $avg = sum(@weighted_completions) / @weighted_completions;
            my $variance = 0;
            
            for my $val (@weighted_completions) {
                $variance += ($val - $avg) ** 2;
            }
            
            my $std_dev = sqrt($variance / @weighted_completions);
        }
    });
    
    print_benchmark_results($results, "Balance Score");
}

sub benchmark_rkd_calculations {
    my ($content_items, $subjects_data) = @_;
    
    my $results = timethese(-3, {
        'rkd_per_subject' => sub {
            for my $subject (@$subjects_data) {
                my @subject_content = grep { $_->{subject_id} == $subject->{id} } @$content_items;
                
                my $weighted_knowledge = 0;
                my $total_weight = 0;
                
                for my $item (@subject_content) {
                    my $weight = calculate_content_weight($item);
                    my $completion = ($item->{completion_percentage} || 0) / 100;
                    
                    $weighted_knowledge += $weight * $completion;
                    $total_weight += $weight;
                }
                
                my $rkd = $total_weight > 0 ? $weighted_knowledge / $total_weight : 0;
            }
        },
        'rkd_global' => sub {
            my $total_weighted_knowledge = 0;
            my $total_possible_weight = 0;
            
            for my $item (@$content_items) {
                my $weight = calculate_content_weight($item);
                my $completion = ($item->{completion_percentage} || 0) / 100;
                
                $total_weighted_knowledge += $weight * $completion;
                $total_possible_weight += $weight;
            }
            
            my $global_rkd = $total_possible_weight > 0 ? $total_weighted_knowledge / $total_possible_weight : 0;
        },
        'rkd_with_scaling' => sub {
            my $total_weighted_knowledge = 0;
            my $total_possible_weight = 0;
            
            for my $item (@$content_items) {
                my $weight = calculate_content_weight($item);
                my $completion = ($item->{completion_percentage} || 0) / 100;
                
                $total_weighted_knowledge += $weight * $completion;
                $total_possible_weight += $weight;
            }
            
            my $rkd = $total_possible_weight > 0 ? $total_weighted_knowledge / $total_possible_weight : 0;
            my $scaled_knowledge_points = int($rkd * 1000); # Scale for display
        }
    });
    
    print_benchmark_results($results, "RKD Calculations");
}

# Core calculation function (from api_server.pl)
sub calculate_content_weight {
    my ($content_item) = @_;
    
    my $base_weight = 1.0;
    
    # Length factor (log scale to prevent huge articles from dominating)
    my $content_text = $content_item->{content} || $content_item->{summary} || '';
    my $content_length = length($content_text);
    $content_length = 100 if $content_length == 0;  # Default for empty content
    
    my $length_factor = log($content_length + 1) / log(1000);  # Normalized to ~1000 char baseline
    
    # Difficulty factor
    my $difficulty_factor = ($content_item->{difficulty_level} || 3) / 3.0;
    
    # Content type factor
    my %type_factors = (
        'book' => 2.0,
        'course' => 1.8,
        'article' => 1.0,
        'video' => 0.8,
        'youtube' => 0.6,
        'text' => 0.4,
        'poetry' => 0.3,
    );
    my $type_factor = $type_factors{$content_item->{content_type} || 'article'} || 1.0;
    
    return $base_weight * $length_factor * $difficulty_factor * $type_factor;
}

sub print_benchmark_results {
    my ($results, $category) = @_;
    
    print "\n$category Results:\n";
    print "-" x 50 . "\n";
    
    for my $test_name (sort keys %$results) {
        my $result = $results->{$test_name};
        my $rate = $result->iters / $result->cpu_a;
        my $time_per_op = $result->cpu_a / $result->iters;
        
        printf "%-25s: %8.2f ops/sec (%.4fs per op)\n", 
               $test_name, $rate, $time_per_op;
    }
}

# Algorithm complexity analysis
sub analyze_calculation_complexity {
    my ($content_items, $subjects_data) = @_;
    
    print "\nCalculation Complexity Analysis:\n";
    print "-" x 40 . "\n";
    
    # Test with different dataset sizes
    my @sizes = (10, 50, 100, 500, 1000);
    
    for my $size (@sizes) {
        next if $size > @$content_items;
        
        my @subset = @$content_items[0..$size-1];
        
        my $start_time = time();
        
        # Perform full brain statistics calculation
        my $total_weighted_knowledge = 0;
        my $total_possible_weight = 0;
        
        for my $item (@subset) {
            my $weight = calculate_content_weight($item);
            my $completion = ($item->{completion_percentage} || 0) / 100;
            
            $total_weighted_knowledge += $weight * $completion;
            $total_possible_weight += $weight;
        }
        
        my $duration = time() - $start_time;
        my $items_per_sec = $size / $duration;
        
        printf "Size %4d: %8.2f items/sec (%.4fs total)\n", 
               $size, $items_per_sec, $duration;
    }
}

# Performance profiling for specific calculations
sub profile_calculation_performance {
    my ($content_items) = @_;
    
    print "\nCalculation Performance Profile:\n";
    print "-" x 35 . "\n";
    
    # Profile individual components of content weight calculation
    my $iterations = 1000;
    
    # Length factor calculation
    my $start_time = time();
    for my $i (1..$iterations) {
        my $item = $content_items->[int(rand(@$content_items))];
        my $content_text = $item->{content} || $item->{summary} || '';
        my $content_length = length($content_text);
        $content_length = 100 if $content_length == 0;
        my $length_factor = log($content_length + 1) / log(1000);
    }
    my $length_time = time() - $start_time;
    
    # Difficulty factor calculation
    $start_time = time();
    for my $i (1..$iterations) {
        my $item = $content_items->[int(rand(@$content_items))];
        my $difficulty_factor = ($item->{difficulty_level} || 3) / 3.0;
    }
    my $difficulty_time = time() - $start_time;
    
    # Type factor lookup
    $start_time = time();
    for my $i (1..$iterations) {
        my $item = $content_items->[int(rand(@$content_items))];
        my %type_factors = (
            'book' => 2.0, 'course' => 1.8, 'article' => 1.0,
            'video' => 0.8, 'youtube' => 0.6, 'text' => 0.4, 'poetry' => 0.3,
        );
        my $type_factor = $type_factors{$item->{content_type} || 'article'} || 1.0;
    }
    my $type_time = time() - $start_time;
    
    printf "Length factor:     %8.2f ops/sec (%.4fs per %d ops)\n", 
           $iterations / $length_time, $length_time, $iterations;
    printf "Difficulty factor: %8.2f ops/sec (%.4fs per %d ops)\n", 
           $iterations / $difficulty_time, $difficulty_time, $iterations;
    printf "Type factor:       %8.2f ops/sec (%.4fs per %d ops)\n", 
           $iterations / $type_time, $type_time, $iterations;
}

1;

__END__

=head1 NAME

04-api-server-bench.pl - Benchmark suite for API Server calculations

=head1 DESCRIPTION

This benchmark suite tests the performance of various API server calculations:

- Content weight calculations
- Learning analytics computations
- Brain statistics calculations
- Weighted knowledge calculations
- Balance score calculations
- Relative Knowledge Depth (RKD) calculations

=head1 USAGE

    cd backend/perl-backend
    perl benchmarks/04-api-server-bench.pl

=head1 BENCHMARKS

=head2 Content Weight Calculation

Tests the core content weighting algorithm:
- Single weight calculation
- Batch processing performance
- Full dataset processing

=head2 Learning Analytics

Tests learning analytics computations:
- Subject-based analytics
- Completion statistics

=head2 Brain Statistics

Tests comprehensive brain statistics:
- Full brain statistics calculation
- Knowledge velocity computation

=head2 Weighted Knowledge

Tests weighted knowledge calculations:
- Subject-based weighting
- Global weighted calculations

=head2 Balance Score

Tests balance score algorithms:
- Full balance calculation
- Variance-only calculation
- Standard deviation calculation

=head2 RKD Calculations

Tests Relative Knowledge Depth calculations:
- Per-subject RKD
- Global RKD
- RKD with scaling

=head1 AUTHOR

Tessera Project

=cut
