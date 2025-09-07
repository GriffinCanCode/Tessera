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
use Tessera::LinkAnalyzer;
use YAML::XS qw(LoadFile);
use Time::HiRes qw(time);
use List::Util qw(shuffle);

# Load test configuration
my $config_file = "$FindBin::Bin/../t/test_config.yaml";
my $config = LoadFile($config_file);

# Create test helper for generating sample data
my $helper = TestHelper->new();

# Test datasets of different sizes
my %datasets = (
    small => {
        links => 100,
        interests => 5,
        boost_keywords => 3,
        description => "Small dataset (100 links, 5 interests)"
    },
    medium => {
        links => 500,
        interests => 10,
        boost_keywords => 8,
        description => "Medium dataset (500 links, 10 interests)"
    },
    large => {
        links => 2000,
        interests => 20,
        boost_keywords => 15,
        description => "Large dataset (2000 links, 20 interests)"
    }
);

print "=== Tessera LinkAnalyzer Benchmarks ===\n\n";

# Run benchmarks for each dataset size
for my $dataset_name (sort keys %datasets) {
    my $dataset = $datasets{$dataset_name};
    
    print "=== $dataset->{description} ===\n";
    
    # Setup test data
    my ($analyzer, $test_links, $test_article) = setup_test_data($config, $helper, $dataset);
    
    # Benchmark 1: Basic relevance calculation
    print "\n1. Relevance Calculation Performance:\n";
    benchmark_relevance_calculation($analyzer, $test_links, $test_article);
    
    # Benchmark 2: Interest matching algorithms
    print "\n2. Interest Matching Performance:\n";
    benchmark_interest_matching($analyzer, $test_links);
    
    # Benchmark 3: Boost keyword matching
    print "\n3. Boost Keyword Matching Performance:\n";
    benchmark_boost_keyword_matching($analyzer, $test_links);
    
    # Benchmark 4: Context scoring
    print "\n4. Context Scoring Performance:\n";
    benchmark_context_scoring($analyzer, $test_links, $test_article);
    
    # Benchmark 5: Link filtering and sorting
    print "\n5. Link Filtering Performance:\n";
    benchmark_link_filtering($analyzer, $test_links);
    
    # Benchmark 6: Adaptive learning (interest extraction)
    print "\n6. Adaptive Learning Performance:\n";
    benchmark_adaptive_learning($analyzer, $test_article);
    
    # Benchmark 7: Recommendation generation
    print "\n7. Recommendation Generation Performance:\n";
    benchmark_recommendation_generation($analyzer, $test_links, $test_article);
    
    print "\n" . "="x60 . "\n\n";
}

print "Benchmark suite completed!\n";

# Benchmark functions

sub setup_test_data {
    my ($config, $helper, $dataset) = @_;
    
    print "Setting up test data...\n";
    
    my $start_time = time();
    
    # Create LinkAnalyzer with test interests
    my @interests = generate_test_interests($dataset->{interests});
    my @boost_keywords = generate_test_boost_keywords($dataset->{boost_keywords});
    
    # Update config with test interests
    $config->{interests} = {
        default => \@interests,
        boost_keywords => \@boost_keywords,
        min_relevance => 0.3
    };
    
    my $analyzer = Tessera::LinkAnalyzer->new(config => $config);
    
    # Generate test links
    my @test_links = generate_test_links($helper, $dataset->{links}, \@interests);
    
    # Generate test source article
    my @sample_categories = @interests[0..2];  # Use some interests as categories
    my $test_article = $helper->create_sample_article(
        id => 1,
        title => "Test Source Article",
        content => generate_content_with_interests(\@interests, 2000),
        categories => \@sample_categories
    );
    
    my $setup_time = time() - $start_time;
    printf "Setup completed: %d links, %d interests, %d boost keywords (%.2fs)\n", 
           $dataset->{links}, $dataset->{interests}, $dataset->{boost_keywords}, $setup_time;
    
    return ($analyzer, \@test_links, $test_article);
}

sub generate_test_interests {
    my ($count) = @_;
    
    my @base_interests = qw(
        programming algorithms mathematics physics chemistry biology
        history philosophy literature art music science technology
        engineering medicine psychology sociology economics politics
        geography astronomy geology ecology anthropology linguistics
    );
    
    my @shuffled = shuffle(@base_interests);
    return @shuffled[0..$count-1];
}

sub generate_test_boost_keywords {
    my ($count) = @_;
    
    my @base_keywords = qw(
        advanced expert professional academic research scientific
        fundamental principles theory practice application development
        analysis synthesis evaluation implementation optimization
        innovation breakthrough discovery methodology framework
    );
    
    my @shuffled = shuffle(@base_keywords);
    return @shuffled[0..$count-1];
}

sub generate_test_links {
    my ($helper, $count, $interests) = @_;
    
    my @links;
    
    for my $i (1..$count) {
        my $link_type = int(rand(4));
        my $title;
        my $anchor_text;
        
        if ($link_type == 0) {
            # Interest-matching link
            my $interest = $interests->[int(rand(@$interests))];
            $title = ucfirst($interest) . " Article $i";
            $anchor_text = $interest;
        } elsif ($link_type == 1) {
            # Partially matching link
            my $interest = $interests->[int(rand(@$interests))];
            $title = "Advanced $interest Research $i";
            $anchor_text = "research in $interest";
        } elsif ($link_type == 2) {
            # Random technical link
            $title = "Technical Article $i";
            $anchor_text = "technical reference";
        } else {
            # Completely random link
            $title = "Random Article $i";
            $anchor_text = "random link";
        }
        
        push @links, {
            title => $title,
            url => "https://en.wikipedia.org/wiki/" . $title,
            anchor_text => $anchor_text
        };
    }
    
    return @links;
}

sub generate_content_with_interests {
    my ($interests, $length) = @_;
    
    my $content = "This is a test article about ";
    $content .= join(", ", @$interests[0..2]) . ". ";
    
    # Add more content with interest keywords scattered throughout
    my @filler_words = qw(
        research study analysis investigation examination exploration
        development implementation application utilization methodology
        framework approach technique strategy process procedure
        concept principle theory hypothesis assumption conclusion
    );
    
    while (length($content) < $length) {
        my $interest = $interests->[int(rand(@$interests))];
        my $filler = $filler_words[int(rand(@filler_words))];
        $content .= "The $filler of $interest is important for understanding. ";
    }
    
    return $content;
}

sub benchmark_relevance_calculation {
    my ($analyzer, $test_links, $test_article) = @_;
    
    my $results = timethese(-3, {
        'single_link_relevance' => sub {
            my $link = $test_links->[int(rand(@$test_links))];
            my $relevance = $analyzer->calculate_relevance($link, $test_article);
        },
        'batch_relevance_10' => sub {
            my @batch = @$test_links[0..9];
            for my $link (@batch) {
                my $relevance = $analyzer->calculate_relevance($link, $test_article);
            }
        },
        'batch_relevance_100' => sub {
            my @batch = @$test_links[0..99];
            for my $link (@batch) {
                my $relevance = $analyzer->calculate_relevance($link, $test_article);
            }
        }
    });
    
    print_benchmark_results($results, "Relevance Calculation");
}

sub benchmark_interest_matching {
    my ($analyzer, $test_links) = @_;
    
    my $results = timethese(-3, {
        'title_matching' => sub {
            for my $i (0..49) {  # Test 50 links
                my $link = $test_links->[$i % @$test_links];
                my $score = $analyzer->_match_interests($link->{title});
            }
        },
        'anchor_matching' => sub {
            for my $i (0..49) {
                my $link = $test_links->[$i % @$test_links];
                my $score = $analyzer->_match_interests($link->{anchor_text});
            }
        },
        'combined_matching' => sub {
            for my $i (0..49) {
                my $link = $test_links->[$i % @$test_links];
                my $title_score = $analyzer->_match_interests($link->{title});
                my $anchor_score = $analyzer->_match_interests($link->{anchor_text});
            }
        }
    });
    
    print_benchmark_results($results, "Interest Matching");
}

sub benchmark_boost_keyword_matching {
    my ($analyzer, $test_links) = @_;
    
    my $results = timethese(-3, {
        'boost_title_matching' => sub {
            for my $i (0..49) {
                my $link = $test_links->[$i % @$test_links];
                my $score = $analyzer->_match_boost_keywords($link->{title});
            }
        },
        'boost_anchor_matching' => sub {
            for my $i (0..49) {
                my $link = $test_links->[$i % @$test_links];
                my $score = $analyzer->_match_boost_keywords($link->{anchor_text});
            }
        }
    });
    
    print_benchmark_results($results, "Boost Keyword Matching");
}

sub benchmark_context_scoring {
    my ($analyzer, $test_links, $test_article) = @_;
    
    my $results = timethese(-3, {
        'context_calculation' => sub {
            for my $i (0..29) {  # Test 30 links
                my $link = $test_links->[$i % @$test_links];
                my $score = $analyzer->_calculate_context_score($link, $test_article);
            }
        },
        'topic_area_detection' => sub {
            for my $i (0..49) {
                my $link = $test_links->[$i % @$test_links];
                my $same_topic = $analyzer->_is_same_topic_area(
                    $link->{title}, 
                    $test_article->{title}
                );
            }
        }
    });
    
    print_benchmark_results($results, "Context Scoring");
}

sub benchmark_link_filtering {
    my ($analyzer, $test_links) = @_;
    
    # First analyze all links to get relevance scores
    my @analyzed_links;
    for my $link (@$test_links) {
        my $analyzed_link = { %$link };
        $analyzed_link->{relevance_score} = 0.3 + rand(0.7); # Random score
        push @analyzed_links, $analyzed_link;
    }
    
    my $results = timethese(-3, {
        'filter_by_relevance' => sub {
            my $filtered = $analyzer->filter_links(
                \@analyzed_links,
                min_relevance => 0.5
            );
        },
        'filter_with_limit' => sub {
            my $filtered = $analyzer->filter_links(
                \@analyzed_links,
                min_relevance => 0.3,
                max_count => 50
            );
        },
        'filter_with_dedup' => sub {
            my $filtered = $analyzer->filter_links(
                \@analyzed_links,
                deduplicate => 1
            );
        },
        'full_filtering' => sub {
            my $filtered = $analyzer->filter_links(
                \@analyzed_links,
                min_relevance => 0.4,
                max_count => 100,
                deduplicate => 1,
                exclude_patterns => ['Random', 'Test']
            );
        }
    });
    
    print_benchmark_results($results, "Link Filtering");
}

sub benchmark_adaptive_learning {
    my ($analyzer, $test_article) = @_;
    
    my $results = timethese(-3, {
        'extract_from_title' => sub {
            # Create articles with different titles
            for my $i (1..20) {
                my $article = {
                    title => "Advanced Machine Learning Algorithm $i",
                    categories => ["Computer Science", "Artificial Intelligence"]
                };
                $analyzer->extract_interests_from_article($article);
            }
        },
        'extract_from_categories' => sub {
            for my $i (1..20) {
                my $article = {
                    title => "Test Article $i",
                    categories => ["Physics", "Quantum Mechanics", "Theoretical Physics"]
                };
                $analyzer->extract_interests_from_article($article);
            }
        }
    });
    
    print_benchmark_results($results, "Adaptive Learning");
}

sub benchmark_recommendation_generation {
    my ($analyzer, $test_links, $test_article) = @_;
    
    my $results = timethese(-3, {
        'recommendations_10' => sub {
            my $recommendations = $analyzer->get_recommendations(
                $test_article,
                [@$test_links[0..99]], # Use first 100 links
                limit => 10
            );
        },
        'recommendations_25' => sub {
            my $recommendations = $analyzer->get_recommendations(
                $test_article,
                [@$test_links[0..199]], # Use first 200 links
                limit => 25
            );
        },
        'recommendations_strict' => sub {
            my $recommendations = $analyzer->get_recommendations(
                $test_article,
                [@$test_links[0..99]],
                limit => 10,
                min_relevance => 0.7
            );
        }
    });
    
    print_benchmark_results($results, "Recommendation Generation");
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

# Performance analysis helpers
sub analyze_algorithm_complexity {
    my ($analyzer, $test_links) = @_;
    
    print "\nAlgorithm Complexity Analysis:\n";
    print "-" x 40 . "\n";
    
    # Test with different input sizes
    my @sizes = (10, 50, 100, 500, 1000);
    
    for my $size (@sizes) {
        next if $size > @$test_links;
        
        my @subset = @$test_links[0..$size-1];
        
        my $start_time = time();
        my $analyzed = $analyzer->analyze_links(\@subset);
        my $duration = time() - $start_time;
        
        my $ops_per_sec = $size / $duration;
        printf "Size %4d: %8.2f links/sec (%.4fs total)\n", 
               $size, $ops_per_sec, $duration;
    }
}

# Memory usage profiling
sub profile_memory_usage {
    my ($analyzer, $test_links) = @_;
    
    print "\nMemory Usage Profile:\n";
    print "-" x 30 . "\n";
    
    my $initial_memory = get_memory_usage();
    
    # Analyze links in batches and measure memory growth
    my $batch_size = 100;
    for my $start (0, $batch_size, $batch_size*2) {
        last if $start >= @$test_links;
        
        my $end = $start + $batch_size - 1;
        $end = $#$test_links if $end > $#$test_links;
        
        my @batch = @$test_links[$start..$end];
        my $analyzed = $analyzer->analyze_links(\@batch);
        
        my $current_memory = get_memory_usage();
        my $memory_delta = $current_memory - $initial_memory;
        
        printf "Batch %d-%d: %+.2fMB\n", 
               $start, $end, $memory_delta / (1024*1024);
    }
}

sub get_memory_usage {
    my $pid = $$;
    if (-f "/proc/$pid/status") {
        open my $fh, '<', "/proc/$pid/status" or return 0;
        while (my $line = <$fh>) {
            if ($line =~ /^VmRSS:\s+(\d+)\s+kB/) {
                return $1 * 1024; # Convert to bytes
            }
        }
    }
    return 0;
}

1;

__END__

=head1 NAME

02-linkanalyzer-bench.pl - Benchmark suite for Tessera::LinkAnalyzer

=head1 DESCRIPTION

This benchmark suite tests the performance of various LinkAnalyzer operations:

- Relevance calculation algorithms
- Interest matching performance
- Boost keyword matching
- Context scoring calculations
- Link filtering and sorting
- Adaptive learning (interest extraction)
- Recommendation generation

=head1 USAGE

    cd backend/perl-backend
    perl benchmarks/02-linkanalyzer-bench.pl

=head1 BENCHMARKS

=head2 Relevance Calculation

Tests the core relevance scoring algorithm:
- Single link relevance calculation
- Batch processing performance
- Scaling with different batch sizes

=head2 Interest Matching

Tests interest matching algorithms:
- Title-based matching
- Anchor text matching
- Combined matching strategies

=head2 Boost Keyword Matching

Tests boost keyword functionality:
- Title boost matching
- Anchor text boost matching

=head2 Context Scoring

Tests contextual relevance calculations:
- Context score calculation
- Topic area detection

=head2 Link Filtering

Tests filtering and sorting operations:
- Relevance-based filtering
- Count-based limiting
- Deduplication
- Pattern-based exclusion

=head2 Adaptive Learning

Tests interest extraction from articles:
- Title-based extraction
- Category-based extraction

=head2 Recommendation Generation

Tests end-to-end recommendation workflows:
- Different recommendation limits
- Strict relevance filtering

=head1 AUTHOR

Tessera Project

=cut
