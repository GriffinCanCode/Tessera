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
use Tessera::Parser;
use YAML::XS qw(LoadFile);
use Time::HiRes qw(time);
use File::Slurp qw(read_file);

# Load test configuration
my $config_file = "$FindBin::Bin/../t/test_config.yaml";
my $config = LoadFile($config_file);

# Create test helper for generating sample data
my $helper = TestHelper->new();

# Test datasets with different HTML complexity levels
my %datasets = (
    simple => {
        description => "Simple Wikipedia page (basic structure)",
        content_size => "small",
        complexity => "low"
    },
    medium => {
        description => "Medium Wikipedia page (infobox, categories, sections)",
        content_size => "medium", 
        complexity => "medium"
    },
    complex => {
        description => "Complex Wikipedia page (large content, many sections, images)",
        content_size => "large",
        complexity => "high"
    }
);

print "=== Tessera Parser Benchmarks ===\n\n";

# Initialize Parser
my $parser = Tessera::Parser->new(config => $config);

# Run benchmarks for each dataset complexity
for my $dataset_name (sort keys %datasets) {
    my $dataset = $datasets{$dataset_name};
    
    print "=== $dataset->{description} ===\n";
    
    # Setup test data
    my $test_html = setup_test_html($helper, $dataset);
    my $test_url = "https://en.wikipedia.org/wiki/Test_Article";
    
    # Benchmark 1: Complete page parsing
    print "\n1. Complete Page Parsing Performance:\n";
    benchmark_complete_parsing($parser, $test_html, $test_url);
    
    # Benchmark 2: Individual extraction methods
    print "\n2. Individual Extraction Methods:\n";
    benchmark_extraction_methods($parser, $test_html, $test_url);
    
    # Benchmark 3: Content processing and cleaning
    print "\n3. Content Processing Performance:\n";
    benchmark_content_processing($parser, $test_html);
    
    # Benchmark 4: Semantic chunking (RAG)
    print "\n4. Semantic Chunking Performance:\n";
    benchmark_semantic_chunking($parser, $test_html, $test_url);
    
    # Benchmark 5: Link extraction and processing
    print "\n5. Link Extraction Performance:\n";
    benchmark_link_extraction($parser, $test_html, $test_url);
    
    # Benchmark 6: Metadata extraction
    print "\n6. Metadata Extraction Performance:\n";
    benchmark_metadata_extraction($parser, $test_html);
    
    print "\n" . "="x60 . "\n\n";
}

print "Benchmark suite completed!\n";

# Benchmark functions

sub setup_test_html {
    my ($helper, $dataset) = @_;
    
    print "Generating test HTML...\n";
    
    my $start_time = time();
    
    my $html;
    if ($dataset->{complexity} eq 'low') {
        $html = generate_simple_html($helper);
    } elsif ($dataset->{complexity} eq 'medium') {
        $html = generate_medium_html($helper);
    } else {
        $html = generate_complex_html($helper);
    }
    
    my $setup_time = time() - $start_time;
    my $html_size = length($html);
    
    printf "Generated HTML: %.2fKB (%.3fs)\n", $html_size/1024, $setup_time;
    
    return $html;
}

sub generate_simple_html {
    my ($helper) = @_;
    
    return qq{
<!DOCTYPE html>
<html>
<head>
    <title>Simple Test Article - Wikipedia</title>
</head>
<body>
    <h1 class="firstHeading">Simple Test Article</h1>
    <div id="mw-content-text">
        <p>This is a simple test article for benchmarking the parser. It contains basic content without complex structures.</p>
        <p>The article discusses various topics including <a href="/wiki/Programming">programming</a> and <a href="/wiki/Algorithms">algorithms</a>.</p>
        <p>This paragraph contains more information about the subject matter.</p>
        
        <h2>Simple Section</h2>
        <p>This is content under a simple section heading.</p>
        
        <div class="mw-references-wrap">
            <ol class="references">
                <li>Reference 1</li>
                <li>Reference 2</li>
            </ol>
        </div>
    </div>
    
    <div id="catlinks">
        <div class="mw-normal-catlinks">
            <a href="/wiki/Category:Test_Articles">Test Articles</a>
            <a href="/wiki/Category:Programming">Programming</a>
        </div>
    </div>
</body>
</html>
    };
}

sub generate_medium_html {
    my ($helper) = @_;
    
    my $content = generate_sample_content(1000);
    my @sections = ("Introduction", "History", "Applications", "See also");
    
    my $html = qq{
<!DOCTYPE html>
<html>
<head>
    <title>Medium Test Article - Wikipedia</title>
</head>
<body>
    <h1 class="firstHeading">Medium Test Article</h1>
    <div id="mw-content-text">
        <table class="infobox">
            <tr><th>Type</th><td>Test Article</td></tr>
            <tr><th>Category</th><td>Programming</td></tr>
            <tr><th>Complexity</th><td>Medium</td></tr>
        </table>
        
        <p>$content</p>
    };
    
    # Add sections
    for my $section (@sections) {
        my $section_content = generate_sample_content(300);
        $html .= qq{
        <h2>$section</h2>
        <p>$section_content</p>
        };
        
        # Add some links in each section
        for my $i (1..5) {
            my $link_title = "Related Article $i";
            $html .= qq{<p>See also <a href="/wiki/$link_title">$link_title</a> for more information.</p>};
        }
    }
    
    $html .= qq{
        <div class="thumb">
            <img src="/wiki/test_image.jpg" alt="Test Image" width="200" height="150">
        </div>
        
        <div class="mw-references-wrap">
            <ol class="references">
    };
    
    # Add references
    for my $i (1..10) {
        $html .= qq{<li>Reference $i content</li>};
    }
    
    $html .= qq{
            </ol>
        </div>
    </div>
    
    <div id="catlinks">
        <div class="mw-normal-catlinks">
            <a href="/wiki/Category:Test_Articles">Test Articles</a>
            <a href="/wiki/Category:Programming">Programming</a>
            <a href="/wiki/Category:Computer_Science">Computer Science</a>
            <a href="/wiki/Category:Algorithms">Algorithms</a>
        </div>
    </div>
</body>
</html>
    };
    
    return $html;
}

sub generate_complex_html {
    my ($helper) = @_;
    
    my @sections = (
        "Introduction", "History", "Early Development", "Modern Applications",
        "Technical Details", "Implementation", "Performance", "Comparison",
        "Future Directions", "Criticism", "See also", "References"
    );
    
    my $html = qq{
<!DOCTYPE html>
<html>
<head>
    <title>Complex Test Article - Wikipedia</title>
</head>
<body>
    <h1 class="firstHeading">Complex Test Article</h1>
    <div id="mw-content-text">
        <table class="infobox">
            <tr><th colspan="2">Complex Test Article</th></tr>
            <tr><th>Type</th><td>Advanced Algorithm</td></tr>
            <tr><th>Invented</th><td>1970s</td></tr>
            <tr><th>Applications</th><td>Computer Science, Mathematics</td></tr>
            <tr><th>Complexity</th><td>O(n log n)</td></tr>
            <tr><th>Space</th><td>O(n)</td></tr>
        </table>
        
        <p>This is a complex test article with extensive content for benchmarking parser performance.</p>
    };
    
    # Add many sections with subsections
    for my $section (@sections) {
        my $main_content = generate_sample_content(800);
        $html .= qq{
        <h2>$section</h2>
        <p>$main_content</p>
        };
        
        # Add subsections
        for my $sub_i (1..3) {
            my $sub_content = generate_sample_content(400);
            $html .= qq{
            <h3>$section Subsection $sub_i</h3>
            <p>$sub_content</p>
            };
            
            # Add many links
            for my $link_i (1..10) {
                my $link_title = "${section}_Related_Article_$link_i";
                $link_title =~ s/\s+/_/g;
                $html .= qq{<p>Related: <a href="/wiki/$link_title">$link_title</a></p>};
            }
        }
    }
    
    # Add many images
    for my $img_i (1..5) {
        $html .= qq{
        <div class="thumb">
            <img src="/wiki/complex_image_$img_i.jpg" alt="Complex Image $img_i" width="300" height="200">
        </div>
        };
    }
    
    # Add coordinates
    $html .= qq{
        <span class="geo">40.7128; -74.0060</span>
    };
    
    # Add extensive references
    $html .= qq{
        <div class="mw-references-wrap">
            <ol class="references">
    };
    
    for my $ref_i (1..50) {
        $html .= qq{<li>Reference $ref_i with detailed citation information</li>};
    }
    
    $html .= qq{
            </ol>
        </div>
    </div>
    
    <div id="catlinks">
        <div class="mw-normal-catlinks">
    };
    
    # Add many categories
    my @categories = qw(
        Test_Articles Programming Computer_Science Algorithms Mathematics
        Software_Engineering Data_Structures Complexity_Theory Performance
        Academic_Research Technical_Documentation
    );
    
    for my $cat (@categories) {
        $html .= qq{<a href="/wiki/Category:$cat">$cat</a> };
    }
    
    $html .= qq{
        </div>
    </div>
</body>
</html>
    };
    
    return $html;
}

sub generate_sample_content {
    my ($length) = @_;
    
    my @words = qw(
        algorithm implementation performance optimization analysis design
        structure data processing computation efficiency scalability
        methodology approach technique strategy framework architecture
        development research investigation study examination exploration
        theory practice application utilization deployment integration
    );
    
    my $content = "";
    while (length($content) < $length) {
        my $word = $words[int(rand(@words))];
        $content .= "$word ";
    }
    
    return substr($content, 0, $length);
}

sub benchmark_complete_parsing {
    my ($parser, $test_html, $test_url) = @_;
    
    my $results = timethese(-3, {
        'complete_parse' => sub {
            my $data = $parser->parse_page($test_html, $test_url);
        },
        'parse_no_chunks' => sub {
            # Temporarily disable chunking for comparison
            local *Tessera::Parser::create_semantic_chunks = sub { return []; };
            my $data = $parser->parse_page($test_html, $test_url);
        }
    });
    
    print_benchmark_results($results, "Complete Parsing");
}

sub benchmark_extraction_methods {
    my ($parser, $test_html, $test_url) = @_;
    
    # Create HTML tree once for reuse
    require HTML::TreeBuilder;
    my $tree = HTML::TreeBuilder->new();
    $tree->parse_content($test_html);
    $tree->eof();
    
    my $results = timethese(-3, {
        'extract_title' => sub {
            my $title = $parser->_extract_title($tree);
        },
        'extract_content' => sub {
            my $content = $parser->_extract_main_content($tree);
        },
        'extract_summary' => sub {
            my $summary = $parser->_extract_summary($tree);
        },
        'extract_infobox' => sub {
            my $infobox = $parser->_extract_infobox($tree);
        },
        'extract_categories' => sub {
            my $categories = $parser->_extract_categories($tree);
        },
        'extract_sections' => sub {
            my $sections = $parser->_extract_sections($tree);
        }
    });
    
    $tree->delete();
    print_benchmark_results($results, "Individual Extraction");
}

sub benchmark_content_processing {
    my ($parser, $test_html) = @_;
    
    require HTML::TreeBuilder;
    my $tree = HTML::TreeBuilder->new();
    $tree->parse_content($test_html);
    $tree->eof();
    
    my $content_elem = $tree->look_down('_tag' => 'div', 'id' => 'mw-content-text');
    
    my $results = timethese(-3, {
        'clean_content' => sub {
            # Create a copy for cleaning
            my $copy = $content_elem->clone() if $content_elem;
            $parser->_clean_content($copy) if $copy;
            $copy->delete() if $copy;
        },
        'extract_text' => sub {
            my $text = $content_elem ? $content_elem->as_text : '';
        }
    });
    
    $tree->delete();
    print_benchmark_results($results, "Content Processing");
}

sub benchmark_semantic_chunking {
    my ($parser, $test_html, $test_url) = @_;
    
    # First parse the page to get article data
    my $article_data = $parser->parse_page($test_html, $test_url);
    
    my $results = timethese(-3, {
        'create_chunks' => sub {
            my $chunks = $parser->create_semantic_chunks($article_data);
        },
        'estimate_tokens' => sub {
            my $content = $article_data->{content} || '';
            my $tokens = $parser->_estimate_tokens($content);
        },
        'chunk_by_paragraphs' => sub {
            my $content = $article_data->{content} || '';
            my $chunks = $parser->_chunk_by_paragraphs($content);
        }
    });
    
    print_benchmark_results($results, "Semantic Chunking");
}

sub benchmark_link_extraction {
    my ($parser, $test_html, $test_url) = @_;
    
    require HTML::TreeBuilder;
    my $tree = HTML::TreeBuilder->new();
    $tree->parse_content($test_html);
    $tree->eof();
    
    my $results = timethese(-3, {
        'extract_links' => sub {
            my $links = $parser->_extract_links($tree, $test_url);
        },
        'extract_images' => sub {
            my $images = $parser->_extract_images($tree);
        }
    });
    
    $tree->delete();
    print_benchmark_results($results, "Link Extraction");
}

sub benchmark_metadata_extraction {
    my ($parser, $test_html) = @_;
    
    require HTML::TreeBuilder;
    my $tree = HTML::TreeBuilder->new();
    $tree->parse_content($test_html);
    $tree->eof();
    
    my $results = timethese(-3, {
        'extract_coordinates' => sub {
            my $coords = $parser->_extract_coordinates($tree);
        },
        'extract_infobox' => sub {
            my $infobox = $parser->_extract_infobox($tree);
        },
        'extract_categories' => sub {
            my $categories = $parser->_extract_categories($tree);
        }
    });
    
    $tree->delete();
    print_benchmark_results($results, "Metadata Extraction");
}

sub print_benchmark_results {
    my ($results, $category) = @_;
    
    print "\n$category Results:\n";
    print "-" x 50 . "\n";
    
    for my $test_name (sort keys %$results) {
        my $result = $results->{$test_name};
        my $rate = $result->iters / $result->cpu_a;
        my $time_per_op = $result->cpu_a / $result->iters;
        
        printf "%-20s: %8.2f ops/sec (%.4fs per op)\n", 
               $test_name, $rate, $time_per_op;
    }
}

# Scaling analysis
sub analyze_parsing_scalability {
    my ($parser) = @_;
    
    print "\nParsing Scalability Analysis:\n";
    print "-" x 40 . "\n";
    
    # Test with different HTML sizes
    my @sizes = (1000, 5000, 10000, 50000, 100000); # bytes
    
    for my $size (@sizes) {
        my $test_html = generate_html_of_size($size);
        my $test_url = "https://en.wikipedia.org/wiki/Test";
        
        my $start_time = time();
        my $data = $parser->parse_page($test_html, $test_url);
        my $duration = time() - $start_time;
        
        my $rate = $size / $duration;
        printf "Size %6d bytes: %8.2f bytes/sec (%.4fs total)\n", 
               $size, $rate, $duration;
    }
}

sub generate_html_of_size {
    my ($target_size) = @_;
    
    my $base_html = qq{
<!DOCTYPE html>
<html>
<head><title>Test Article - Wikipedia</title></head>
<body>
<h1 class="firstHeading">Test Article</h1>
<div id="mw-content-text">
<p>This is test content. };
    
    my $end_html = qq{</p>
</div>
</body>
</html>};
    
    my $current_size = length($base_html) + length($end_html);
    my $content_needed = $target_size - $current_size;
    
    if ($content_needed > 0) {
        my $filler = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " x int($content_needed / 57);
        $base_html .= $filler;
    }
    
    return $base_html . $end_html;
}

# Memory profiling
sub profile_memory_usage {
    my ($parser, $test_html, $test_url) = @_;
    
    print "\nMemory Usage Profile:\n";
    print "-" x 30 . "\n";
    
    my $initial_memory = get_memory_usage();
    
    # Parse multiple times and track memory
    for my $iteration (1..5) {
        my $data = $parser->parse_page($test_html, $test_url);
        
        my $current_memory = get_memory_usage();
        my $memory_delta = $current_memory - $initial_memory;
        
        printf "Iteration %d: %+.2fMB\n", 
               $iteration, $memory_delta / (1024*1024);
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

03-parser-bench.pl - Benchmark suite for Tessera::Parser

=head1 DESCRIPTION

This benchmark suite tests the performance of various Parser operations:

- Complete page parsing performance
- Individual extraction methods
- Content processing and cleaning
- Semantic chunking (RAG functionality)
- Link and image extraction
- Metadata extraction

=head1 USAGE

    cd backend/perl-backend
    perl benchmarks/03-parser-bench.pl

=head1 BENCHMARKS

=head2 Complete Page Parsing

Tests full page parsing performance:
- Complete parsing with all features
- Parsing without semantic chunking

=head2 Individual Extraction Methods

Tests specific extraction functions:
- Title extraction
- Content extraction
- Summary extraction
- Infobox parsing
- Category extraction
- Section extraction

=head2 Content Processing

Tests content cleaning and processing:
- HTML cleaning operations
- Text extraction

=head2 Semantic Chunking

Tests RAG-related functionality:
- Semantic chunk creation
- Token estimation
- Paragraph-based chunking

=head2 Link Extraction

Tests link and media extraction:
- Wikipedia link extraction
- Image extraction and filtering

=head2 Metadata Extraction

Tests metadata parsing:
- Coordinate extraction
- Infobox processing
- Category parsing

=head1 AUTHOR

Tessera Project

=cut
