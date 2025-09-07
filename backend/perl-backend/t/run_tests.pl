#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::Harness;

# Test runner script for Tessera backend

print "Running Tessera Backend Tests\n";
print "=" x 40 . "\n";

# Set test environment
$ENV{PERL_TEST_HARNESS_DUMP_TAP} = 1 if $ENV{DEBUG_TESTS};

# Find all test files
my @test_files = glob("$FindBin::Bin/*.t");
@test_files = sort @test_files;

if (@test_files == 0) {
    print "No test files found in $FindBin::Bin\n";
    exit 1;
}

print "Found " . @test_files . " test files:\n";
for my $test (@test_files) {
    my $basename = (split '/', $test)[-1];
    print "  - $basename\n";
}
print "\n";

# Run the tests
runtests(@test_files);

print "\nTest run completed.\n";
