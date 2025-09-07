#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/lib";

use YAML::XS qw(LoadFile);

print "Testing database creation...\n";

# Load config
my $config = LoadFile("$FindBin::Bin/config/crawler.yaml");
print "Config loaded, database path: " . $config->{database}{path} . "\n";

# Load DBI
use DBI;

# Try to create database manually 
my $db_path = $config->{database}{path};
print "Attempting to create database at: $db_path\n";

# Create directory if needed
use File::Path qw(make_path);
use File::Basename qw(dirname);
my $db_dir = dirname($db_path);
make_path($db_dir) unless -d $db_dir;

# Try direct DBI connection
print "Attempting DBI connection...\n";
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=$db_path",
    "", "",
    {
        RaiseError => 1,
        AutoCommit => 1,
        sqlite_unicode => 1,
        PrintError => 1,
    }
) or die "Cannot connect to database: " . DBI->errstr;

print "✓ DBI connection successful\n";

# Create a simple test table
$dbh->do("CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY, name TEXT)");
$dbh->do("INSERT INTO test (name) VALUES ('test')");

print "✓ Test table created\n";

# Check file exists
if (-f $db_path) {
    my $size = -s $db_path;
    print "✓ Database file exists, size: $size bytes\n";
} else {
    print "✗ Database file doesn't exist\n";
}

$dbh->disconnect;
print "Database test complete\n";
