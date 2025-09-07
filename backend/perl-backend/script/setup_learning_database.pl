#!/usr/bin/env perl

use strict;
use warnings;
use v5.20;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Tessera::Storage;
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

print "Personal Learning Tracker Database Setup\n";
print "=" x 40 . "\n";

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

# Create storage instance with new schema
print "Creating learning database schema...\n";
my $storage = Tessera::Storage->new(config => $config);

# Initialize learning-specific schema
_initialize_learning_schema($storage->dbh);

print "Learning database setup completed successfully!\n";
print "\nCreated tables:\n";
print "  - subjects (programming, cooking, etc.)\n";
print "  - learning_content (books, videos, articles, etc.)\n";
print "  - learning_progress (track what you've learned)\n";
print "  - content_chunks (for embeddings and RAG)\n";
print "  - subject_clusters (knowledge graph connections)\n";
print "  - learning_sessions (track study sessions)\n";

print "\nNext steps:\n";
print "1. Add learning content: Use the notebook interface\n";
print "2. Start learning services: ./start_all_services.sh\n";
print "3. Track your progress in the dashboard\n";

sub _initialize_learning_schema {
    my ($dbh) = @_;
    
    # Subjects table - main learning domains
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS subjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE, -- e.g., "Programming", "Cooking", "Machine Learning"
            description TEXT,
            color TEXT DEFAULT '#3b82f6', -- Hex color for UI visualization
            icon TEXT, -- Icon identifier for UI
            parent_subject_id INTEGER, -- For hierarchical subjects (e.g., "Python" under "Programming")
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (parent_subject_id) REFERENCES subjects(id)
        )
    });
    
    # Learning content table - replaces articles table
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS learning_content (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content_type TEXT NOT NULL, -- 'book', 'video', 'article', 'course', 'documentation'
            url TEXT, -- URL for web content, file path for local content
            content TEXT, -- Full text content (for books, articles)
            summary TEXT, -- AI-generated or manual summary
            metadata TEXT, -- JSON: author, duration, page_count, etc.
            source TEXT, -- 'manual', 'scraped', 'imported'
            difficulty_level INTEGER DEFAULT 1, -- 1-5 scale
            estimated_time_minutes INTEGER, -- Time to consume this content
            actual_time_minutes INTEGER DEFAULT 0, -- Time actually spent
            completion_percentage REAL DEFAULT 0, -- 0-100%
            rating INTEGER, -- Personal 1-5 star rating
            notes TEXT, -- Personal notes about this content
            tags TEXT, -- JSON array of tags
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER DEFAULT (strftime('%s', 'now'))
        )
    });
    
    # Content-subject relationships (many-to-many)
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS content_subjects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content_id INTEGER NOT NULL,
            subject_id INTEGER NOT NULL,
            relevance_score REAL DEFAULT 1.0, -- How relevant is this content to this subject
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (content_id) REFERENCES learning_content(id) ON DELETE CASCADE,
            FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
            UNIQUE(content_id, subject_id)
        )
    });
    
    # Learning progress tracking
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS learning_progress (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content_id INTEGER NOT NULL,
            session_date INTEGER DEFAULT (strftime('%s', 'now')),
            time_spent_minutes INTEGER DEFAULT 0,
            progress_delta REAL DEFAULT 0, -- Change in completion percentage this session
            comprehension_score INTEGER, -- 1-5 self-assessed comprehension
            session_notes TEXT, -- What was learned in this session
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (content_id) REFERENCES learning_content(id) ON DELETE CASCADE
        )
    });
    
    # Content chunks for embeddings (similar to article_chunks but content-agnostic)
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS content_chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content_id INTEGER NOT NULL,
            chunk_type TEXT NOT NULL, -- 'chapter', 'section', 'timestamp', 'page'
            chunk_identifier TEXT, -- Chapter name, timestamp, page number, etc.
            content_text TEXT NOT NULL,
            char_count INTEGER,
            token_count INTEGER,
            content_hash TEXT, -- SHA256 for change detection
            needs_embedding INTEGER DEFAULT 1,
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (content_id) REFERENCES learning_content(id) ON DELETE CASCADE
        )
    });
    
    # Embeddings for content chunks
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS content_embeddings (
            chunk_id INTEGER PRIMARY KEY,
            model_name TEXT NOT NULL,
            embedding_blob BLOB NOT NULL,
            embedding_dim INTEGER NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (chunk_id) REFERENCES content_chunks(id) ON DELETE CASCADE
        )
    });
    
    # Subject clusters - knowledge graph connections between subjects
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS subject_clusters (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_subject_id INTEGER NOT NULL,
            to_subject_id INTEGER NOT NULL,
            connection_type TEXT DEFAULT 'related', -- 'prerequisite', 'related', 'advanced'
            strength REAL DEFAULT 1.0, -- Connection strength
            notes TEXT, -- Why these subjects are connected
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (from_subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
            FOREIGN KEY (to_subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
            UNIQUE(from_subject_id, to_subject_id)
        )
    });
    
    # Learning sessions - track focused study sessions
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS learning_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_name TEXT, -- Optional name for the session
            subject_id INTEGER, -- Primary subject for this session
            start_time INTEGER DEFAULT (strftime('%s', 'now')),
            end_time INTEGER,
            total_minutes INTEGER DEFAULT 0,
            session_type TEXT DEFAULT 'study', -- 'study', 'practice', 'review'
            focus_level INTEGER, -- 1-5 self-assessed focus
            session_notes TEXT,
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (subject_id) REFERENCES subjects(id)
        )
    });
    
    # Session content - what content was studied in each session
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS session_content (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            content_id INTEGER NOT NULL,
            time_spent_minutes INTEGER DEFAULT 0,
            notes TEXT,
            FOREIGN KEY (session_id) REFERENCES learning_sessions(id) ON DELETE CASCADE,
            FOREIGN KEY (content_id) REFERENCES learning_content(id) ON DELETE CASCADE
        )
    });
    
    # Create indexes for performance
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_subjects_parent ON subjects(parent_subject_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_content_type ON learning_content(content_type)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_content_completion ON learning_content(completion_percentage)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_content_subjects_content ON content_subjects(content_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_content_subjects_subject ON content_subjects(subject_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_progress_content ON learning_progress(content_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_progress_date ON learning_progress(session_date)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_chunks_content ON content_chunks(content_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_chunks_needs_embedding ON content_chunks(needs_embedding)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_embeddings_model ON content_embeddings(model_name)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_clusters_from ON subject_clusters(from_subject_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_clusters_to ON subject_clusters(to_subject_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_sessions_subject ON learning_sessions(subject_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_sessions_date ON learning_sessions(start_time)");
    
    # Insert default subjects
    my $default_subjects = [
        {name => 'Programming', description => 'Software development and coding', color => '#10b981', icon => 'code'},
        {name => 'Cooking', description => 'Culinary arts and recipes', color => '#f59e0b', icon => 'chef-hat'},
        {name => 'Machine Learning', description => 'AI and data science', color => '#8b5cf6', icon => 'brain'},
        {name => 'Web Development', description => 'Frontend and backend web technologies', color => '#06b6d4', icon => 'globe'},
        {name => 'Data Science', description => 'Data analysis and visualization', color => '#ec4899', icon => 'chart-bar'},
        {name => 'Personal Development', description => 'Self-improvement and productivity', color => '#84cc16', icon => 'user'},
    ];
    
    my $sth = $dbh->prepare("INSERT OR IGNORE INTO subjects (name, description, color, icon) VALUES (?, ?, ?, ?)");
    for my $subject (@$default_subjects) {
        $sth->execute($subject->{name}, $subject->{description}, $subject->{color}, $subject->{icon});
    }
    
    print "Initialized learning schema with default subjects\n";
}

__END__

=head1 NAME

setup_learning_database.pl - Initialize Personal Learning Tracker database

=head1 SYNOPSIS

setup_learning_database.pl [options]

=head1 DESCRIPTION

This script initializes the SQLite database for the Personal Learning Tracker,
creating all necessary tables and indexes for tracking learning progress
across different subjects and content types.

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

Personal Learning Tracker Project

=cut
