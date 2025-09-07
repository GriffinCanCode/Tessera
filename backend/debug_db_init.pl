#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/lib";

use Data::Dumper;
use YAML::XS qw(LoadFile);

print "=== Database Debug Script ===\n";

# Load configuration
print "1. Loading configuration...\n";
my $config_file = "$FindBin::Bin/config/crawler.yaml";
print "   Config file: $config_file\n";

my $config = LoadFile($config_file);
print "   Database path: " . $config->{database}{path} . "\n";

# Check if directory exists
my $db_path = $config->{database}{path};
my $db_dir = $db_path;
$db_dir =~ s/\/[^\/]*$//; # Remove filename to get directory
print "   Database directory: $db_dir\n";

if (-d $db_dir) {
    print "   ✓ Database directory exists\n";
} else {
    print "   ✗ Database directory does not exist\n";
    mkdir $db_dir or die "Cannot create directory $db_dir: $!";
    print "   ✓ Created database directory\n";
}

# Try to load WikiCrawler::Storage
print "\n2. Loading WikiCrawler::Storage...\n";
eval {
    require WikiCrawler::Storage;
    print "   ✓ WikiCrawler::Storage loaded successfully\n";
};
if ($@) {
    print "   ✗ Failed to load WikiCrawler::Storage: $@\n";
    exit 1;
}

# Try to create storage instance
print "\n3. Creating Storage instance...\n";
my $storage;
eval {
    $storage = WikiCrawler::Storage->new(config => $config);
    print "   ✓ Storage instance created\n";
};
if ($@) {
    print "   ✗ Failed to create Storage instance: $@\n";
    exit 1;
}

# Try to access dbh to trigger database creation
print "\n3.5. Accessing database handle (triggers DB creation)...\n";
eval {
    my $dbh = $storage->dbh;
    print "   ✓ Database handle accessed successfully\n";
};
if ($@) {
    print "   ✗ Failed to access database handle: $@\n";
    exit 1;
}

# Check if database file was created
print "\n4. Checking database file...\n";
if (-f $db_path) {
    my $size = -s $db_path;
    print "   ✓ Database file exists, size: $size bytes\n";
    
    if ($size > 0) {
        # Try to connect and list tables
        print "\n5. Testing database connection...\n";
        eval {
            my $dbh = $storage->dbh;
            print "   ✓ Database connection successful\n";
            
            my $tables = $dbh->selectcol_arrayref(
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
            );
            
            print "   Tables found:\n";
            for my $table (@$tables) {
                print "     - $table\n";
            }
        };
        if ($@) {
            print "   ✗ Database connection failed: $@\n";
        }
    } else {
        print "   ✗ Database file is empty\n";
    }
} else {
    print "   ✗ Database file was not created\n";
}

print "\n=== Debug Complete ===\n";
