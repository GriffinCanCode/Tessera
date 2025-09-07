package WikiCrawler::ProjectManager;

use strict;
use warnings;
use v5.20;

use Log::Log4perl;
use JSON::XS;
use Time::HiRes qw(time);

use Moo;
use namespace::clean;

# Attributes
has 'storage' => (
    is       => 'ro',
    required => 1,
);

has 'logger' => (
    is      => 'lazy',
    builder => '_build_logger',
);

has 'json' => (
    is      => 'lazy',
    builder => '_build_json',
);

has 'hash_manager' => (
    is      => 'lazy',
    builder => '_build_hash_manager',
);

sub _build_logger {
    my $self = shift;
    return Log::Log4perl->get_logger(__PACKAGE__);
}

sub _build_json {
    my $self = shift;
    return JSON::XS->new->utf8->pretty;
}

sub _build_hash_manager {
    my $self = shift;
    require WikiCrawler::HashManager;
    return WikiCrawler::HashManager->new();
}

# Initialize project system (extends existing schema)
sub initialize_project_schema {
    my ($self, $dbh) = @_;
    
    # Accept dbh as parameter to avoid circular dependency
    $dbh ||= $self->storage->dbh;
    
    # Projects table
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            description TEXT,
            color TEXT DEFAULT '#3b82f6', -- Hex color for UI
            settings TEXT, -- JSON settings (search preferences, etc.)
            is_default INTEGER DEFAULT 0, -- Is this the default project?
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER DEFAULT (strftime('%s', 'now'))
        )
    });
    
    # Create a default project if none exists
    my $default_project = $dbh->selectrow_hashref(
        "SELECT id FROM projects WHERE is_default = 1"
    );
    
    unless ($default_project) {
        $dbh->do(qq{
            INSERT INTO projects (name, description, color, is_default, settings)
            VALUES (?, ?, ?, ?, ?)
        }, {}, 
            'Default Project',
            'Your personal knowledge base',
            '#3b82f6',
            1,
            $self->json->encode({
                search_preferences => {
                    min_relevance => 0.3,
                    max_results => 50
                },
                rag_settings => {
                    chunk_overlap => 0.1,
                    similarity_threshold => 0.4
                }
            })
        );
        $self->logger->info("Created default project");
    }
    
    # Add project_id columns to existing tables (if not already exists)
    my @tables_needing_project_id = (
        'articles',
        'crawl_sessions',
        'interest_profiles'
    );
    
    for my $table (@tables_needing_project_id) {
        # Check if column already exists
        my $columns = $dbh->selectall_arrayref(
            "PRAGMA table_info($table)",
            { Slice => {} }
        );
        
        my $has_project_id = grep { $_->{name} eq 'project_id' } @$columns;
        
        unless ($has_project_id) {
            my $default_project_id = $self->get_default_project_id($dbh);
            
            # Add project_id column
            $dbh->do("ALTER TABLE $table ADD COLUMN project_id INTEGER DEFAULT $default_project_id");
            
            # Add foreign key constraint (for new data)
            if ($table eq 'articles') {
                # Articles need special handling for links table
                $dbh->do("CREATE INDEX IF NOT EXISTS idx_${table}_project_id ON $table(project_id)");
            } else {
                $dbh->do("CREATE INDEX IF NOT EXISTS idx_${table}_project_id ON $table(project_id)");
            }
            
            $self->logger->info("Added project_id column to $table");
        }
    }
    
    # Project-article relationships (many-to-many for shared articles)
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS project_articles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            article_id INTEGER NOT NULL,
            added_at INTEGER DEFAULT (strftime('%s', 'now')),
            added_via TEXT, -- 'crawl', 'manual', 'link'
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
            FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE,
            UNIQUE(project_id, article_id)
        )
    });
    
    # Project statistics cache
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS project_stats (
            project_id INTEGER PRIMARY KEY,
            article_count INTEGER DEFAULT 0,
            link_count INTEGER DEFAULT 0,
            chunk_count INTEGER DEFAULT 0,
            last_activity INTEGER,
            last_updated INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        )
    });
    
    # Create indexes
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_project_articles_project ON project_articles(project_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_project_articles_article ON project_articles(article_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_projects_default ON projects(is_default)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name)");
    
    $self->logger->info("Project schema initialized");
    return 1;
}

# Create a new project
sub create_project {
    my ($self, $params) = @_;
    
    return { success => 0, error => 'Project name is required' }
        unless $params->{name};
    
    my $dbh = $self->storage->dbh;
    
    eval {
        $dbh->do(qq{
            INSERT INTO projects (name, description, color, settings)
            VALUES (?, ?, ?, ?)
        }, {},
            $params->{name},
            $params->{description} || '',
            $params->{color} || '#3b82f6',
            $self->json->encode($params->{settings} || {
                search_preferences => {
                    min_relevance => 0.3,
                    max_results => 50
                },
                rag_settings => {
                    chunk_overlap => 0.1,
                    similarity_threshold => 0.4
                }
            })
        );
        
        my $project_id = $dbh->last_insert_id("", "", "projects", "id");
        
        # Initialize stats
        $dbh->do(qq{
            INSERT INTO project_stats (project_id, article_count, link_count, chunk_count, last_activity)
            VALUES (?, 0, 0, 0, strftime('%s', 'now'))
        }, {}, $project_id);
        
        $self->logger->info("Created project: $params->{name} (ID: $project_id)");
        
        return {
            success => 1,
            project => $self->get_project($project_id)
        };
    };
    
    if ($@) {
        $self->logger->error("Failed to create project: $@");
        return { success => 0, error => "Failed to create project: $@" };
    }
}

# Get project by ID
sub get_project {
    my ($self, $project_id) = @_;
    
    return unless $project_id;
    
    my $dbh = $self->storage->dbh;
    my $project = $dbh->selectrow_hashref(qq{
        SELECT p.*, ps.article_count, ps.link_count, ps.chunk_count, ps.last_activity
        FROM projects p
        LEFT JOIN project_stats ps ON p.id = ps.project_id
        WHERE p.id = ?
    }, {}, $project_id);
    
    if ($project && $project->{settings}) {
        $project->{settings} = eval { $self->json->decode($project->{settings}) } || {};
    }
    
    return $project;
}

# Get all projects
sub list_projects {
    my ($self, $params) = @_;
    
    my $dbh = $self->storage->dbh;
    my $projects = $dbh->selectall_arrayref(qq{
        SELECT p.*, ps.article_count, ps.link_count, ps.chunk_count, ps.last_activity
        FROM projects p
        LEFT JOIN project_stats ps ON p.id = ps.project_id
        ORDER BY p.is_default DESC, p.updated_at DESC
    }, { Slice => {} });
    
    # Decode settings for each project
    for my $project (@$projects) {
        if ($project->{settings}) {
            $project->{settings} = eval { $self->json->decode($project->{settings}) } || {};
        }
    }
    
    return $projects || [];
}

# Update project
sub update_project {
    my ($self, $project_id, $params) = @_;
    
    return { success => 0, error => 'Project ID is required' }
        unless $project_id;
    
    my $dbh = $self->storage->dbh;
    
    eval {
        my @fields;
        my @values;
        
        if (defined $params->{name}) {
            push @fields, 'name = ?';
            push @values, $params->{name};
        }
        
        if (defined $params->{description}) {
            push @fields, 'description = ?';
            push @values, $params->{description};
        }
        
        if (defined $params->{color}) {
            push @fields, 'color = ?';
            push @values, $params->{color};
        }
        
        if (defined $params->{settings}) {
            push @fields, 'settings = ?';
            push @values, $self->json->encode($params->{settings});
        }
        
        push @fields, "updated_at = strftime('%s', 'now')";
        push @values, $project_id;
        
        my $sql = "UPDATE projects SET " . join(', ', @fields) . " WHERE id = ?";
        $dbh->do($sql, {}, @values);
        
        $self->logger->info("Updated project ID: $project_id");
        
        return {
            success => 1,
            project => $self->get_project($project_id)
        };
    };
    
    if ($@) {
        $self->logger->error("Failed to update project: $@");
        return { success => 0, error => "Failed to update project: $@" };
    }
}

# Delete project (with safeguards)
sub delete_project {
    my ($self, $project_id) = @_;
    
    return { success => 0, error => 'Project ID is required' }
        unless $project_id;
    
    my $dbh = $self->storage->dbh;
    my $project = $self->get_project($project_id);
    
    return { success => 0, error => 'Project not found' }
        unless $project;
    
    return { success => 0, error => 'Cannot delete default project' }
        if $project->{is_default};
    
    eval {
        # Begin transaction
        $dbh->begin_work();
        
        # Move articles to default project instead of deleting them
        my $default_project_id = $self->get_default_project_id();
        
        $dbh->do(qq{
            UPDATE project_articles 
            SET project_id = ? 
            WHERE project_id = ? 
            AND article_id NOT IN (
                SELECT article_id FROM project_articles WHERE project_id = ?
            )
        }, {}, $default_project_id, $project_id, $default_project_id);
        
        # Delete project-specific associations
        $dbh->do("DELETE FROM project_articles WHERE project_id = ?", {}, $project_id);
        $dbh->do("DELETE FROM project_stats WHERE project_id = ?", {}, $project_id);
        
        # Update any other project-specific records to default
        $dbh->do("UPDATE crawl_sessions SET project_id = ? WHERE project_id = ?", 
                {}, $default_project_id, $project_id);
        $dbh->do("UPDATE interest_profiles SET project_id = ? WHERE project_id = ?", 
                {}, $default_project_id, $project_id);
        
        # Finally delete the project
        $dbh->do("DELETE FROM projects WHERE id = ?", {}, $project_id);
        
        $dbh->commit();
        
        $self->logger->info("Deleted project: $project->{name} (ID: $project_id)");
        
        return { success => 1, message => 'Project deleted successfully' };
    };
    
    if ($@) {
        $dbh->rollback();
        $self->logger->error("Failed to delete project: $@");
        return { success => 0, error => "Failed to delete project: $@" };
    }
}

# Get default project ID
sub get_default_project_id {
    my ($self, $dbh) = @_;
    
    # Accept dbh as parameter to avoid circular dependency during init
    $dbh ||= $self->storage->dbh;
    
    my ($project_id) = $dbh->selectrow_array(
        "SELECT id FROM projects WHERE is_default = 1"
    );
    
    return $project_id || 1; # Fallback to ID 1
}

# Add article to project
sub add_article_to_project {
    my ($self, $project_id, $article_id, $added_via) = @_;
    
    return unless $project_id && $article_id;
    
    my $dbh = $self->storage->dbh;
    
    eval {
        $dbh->do(qq{
            INSERT OR IGNORE INTO project_articles (project_id, article_id, added_via)
            VALUES (?, ?, ?)
        }, {}, $project_id, $article_id, $added_via || 'manual');
        
        # Update project stats
        $self->update_project_stats($project_id);
    };
    
    if ($@) {
        $self->logger->error("Failed to add article $article_id to project $project_id: $@");
    }
}

# Remove article from project
sub remove_article_from_project {
    my ($self, $project_id, $article_id) = @_;
    
    return unless $project_id && $article_id;
    
    my $dbh = $self->storage->dbh;
    
    eval {
        $dbh->do(qq{
            DELETE FROM project_articles 
            WHERE project_id = ? AND article_id = ?
        }, {}, $project_id, $article_id);
        
        # Update project stats
        $self->update_project_stats($project_id);
    };
    
    if ($@) {
        $self->logger->error("Failed to remove article $article_id from project $project_id: $@");
    }
}

# Update project statistics
sub update_project_stats {
    my ($self, $project_id) = @_;
    
    return unless $project_id;
    
    my $dbh = $self->storage->dbh;
    
    eval {
        # Count articles in project
        my ($article_count) = $dbh->selectrow_array(qq{
            SELECT COUNT(*) FROM project_articles WHERE project_id = ?
        }, {}, $project_id);
        
        # Count links between articles in project
        my ($link_count) = $dbh->selectrow_array(qq{
            SELECT COUNT(*) FROM links l
            JOIN project_articles pa1 ON l.from_article_id = pa1.article_id
            JOIN project_articles pa2 ON l.to_article_id = pa2.article_id
            WHERE pa1.project_id = ? AND pa2.project_id = ?
        }, {}, $project_id, $project_id);
        
        # Count chunks for articles in project
        my ($chunk_count) = $dbh->selectrow_array(qq{
            SELECT COUNT(*) FROM article_chunks ac
            JOIN project_articles pa ON ac.article_id = pa.article_id
            WHERE pa.project_id = ?
        }, {}, $project_id);
        
        # Update stats
        $dbh->do(qq{
            INSERT OR REPLACE INTO project_stats 
            (project_id, article_count, link_count, chunk_count, last_activity, last_updated)
            VALUES (?, ?, ?, ?, strftime('%s', 'now'), strftime('%s', 'now'))
        }, {}, $project_id, $article_count, $link_count, $chunk_count);
    };
    
    if ($@) {
        $self->logger->error("Failed to update project stats for project $project_id: $@");
    }
}

# Get articles for a project
sub get_project_articles {
    my ($self, $project_id, $limit, $offset) = @_;
    
    return [] unless $project_id;
    
    $limit ||= 50;
    $offset ||= 0;
    
    my $dbh = $self->storage->dbh;
    
    my $articles = $dbh->selectall_arrayref(qq{
        SELECT a.*, pa.added_at, pa.added_via
        FROM articles a
        JOIN project_articles pa ON a.id = pa.article_id
        WHERE pa.project_id = ?
        ORDER BY pa.added_at DESC
        LIMIT ? OFFSET ?
    }, { Slice => {} }, $project_id, $limit, $offset);
    
    return $articles || [];
}

# Search articles within a project context
sub search_project_articles {
    my ($self, $project_id, $query, $limit) = @_;
    
    return [] unless $project_id && $query;
    
    $limit ||= 20;
    
    my $dbh = $self->storage->dbh;
    
    my $articles = $dbh->selectall_arrayref(qq{
        SELECT a.id, a.title, a.url, a.summary, pa.added_via
        FROM articles a
        JOIN project_articles pa ON a.id = pa.article_id
        WHERE pa.project_id = ?
        AND (a.title LIKE ? OR a.content LIKE ? OR a.summary LIKE ?)
        ORDER BY 
            CASE 
                WHEN a.title LIKE ? THEN 1
                WHEN a.summary LIKE ? THEN 2
                ELSE 3
            END,
            a.title
        LIMIT ?
    }, { Slice => {} },
        $project_id,
        "%$query%", "%$query%", "%$query%",
        "%$query%", "%$query%",
        $limit
    );
    
    return $articles || [];
}

1;

__END__

=head1 NAME

WikiCrawler::ProjectManager - Project management for WikiCrawler

=head1 SYNOPSIS

    use WikiCrawler::ProjectManager;
    
    my $pm = WikiCrawler::ProjectManager->new(storage => $storage);
    
    # Initialize project system
    $pm->initialize_project_schema();
    
    # Create a project
    my $result = $pm->create_project({
        name => 'My Research',
        description => 'AI and Machine Learning research'
    });

=head1 DESCRIPTION

This module provides project management capabilities for organizing articles,
conversations, and knowledge graphs into separate project contexts.

=head1 AUTHOR

WikiCrawler Project

=cut
