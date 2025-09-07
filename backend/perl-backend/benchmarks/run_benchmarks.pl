#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../t/lib";

use Getopt::Long;
use Pod::Usage;
use Time::HiRes qw(time);
use File::Spec;
use YAML::XS qw(LoadFile DumpFile);
use JSON::XS;
use Term::ANSIColor qw(colored);

# Command line options
my %options = (
    help => 0,
    verbose => 0,
    output => '',
    format => 'text',
    suite => 'all',
    iterations => 3,
    config => '',
    profile => 0,
    compare => '',
);

GetOptions(
    'help|h'        => \$options{help},
    'verbose|v'     => \$options{verbose},
    'output|o=s'    => \$options{output},
    'format|f=s'    => \$options{format},
    'suite|s=s'     => \$options{suite},
    'iterations|i=i' => \$options{iterations},
    'config|c=s'    => \$options{config},
    'profile|p'     => \$options{profile},
    'compare=s'     => \$options{compare},
) or pod2usage(2);

pod2usage(1) if $options{help};

# Validate options
die "Invalid format: $options{format}. Must be one of: text, json, yaml, html\n" 
    unless $options{format} =~ /^(text|json|yaml|html)$/;

# Available benchmark suites
my %benchmark_suites = (
    'knowledgegraph' => {
        script => '01-knowledgegraph-bench.pl',
        name => 'KnowledgeGraph Calculations',
        description => 'Graph building, metrics, centrality measures'
    },
    'linkanalyzer' => {
        script => '02-linkanalyzer-bench.pl',
        name => 'LinkAnalyzer Calculations',
        description => 'Relevance scoring, interest matching, filtering'
    },
    'parser' => {
        script => '03-parser-bench.pl',
        name => 'Parser Calculations',
        description => 'HTML parsing, content extraction, chunking'
    },
    'apiserver' => {
        script => '04-api-server-bench.pl',
        name => 'API Server Calculations',
        description => 'Content weighting, learning analytics, brain stats'
    }
);

print colored("=== Tessera Perl Calculation Benchmarks ===\n", 'bold blue');
print colored("Benchmark Runner v1.0\n\n", 'cyan');

# Determine which suites to run
my @suites_to_run;
if ($options{suite} eq 'all') {
    @suites_to_run = sort keys %benchmark_suites;
} else {
    my @requested = split /,/, $options{suite};
    for my $suite (@requested) {
        if (exists $benchmark_suites{$suite}) {
            push @suites_to_run, $suite;
        } else {
            warn colored("Warning: Unknown benchmark suite '$suite'\n", 'yellow');
        }
    }
}

die colored("No valid benchmark suites specified\n", 'red') unless @suites_to_run;

# Load configuration if specified
my $config = {};
if ($options{config} && -f $options{config}) {
    $config = LoadFile($options{config});
    print colored("Loaded configuration from: $options{config}\n", 'green');
}

# Initialize results storage
my %results = (
    metadata => {
        timestamp => time(),
        hostname => `hostname` || 'unknown',
        perl_version => $^V,
        os => $^O,
        iterations => $options{iterations},
        suites_run => \@suites_to_run,
    },
    benchmarks => {}
);

chomp $results{metadata}{hostname};

print colored("Running benchmark suites: " . join(', ', @suites_to_run) . "\n", 'cyan');
print colored("Output format: $options{format}\n", 'cyan');
print colored("Iterations per test: $options{iterations}\n", 'cyan');
print "\n";

# Run each benchmark suite
my $total_start_time = time();

for my $suite_name (@suites_to_run) {
    my $suite = $benchmark_suites{$suite_name};
    
    print colored("Running $suite->{name}...\n", 'bold green');
    print colored("Description: $suite->{description}\n", 'white');
    
    my $suite_start_time = time();
    
    # Construct the command to run the benchmark
    my $script_path = File::Spec->catfile($FindBin::Bin, $suite->{script});
    
    unless (-f $script_path) {
        warn colored("Error: Benchmark script not found: $script_path\n", 'red');
        next;
    }
    
    # Capture output from benchmark script
    my $output = '';
    my $error = '';
    
    if ($options{verbose}) {
        print colored("Executing: perl $script_path\n", 'yellow');
    }
    
    # Run the benchmark and capture output
    my $cmd = "cd $FindBin::Bin/.. && perl benchmarks/$suite->{script} 2>&1";
    $output = `$cmd`;
    my $exit_code = $? >> 8;
    
    my $suite_duration = time() - $suite_start_time;
    
    if ($exit_code != 0) {
        warn colored("Error running $suite->{name} (exit code: $exit_code)\n", 'red');
        if ($options{verbose}) {
            print colored("Output:\n$output\n", 'red');
        }
        next;
    }
    
    # Parse benchmark results from output
    my $parsed_results = parse_benchmark_output($output);
    
    $results{benchmarks}{$suite_name} = {
        name => $suite->{name},
        description => $suite->{description},
        duration => $suite_duration,
        results => $parsed_results,
        raw_output => $options{verbose} ? $output : undef,
    };
    
    printf colored("Completed in %.2fs\n", 'green'), $suite_duration;
    print "\n";
}

my $total_duration = time() - $total_start_time;
$results{metadata}{total_duration} = $total_duration;

print colored("All benchmarks completed in " . sprintf("%.2fs", $total_duration) . "\n", 'bold green');

# Generate output
if ($options{output}) {
    save_results(\%results, $options{output}, $options{format});
    print colored("Results saved to: $options{output}\n", 'cyan');
} else {
    display_results(\%results, $options{format});
}

# Compare with previous results if requested
if ($options{compare} && -f $options{compare}) {
    print colored("\nComparing with previous results...\n", 'bold yellow');
    compare_results(\%results, $options{compare});
}

# Performance profiling if requested
if ($options{profile}) {
    print colored("\nGenerating performance profile...\n", 'bold yellow');
    generate_performance_profile(\%results);
}

print colored("\nBenchmark run completed successfully!\n", 'bold green');

# Helper functions

sub parse_benchmark_output {
    my ($output) = @_;
    
    my %parsed;
    my $current_category = '';
    
    for my $line (split /\n/, $output) {
        # Look for category headers
        if ($line =~ /^=== (.+) ===/) {
            $current_category = $1;
            next;
        }
        
        # Look for benchmark results
        if ($line =~ /^(\w+(?:_\w+)*)\s*:\s*([\d.]+)\s+ops\/sec\s*\(([\d.]+)s per op\)/) {
            my ($test_name, $ops_per_sec, $time_per_op) = ($1, $2, $3);
            
            $parsed{$current_category}{$test_name} = {
                ops_per_sec => $ops_per_sec + 0,
                time_per_op => $time_per_op + 0,
            };
        }
    }
    
    return \%parsed;
}

sub save_results {
    my ($results, $filename, $format) = @_;
    
    if ($format eq 'json') {
        my $json = JSON::XS->new->pretty->encode($results);
        open my $fh, '>', $filename or die "Cannot write to $filename: $!";
        print $fh $json;
        close $fh;
    } elsif ($format eq 'yaml') {
        DumpFile($filename, $results);
    } elsif ($format eq 'html') {
        generate_html_report($results, $filename);
    } else {
        # Default to text format
        open my $fh, '>', $filename or die "Cannot write to $filename: $!";
        print $fh format_text_results($results);
        close $fh;
    }
}

sub display_results {
    my ($results, $format) = @_;
    
    if ($format eq 'json') {
        my $json = JSON::XS->new->pretty->encode($results);
        print $json;
    } elsif ($format eq 'yaml') {
        print Dump($results);
    } else {
        print format_text_results($results);
    }
}

sub format_text_results {
    my ($results) = @_;
    
    my $output = "\n" . "="x60 . "\n";
    $output .= "BENCHMARK RESULTS SUMMARY\n";
    $output .= "="x60 . "\n\n";
    
    $output .= sprintf "Timestamp: %s\n", scalar(localtime($results->{metadata}{timestamp}));
    $output .= sprintf "Hostname: %s\n", $results->{metadata}{hostname};
    $output .= sprintf "Perl Version: %s\n", $results->{metadata}{perl_version};
    $output .= sprintf "OS: %s\n", $results->{metadata}{os};
    $output .= sprintf "Total Duration: %.2fs\n", $results->{metadata}{total_duration};
    $output .= "\n";
    
    for my $suite_name (sort keys %{$results->{benchmarks}}) {
        my $suite = $results->{benchmarks}{$suite_name};
        
        $output .= "-"x50 . "\n";
        $output .= sprintf "%s\n", uc($suite->{name});
        $output .= sprintf "Duration: %.2fs\n", $suite->{duration};
        $output .= "-"x50 . "\n\n";
        
        for my $category (sort keys %{$suite->{results}}) {
            $output .= sprintf "  %s:\n", $category;
            
            for my $test (sort keys %{$suite->{results}{$category}}) {
                my $result = $suite->{results}{$category}{$test};
                $output .= sprintf "    %-25s: %8.2f ops/sec (%.4fs per op)\n",
                    $test, $result->{ops_per_sec}, $result->{time_per_op};
            }
            $output .= "\n";
        }
    }
    
    return $output;
}

sub generate_html_report {
    my ($results, $filename) = @_;
    
    my $html = qq{<!DOCTYPE html>
<html>
<head>
    <title>Tessera Perl Benchmarks Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
        .suite { margin: 20px 0; border: 1px solid #ddd; border-radius: 5px; }
        .suite-header { background: #e0e0e0; padding: 10px; font-weight: bold; }
        .category { margin: 10px; }
        .category-header { font-weight: bold; color: #333; margin: 10px 0 5px 0; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; }
        .number { text-align: right; font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Tessera Perl Benchmarks Report</h1>
        <p><strong>Generated:</strong> } . scalar(localtime($results->{metadata}{timestamp})) . qq{</p>
        <p><strong>Hostname:</strong> $results->{metadata}{hostname}</p>
        <p><strong>Perl Version:</strong> $results->{metadata}{perl_version}</p>
        <p><strong>Total Duration:</strong> } . sprintf("%.2fs", $results->{metadata}{total_duration}) . qq{</p>
    </div>
};
    
    for my $suite_name (sort keys %{$results->{benchmarks}}) {
        my $suite = $results->{benchmarks}{$suite_name};
        
        $html .= qq{
    <div class="suite">
        <div class="suite-header">$suite->{name}</div>
        <p><em>$suite->{description}</em></p>
        <p><strong>Duration:</strong> } . sprintf("%.2fs", $suite->{duration}) . qq{</p>
};
        
        for my $category (sort keys %{$suite->{results}}) {
            $html .= qq{
        <div class="category">
            <div class="category-header">$category</div>
            <table>
                <tr><th>Test</th><th>Ops/Sec</th><th>Time/Op</th></tr>
};
            
            for my $test (sort keys %{$suite->{results}{$category}}) {
                my $result = $suite->{results}{$category}{$test};
                $html .= sprintf qq{
                <tr>
                    <td>%s</td>
                    <td class="number">%.2f</td>
                    <td class="number">%.4fs</td>
                </tr>
}, $test, $result->{ops_per_sec}, $result->{time_per_op};
            }
            
            $html .= qq{
            </table>
        </div>
};
        }
        
        $html .= qq{
    </div>
};
    }
    
    $html .= qq{
</body>
</html>
};
    
    open my $fh, '>', $filename or die "Cannot write to $filename: $!";
    print $fh $html;
    close $fh;
}

sub compare_results {
    my ($current_results, $previous_file) = @_;
    
    my $previous_results;
    
    if ($previous_file =~ /\.json$/) {
        my $json_text = do {
            open my $fh, '<', $previous_file or die "Cannot read $previous_file: $!";
            local $/;
            <$fh>;
        };
        $previous_results = JSON::XS->new->decode($json_text);
    } elsif ($previous_file =~ /\.ya?ml$/) {
        $previous_results = LoadFile($previous_file);
    } else {
        warn colored("Cannot compare: unsupported file format for $previous_file\n", 'yellow');
        return;
    }
    
    print colored("Comparison Results:\n", 'bold');
    print colored("-" x 40 . "\n", 'white');
    
    for my $suite_name (sort keys %{$current_results->{benchmarks}}) {
        next unless exists $previous_results->{benchmarks}{$suite_name};
        
        my $current_suite = $current_results->{benchmarks}{$suite_name};
        my $previous_suite = $previous_results->{benchmarks}{$suite_name};
        
        print colored("$current_suite->{name}:\n", 'bold');
        
        for my $category (sort keys %{$current_suite->{results}}) {
            next unless exists $previous_suite->{results}{$category};
            
            print colored("  $category:\n", 'white');
            
            for my $test (sort keys %{$current_suite->{results}{$category}}) {
                next unless exists $previous_suite->{results}{$category}{$test};
                
                my $current_ops = $current_suite->{results}{$category}{$test}{ops_per_sec};
                my $previous_ops = $previous_suite->{results}{$category}{$test}{ops_per_sec};
                
                my $change_percent = (($current_ops - $previous_ops) / $previous_ops) * 100;
                my $change_color = $change_percent > 5 ? 'green' : 
                                  $change_percent < -5 ? 'red' : 'white';
                
                printf colored("    %-25s: %+6.1f%% (%.2f -> %.2f ops/sec)\n", $change_color),
                    $test, $change_percent, $previous_ops, $current_ops;
            }
        }
        print "\n";
    }
}

sub generate_performance_profile {
    my ($results) = @_;
    
    print colored("Performance Profile:\n", 'bold');
    print colored("-" x 30 . "\n", 'white');
    
    # Find fastest and slowest operations
    my @all_ops;
    
    for my $suite_name (keys %{$results->{benchmarks}}) {
        my $suite = $results->{benchmarks}{$suite_name};
        
        for my $category (keys %{$suite->{results}}) {
            for my $test (keys %{$suite->{results}{$category}}) {
                my $result = $suite->{results}{$category}{$test};
                push @all_ops, {
                    suite => $suite_name,
                    category => $category,
                    test => $test,
                    ops_per_sec => $result->{ops_per_sec},
                    time_per_op => $result->{time_per_op},
                };
            }
        }
    }
    
    # Sort by operations per second
    @all_ops = sort { $b->{ops_per_sec} <=> $a->{ops_per_sec} } @all_ops;
    
    print colored("Top 10 Fastest Operations:\n", 'green');
    for my $i (0..9) {
        last unless $all_ops[$i];
        my $op = $all_ops[$i];
        printf "  %2d. %-15s %-20s %-25s: %8.2f ops/sec\n",
            $i+1, $op->{suite}, $op->{category}, $op->{test}, $op->{ops_per_sec};
    }
    
    print colored("\nTop 10 Slowest Operations:\n", 'red');
    for my $i (-10..-1) {
        last unless $all_ops[$i];
        my $op = $all_ops[$i];
        printf "  %2d. %-15s %-20s %-25s: %8.2f ops/sec\n",
            abs($i), $op->{suite}, $op->{category}, $op->{test}, $op->{ops_per_sec};
    }
}

__END__

=head1 NAME

run_benchmarks.pl - Tessera Perl Calculation Benchmark Runner

=head1 SYNOPSIS

    perl run_benchmarks.pl [options]

    Options:
        -h, --help              Show this help message
        -v, --verbose           Verbose output
        -o, --output FILE       Save results to file
        -f, --format FORMAT     Output format (text, json, yaml, html)
        -s, --suite SUITE       Run specific suite(s) (comma-separated)
        -i, --iterations N      Number of iterations per test (default: 3)
        -c, --config FILE       Load configuration from file
        -p, --profile           Generate performance profile
        --compare FILE          Compare with previous results

=head1 DESCRIPTION

This script runs comprehensive benchmarks for Tessera Perl calculations including:

- KnowledgeGraph calculations (graph building, metrics, centrality)
- LinkAnalyzer calculations (relevance scoring, filtering)
- Parser calculations (HTML parsing, content extraction, chunking)
- API Server calculations (content weighting, learning analytics)

=head1 OPTIONS

=over 4

=item B<-h, --help>

Show help message and exit.

=item B<-v, --verbose>

Enable verbose output including raw benchmark output.

=item B<-o, --output FILE>

Save results to the specified file. Format is determined by file extension or --format option.

=item B<-f, --format FORMAT>

Output format: text (default), json, yaml, or html.

=item B<-s, --suite SUITE>

Run specific benchmark suite(s). Available suites:
- knowledgegraph: Graph building and analysis
- linkanalyzer: Link relevance calculations
- parser: HTML parsing and content processing
- apiserver: API server calculations
- all: Run all suites (default)

Multiple suites can be specified comma-separated: --suite knowledgegraph,parser

=item B<-i, --iterations N>

Number of iterations per benchmark test (default: 3).

=item B<-c, --config FILE>

Load configuration from YAML file.

=item B<-p, --profile>

Generate performance profile showing fastest and slowest operations.

=item B<--compare FILE>

Compare current results with previous results from file (JSON or YAML format).

=back

=head1 EXAMPLES

    # Run all benchmarks with default settings
    perl run_benchmarks.pl

    # Run specific suites with verbose output
    perl run_benchmarks.pl -v -s knowledgegraph,parser

    # Save results to JSON file
    perl run_benchmarks.pl -o results.json -f json

    # Generate HTML report
    perl run_benchmarks.pl -o report.html -f html

    # Compare with previous results
    perl run_benchmarks.pl -o current.json --compare previous.json

    # Run with performance profiling
    perl run_benchmarks.pl -p -v

=head1 OUTPUT FORMATS

=over 4

=item B<text>

Human-readable text format (default for console output).

=item B<json>

JSON format suitable for programmatic processing.

=item B<yaml>

YAML format for configuration and data exchange.

=item B<html>

HTML report with tables and styling.

=back

=head1 AUTHOR

Tessera Project

=cut
