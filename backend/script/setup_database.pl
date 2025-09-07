#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";

use WikiCrawler::Storage;
use YAML::XS qw(LoadFile);
use Getopt::Long qw(GetOptions);
use Pod::Usage qw(pod2usage);

# Command-line options
my %opts = (
    config => "$FindBin::Bin/../config/crawler.yaml",
    force => 0,
    help => 0,
);

GetOptions(
    'config|c=s' => \$opts{config},
    'force|f' => \$opts{force},
    'help|h' => \$opts{help},
) or pod2usage(2);

pod2usage(1) if $opts{help};

print "WikiCrawler Database Setup\n";
print "=" x 30 . "\n";

# Load configuration
my $config = LoadFile($opts{config});
my $db_path = $config->{database}{path};

print "Database path: $db_path\n";

# Check if database already exists
if (-f $db_path && !$opts{force}) {
    print "Database already exists. Use --force to recreate.\n";
    exit 1;
}

# Remove existing database if force option is used
if (-f $db_path && $opts{force}) {
    print "Removing existing database...\n";
    unlink $db_path or die "Cannot remove $db_path: $!";
}

# Create storage instance (this will initialize the database)
print "Creating database schema...\n";
my $storage = WikiCrawler::Storage->new(config => $config);

print "Database setup completed successfully!\n";
print "\nCreated tables:\n";
print "  - articles (for storing Wikipedia articles)\n";
print "  - links (for the knowledge graph connections)\n";
print "  - interest_profiles (for managing interests)\n";
print "  - crawl_sessions (for tracking crawl sessions)\n";

print "\nNext steps:\n";
print "1. Start crawling: perl bin/wikicrawler --start-title 'Your Topic'\n";
print "2. Start API server: perl script/api_server.pl\n";
print "3. View statistics: perl bin/wikicrawler --stats\n";

__END__

=head1 NAME

setup_database.pl - Initialize WikiCrawler database

=head1 SYNOPSIS

setup_database.pl [options]

=head1 DESCRIPTION

This script initializes the SQLite database for WikiCrawler, creating all
necessary tables and indexes.

=head1 OPTIONS

=over 4

=item B<--config, -c FILENAME>

Use specified configuration file (default: config/crawler.yaml).

=item B<--force, -f>

Force recreation of database if it already exists.

=item B<--help, -h>

Show help message.

=back

=head1 AUTHOR

WikiCrawler Project

=cut
