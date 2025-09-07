package WikiCrawler::Storage;

use strict;
use warnings;
use v5.20;

use DBI;
use JSON::XS;
use Log::Log4perl;
use File::Path qw(make_path);
use File::Basename qw(dirname);

use Moo;
use namespace::clean;

# Attributes
has 'config' => (
    is       => 'ro',
    required => 1,
);

has 'dbh' => (
    is      => 'lazy',
    builder => '_build_dbh',
);

has 'logger' => (
    is      => 'lazy',
    builder => '_build_logger',
);

has 'json' => (
    is      => 'lazy',
    builder => '_build_json',
);

has 'project_manager' => (
    is      => 'lazy',
    builder => '_build_project_manager',
);

has 'hash_manager' => (
    is      => 'lazy',
    builder => '_build_hash_manager',
);

# Cache invalidation callback - called when data changes
has 'cache_invalidation_callback' => (
    is      => 'rw',
    clearer => 'clear_cache_invalidation_callback',
);

# Cache invalidation debouncing
has '_invalidation_pending' => (
    is      => 'rw',
    default => 0,
);

has '_invalidation_timer' => (
    is      => 'rw',
    clearer => 'clear_invalidation_timer',
);

sub _build_dbh {
    my $self = shift;
    
    my $db_path = $self->config->{database}{path};
    
    # Ensure directory exists
    my $db_dir = dirname($db_path);
    make_path($db_dir) unless -d $db_dir;
    
    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$db_path",
        "", "",
        {
            RaiseError => 1,
            AutoCommit => 1,
            sqlite_unicode => 1,
        }
    ) or die "Cannot connect to database: " . DBI->errstr;
    
    # Initialize database schema
    $self->_initialize_schema($dbh);
    
    return $dbh;
}

sub _build_logger {
    my $self = shift;
    return Log::Log4perl->get_logger(__PACKAGE__);
}

sub _build_json {
    my $self = shift;
    return JSON::XS->new->utf8->pretty;
}

sub _build_project_manager {
    my $self = shift;
    require WikiCrawler::ProjectManager;
    return WikiCrawler::ProjectManager->new(storage => $self);
}

sub _build_hash_manager {
    my $self = shift;
    require WikiCrawler::HashManager;
    return WikiCrawler::HashManager->new();
}

# Debounced cache invalidation to prevent excessive invalidation calls
sub _schedule_cache_invalidation {
    my ($self) = @_;
    
    # Simple debouncing: only invalidate if enough time has passed since last invalidation
    my $now = time();
    my $last_invalidation = $self->_invalidation_timer || 0;
    
    # If less than 2 seconds since last invalidation, just mark as pending
    if ($now - $last_invalidation < 2) {
        $self->_invalidation_pending(1);
        return;
    }
    
    # Execute invalidation and update timer
    $self->_execute_cache_invalidation();
    $self->_invalidation_timer($now);
}

# Execute the actual cache invalidation
sub _execute_cache_invalidation {
    my ($self) = @_;
    
    return unless $self->cache_invalidation_callback;
    
    $self->logger->info("Invalidating knowledge graph cache");
    $self->cache_invalidation_callback->();
    
    # Reset the pending flag
    $self->_invalidation_pending(0);
}

# Force immediate cache invalidation (e.g., at end of crawl session)
sub force_cache_invalidation {
    my ($self) = @_;
    
    # If there's a pending invalidation, execute it now
    if ($self->_invalidation_pending) {
        $self->_execute_cache_invalidation();
        $self->_invalidation_timer(time());
    }
}

# Initialize database schema
sub _initialize_schema {
    my ($self, $dbh) = @_;
    
    # Articles table
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS articles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL UNIQUE,
            url TEXT NOT NULL,
            content TEXT,
            summary TEXT,
            infobox TEXT, -- JSON
            categories TEXT, -- JSON array
            sections TEXT, -- JSON array
            images TEXT, -- JSON array
            coordinates TEXT, -- JSON object
            fetched_at INTEGER,
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER DEFAULT (strftime('%s', 'now'))
        )
    });
    
    # Links table (for the knowledge graph)
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS links (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_article_id INTEGER,
            to_article_id INTEGER,
            anchor_text TEXT,
            relevance_score REAL DEFAULT 0,
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (from_article_id) REFERENCES articles(id),
            FOREIGN KEY (to_article_id) REFERENCES articles(id),
            UNIQUE(from_article_id, to_article_id)
        )
    });
    
    # Interest profiles table
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS interest_profiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            keywords TEXT, -- JSON array
            relevance_threshold REAL DEFAULT 0.3,
            boost_keywords TEXT, -- JSON array
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER DEFAULT (strftime('%s', 'now'))
        )
    });
    
    # Crawl sessions table
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS crawl_sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            profile_id INTEGER,
            start_url TEXT,
            max_depth INTEGER,
            max_articles INTEGER,
            articles_crawled INTEGER DEFAULT 0,
            status TEXT DEFAULT 'running', -- running, completed, stopped, error
            started_at INTEGER DEFAULT (strftime('%s', 'now')),
            completed_at INTEGER,
            FOREIGN KEY (profile_id) REFERENCES interest_profiles(id)
        )
    });
    
    # RAG: Article chunks table
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS article_chunks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            article_id INTEGER NOT NULL,
            chunk_type TEXT NOT NULL, -- 'section', 'paragraph', 'summary'  
            section_name TEXT,
            content TEXT NOT NULL,
            char_count INTEGER,
            token_count INTEGER,
            content_hash TEXT, -- SHA256 of content for change detection
            needs_embedding INTEGER DEFAULT 1,
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            updated_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (article_id) REFERENCES articles(id) ON DELETE CASCADE
        )
    });
    
    # RAG: Embeddings table (stores vector representations)
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS chunk_embeddings (
            chunk_id INTEGER PRIMARY KEY,
            model_name TEXT NOT NULL, -- e.g., 'all-MiniLM-L6-v2'
            embedding_blob BLOB NOT NULL, -- Serialized vector
            embedding_dim INTEGER NOT NULL, -- Vector dimension
            created_at INTEGER DEFAULT (strftime('%s', 'now')),
            FOREIGN KEY (chunk_id) REFERENCES article_chunks(id) ON DELETE CASCADE
        )
    });
    
    # RAG: Semantic search cache (optional optimization)
    $dbh->do(qq{
        CREATE TABLE IF NOT EXISTS semantic_search_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query_hash TEXT UNIQUE NOT NULL,
            query_text TEXT NOT NULL,
            results_json TEXT NOT NULL, -- JSON array of chunk_ids with scores
            expires_at INTEGER NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s', 'now'))
        )
    });

    # Create indexes
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_articles_title ON articles(title)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_articles_fetched_at ON articles(fetched_at)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_links_from_article ON links(from_article_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_links_to_article ON links(to_article_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_links_relevance ON links(relevance_score)");
    
    # RAG indexes
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_chunks_article_id ON article_chunks(article_id)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_chunks_type ON article_chunks(chunk_type)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_chunks_hash ON article_chunks(content_hash)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_chunks_needs_embedding ON article_chunks(needs_embedding)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_embeddings_model ON chunk_embeddings(model_name)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_search_cache_hash ON semantic_search_cache(query_hash)");
    $dbh->do("CREATE INDEX IF NOT EXISTS idx_search_cache_expires ON semantic_search_cache(expires_at)");
    
    $self->logger->info("Database schema initialized with RAG support");
    
    # Initialize project schema immediately after core schema
    $self->_initialize_project_schema($dbh);
}

# Initialize project schema directly (called during main schema init)
sub _initialize_project_schema {
    my ($self, $dbh) = @_;
    
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
}

# Ensure project schema is initialized (called when needed)
sub _ensure_project_schema {
    my $self = shift;
    
    # Check if projects table exists
    my $dbh = $self->dbh;
    my $table_exists = $dbh->selectrow_array(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='projects'"
    );
    
    unless ($table_exists) {
        $self->logger->info("Projects table not found, initializing project schema");
        $self->_initialize_project_schema($dbh);
    }
}

# Note: Project schema is now initialized directly in _initialize_schema

# Store article data
sub store_article {
    my ($self, $article_data, $project_id) = @_;
    
    return unless $article_data && $article_data->{title};
    
    my $dbh = $self->dbh;
    
    # Use default project if none specified
    $project_id ||= $self->project_manager->get_default_project_id($dbh);
    
    my $result;
    eval {
        # Check if article already exists
        my $existing = $dbh->selectrow_hashref(
            "SELECT id, updated_at FROM articles WHERE title = ?",
            {}, $article_data->{title}
        );
        
        if ($existing) {
            # Update existing article
            $dbh->do(qq{
                UPDATE articles SET
                    url = ?, content = ?, summary = ?, infobox = ?,
                    categories = ?, sections = ?, images = ?, coordinates = ?,
                    fetched_at = ?, updated_at = strftime('%s', 'now')
                WHERE id = ?
            },
                {},
                $article_data->{url},
                $article_data->{content},
                $article_data->{summary},
                $self->json->encode($article_data->{infobox} || {}),
                $self->json->encode($article_data->{categories} || []),
                $self->json->encode($article_data->{sections} || []),
                $self->json->encode($article_data->{images} || []),
                $self->json->encode($article_data->{coordinates} || {}),
                $article_data->{parsed_at} || time(),
                $existing->{id}
            );
            
            $self->logger->info("Updated article: " . $article_data->{title});
            $result = $existing->{id};
            
            # RAG: Update chunks if article was modified
            if ($article_data->{chunks}) {
                $self->store_article_chunks($result, $article_data->{chunks});
            }
            
            # Ensure article is associated with the project
            $self->project_manager->add_article_to_project($project_id, $result, 'update');
        } else {
            # Insert new article
            $dbh->do(qq{
                INSERT INTO articles (
                    title, url, content, summary, infobox, categories,
                    sections, images, coordinates, fetched_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            },
                {},
                $article_data->{title},
                $article_data->{url},
                $article_data->{content},
                $article_data->{summary},
                $self->json->encode($article_data->{infobox} || {}),
                $self->json->encode($article_data->{categories} || []),
                $self->json->encode($article_data->{sections} || []),
                $self->json->encode($article_data->{images} || []),
                $self->json->encode($article_data->{coordinates} || {}),
                $article_data->{parsed_at} || time()
            );
            
            my $article_id = $dbh->last_insert_id("", "", "articles", "id");
            $self->logger->info("Stored new article: " . $article_data->{title});
            $result = $article_id;
            
            # RAG: Store chunks for new article
            if ($article_data->{chunks}) {
                $self->store_article_chunks($result, $article_data->{chunks});
            }
            
            # Associate article with project
            $self->project_manager->add_article_to_project($project_id, $result, 'crawl');
            
            # Schedule debounced cache invalidation for new articles
            $self->_schedule_cache_invalidation();
        }
    };
    
    if ($@) {
        $self->logger->error("Failed to store article '$article_data->{title}': $@");
        return;
    }
    
    return $result;
}

# Store link between articles
sub store_link {
    my ($self, $from_article_id, $to_article_id, $anchor_text, $relevance_score) = @_;
    
    return unless $from_article_id && $to_article_id;
    
    $relevance_score ||= 0;
    
    eval {
        $self->dbh->do(qq{
            INSERT OR REPLACE INTO links (
                from_article_id, to_article_id, anchor_text, relevance_score
            ) VALUES (?, ?, ?, ?)
        },
            {},
            $from_article_id,
            $to_article_id,
            $anchor_text,
            $relevance_score
        );
        
        $self->logger->debug("Stored link: $from_article_id -> $to_article_id");
        
        # Schedule debounced cache invalidation for new links
        $self->_schedule_cache_invalidation();
    };
    
    if ($@) {
        $self->logger->error("Failed to store link: $@");
    }
}

# Get article by title
sub get_article_by_title {
    my ($self, $title) = @_;
    
    return unless $title;
    
    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM articles WHERE title = ?",
        {}, $title
    );
    
    return unless $row;
    
    # Decode JSON fields
    for my $field (qw(infobox categories sections images coordinates)) {
        if ($row->{$field}) {
            eval {
                $row->{$field} = $self->json->decode($row->{$field});
            };
            if ($@) {
                $self->logger->warn("Failed to decode JSON for $field in article $title: $@");
                $row->{$field} = {};
            }
        }
    }
    
    return $row;
}

# Get article by ID
sub get_article_by_id {
    my ($self, $id) = @_;
    
    return unless $id;
    
    my $row = $self->dbh->selectrow_hashref(
        "SELECT * FROM articles WHERE id = ?",
        {}, $id
    );
    
    return unless $row;
    
    # Decode JSON fields
    for my $field (qw(infobox categories sections images coordinates)) {
        if ($row->{$field}) {
            eval {
                $row->{$field} = $self->json->decode($row->{$field});
            };
            $row->{$field} = {} if $@;
        }
    }
    
    return $row;
}

# Get links from an article
sub get_outbound_links {
    my ($self, $article_id, $min_relevance) = @_;
    
    return [] unless $article_id;
    
    $min_relevance ||= 0;
    
    my $links = $self->dbh->selectall_arrayref(qq{
        SELECT l.*, a.title, a.url
        FROM links l
        JOIN articles a ON l.to_article_id = a.id
        WHERE l.from_article_id = ? AND l.relevance_score >= ?
        ORDER BY l.relevance_score DESC
    }, { Slice => {} }, $article_id, $min_relevance);
    
    return $links || [];
}

# Get links to an article
sub get_inbound_links {
    my ($self, $article_id, $min_relevance) = @_;
    
    return [] unless $article_id;
    
    $min_relevance ||= 0;
    
    my $links = $self->dbh->selectall_arrayref(qq{
        SELECT l.*, a.title, a.url
        FROM links l
        JOIN articles a ON l.from_article_id = a.id
        WHERE l.to_article_id = ? AND l.relevance_score >= ?
        ORDER BY l.relevance_score DESC
    }, { Slice => {} }, $article_id, $min_relevance);
    
    return $links || [];
}

# Search articles by text
sub search_articles {
    my ($self, $query, $limit, $project_id) = @_;
    
    return [] unless $query;
    
    $limit ||= 50;
    # Ensure limit is a valid positive integer
    $limit = ($limit && $limit =~ /^\d+$/) ? int($limit) : 50;
    $limit = 50 if $limit <= 0;
    
    # Simple text search - could be enhanced with FTS
    my $articles;
    
    if ($project_id) {
        # Ensure project schema is initialized
        $self->_ensure_project_schema();
        
        # Search within project context
        $articles = $self->dbh->selectall_arrayref(qq{
            SELECT a.id, a.title, a.url, a.summary
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
    } else {
        # Global search across all articles
        $articles = $self->dbh->selectall_arrayref(qq{
            SELECT id, title, url, summary
            FROM articles
            WHERE title LIKE ? OR content LIKE ? OR summary LIKE ?
            ORDER BY 
                CASE 
                    WHEN title LIKE ? THEN 1
                    WHEN summary LIKE ? THEN 2
                    ELSE 3
                END,
                title
            LIMIT ?
        }, { Slice => {} },
            "%$query%", "%$query%", "%$query%",
            "%$query%", "%$query%",
            $limit
        );
    }
    
    return $articles || [];
}

# Get most connected articles (knowledge hubs)
sub get_knowledge_hubs {
    my ($self, $limit) = @_;
    
    $limit ||= 10;
    
    # Get articles with the most connections (both inbound and outbound)
    my $hubs = $self->dbh->selectall_arrayref(qq{
        SELECT 
            a.id, a.title, a.url, a.summary, a.categories,
            COALESCE(out_links.count, 0) + COALESCE(in_links.count, 0) as total_connections,
            COALESCE(out_links.count, 0) as outbound_links,
            COALESCE(in_links.count, 0) as inbound_links
        FROM articles a
        LEFT JOIN (
            SELECT from_article_id, COUNT(*) as count 
            FROM links 
            GROUP BY from_article_id
        ) out_links ON a.id = out_links.from_article_id
        LEFT JOIN (
            SELECT to_article_id, COUNT(*) as count 
            FROM links 
            GROUP BY to_article_id
        ) in_links ON a.id = in_links.to_article_id
        WHERE COALESCE(out_links.count, 0) + COALESCE(in_links.count, 0) > 0
        ORDER BY total_connections DESC
        LIMIT ?
    }, { Slice => {} }, $limit);
    
    # Decode categories JSON for each hub
    for my $hub (@$hubs) {
        if ($hub->{categories}) {
            eval {
                $hub->{categories} = $self->json->decode($hub->{categories});
            };
            $hub->{categories} = [] if $@;
        } else {
            $hub->{categories} = [];
        }
    }
    
    return $hubs || [];
}

# Get recent link discoveries
sub get_recent_discoveries {
    my ($self, $limit) = @_;
    
    $limit ||= 10;
    
    # Get most recent links with article titles
    my $discoveries = $self->dbh->selectall_arrayref(qq{
        SELECT 
            l.id, l.anchor_text, l.relevance_score, l.created_at,
            a1.title as from_title, a1.url as from_url,
            a2.title as to_title, a2.url as to_url,
            a1.categories as from_categories,
            a2.categories as to_categories
        FROM links l
        JOIN articles a1 ON l.from_article_id = a1.id
        JOIN articles a2 ON l.to_article_id = a2.id
        ORDER BY l.created_at DESC
        LIMIT ?
    }, { Slice => {} }, $limit);
    
    # Decode categories and format time for each discovery
    for my $discovery (@$discoveries) {
        # Decode categories
        for my $cat_field (qw(from_categories to_categories)) {
            if ($discovery->{$cat_field}) {
                eval {
                    $discovery->{$cat_field} = $self->json->decode($discovery->{$cat_field});
                };
                $discovery->{$cat_field} = [] if $@;
            } else {
                $discovery->{$cat_field} = [];
            }
        }
        
        # Add time formatting
        my $time_diff = time() - $discovery->{created_at};
        if ($time_diff < 3600) {
            $discovery->{time_ago} = int($time_diff / 60) . " minutes ago";
        } elsif ($time_diff < 86400) {
            $discovery->{time_ago} = int($time_diff / 3600) . " hours ago";
        } else {
            $discovery->{time_ago} = int($time_diff / 86400) . " days ago";
        }
        
        # Classify connection strength
        if ($discovery->{relevance_score} >= 0.8) {
            $discovery->{strength} = "strong connection";
        } elsif ($discovery->{relevance_score} >= 0.5) {
            $discovery->{strength} = "moderate link";
        } else {
            $discovery->{strength} = "emerging link";
        }
    }
    
    return $discoveries || [];
}

# Get crawl statistics
sub get_stats {
    my $self = shift;
    
    my $stats = {};
    
    # Article count
    ($stats->{total_articles}) = $self->dbh->selectrow_array(
        "SELECT COUNT(*) FROM articles"
    );
    
    # Link count
    ($stats->{total_links}) = $self->dbh->selectrow_array(
        "SELECT COUNT(*) FROM links"
    );
    
    # Recent activity
    ($stats->{articles_last_24h}) = $self->dbh->selectrow_array(
        "SELECT COUNT(*) FROM articles WHERE created_at > strftime('%s', 'now', '-1 day')"
    );
    
    # Recent links
    ($stats->{links_last_24h}) = $self->dbh->selectrow_array(
        "SELECT COUNT(*) FROM links WHERE created_at > strftime('%s', 'now', '-1 day')"
    );
    
    # Average links per article
    ($stats->{avg_links_per_article}) = $self->dbh->selectrow_array(
        "SELECT AVG(link_count) FROM (SELECT COUNT(*) as link_count FROM links GROUP BY from_article_id)"
    );
    
    $stats->{avg_links_per_article} ||= 0;
    
    # Network density calculation (if we have articles and links)
    if ($stats->{total_articles} > 1 && $stats->{total_links} > 0) {
        my $max_possible_links = $stats->{total_articles} * ($stats->{total_articles} - 1);
        $stats->{network_density} = $stats->{total_links} / $max_possible_links;
    } else {
        $stats->{network_density} = 0;
    }
    
    return $stats;
}

# RAG: Store article chunks
sub store_article_chunks {
    my ($self, $article_id, $chunks) = @_;
    
    return unless $article_id && $chunks && @$chunks;
    
    my $dbh = $self->dbh;
    my $stored_count = 0;
    
    eval {
        # Begin transaction for efficiency
        $dbh->begin_work();
        
        # Delete existing chunks for this article 
        $dbh->do("DELETE FROM article_chunks WHERE article_id = ?", {}, $article_id);
        
        my $sth = $dbh->prepare(qq{
            INSERT INTO article_chunks (
                article_id, chunk_type, section_name, content, 
                char_count, token_count, content_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        });
        
        for my $chunk (@$chunks) {
            my $content_hash = $self->hash_manager->hash_content($chunk->{content});
            
            $sth->execute(
                $article_id,
                $chunk->{type} || 'paragraph',
                $chunk->{section_name},
                $chunk->{content},
                length($chunk->{content}),
                $chunk->{token_count} || $self->_estimate_tokens($chunk->{content}),
                $content_hash
            );
            $stored_count++;
        }
        
        $dbh->commit();
        $self->logger->info("Stored $stored_count chunks for article ID $article_id");
    };
    
    if ($@) {
        $dbh->rollback();
        $self->logger->error("Failed to store chunks for article $article_id: $@");
        return 0;
    }
    
    return $stored_count;
}

# RAG: Get chunks needing embeddings
sub get_chunks_needing_embeddings {
    my ($self, $limit, $model_name) = @_;
    
    $limit ||= 50;
    $model_name ||= 'all-MiniLM-L6-v2';
    
    my $sql = qq{
        SELECT c.id, c.article_id, c.content, c.chunk_type, 
               c.section_name, a.title as article_title
        FROM article_chunks c
        JOIN articles a ON c.article_id = a.id  
        LEFT JOIN chunk_embeddings e ON c.id = e.chunk_id AND e.model_name = ?
        WHERE c.needs_embedding = 1 AND e.chunk_id IS NULL
        ORDER BY c.created_at ASC
        LIMIT ?
    };
    
    my $chunks = $self->dbh->selectall_arrayref($sql, { Slice => {} }, $model_name, $limit);
    
    return $chunks || [];
}

# RAG: Store embeddings for chunks
sub store_chunk_embeddings {
    my ($self, $embeddings_data, $model_name) = @_;
    
    return unless $embeddings_data && @$embeddings_data;
    
    $model_name ||= 'all-MiniLM-L6-v2';
    my $dbh = $self->dbh;
    my $stored_count = 0;
    
    eval {
        $dbh->begin_work();
        
        my $embedding_sth = $dbh->prepare(qq{
            INSERT OR REPLACE INTO chunk_embeddings (
                chunk_id, model_name, embedding_blob, embedding_dim
            ) VALUES (?, ?, ?, ?)
        });
        
        my $update_sth = $dbh->prepare(qq{
            UPDATE article_chunks SET needs_embedding = 0 
            WHERE id = ?
        });
        
        for my $embed_data (@$embeddings_data) {
            my $chunk_id = $embed_data->{chunk_id};
            my $embedding = $embed_data->{embedding}; # Array reference
            
            # Serialize the embedding vector (JSON for simplicity)
            my $embedding_blob = $self->json->encode($embedding);
            my $embedding_dim = scalar @$embedding;
            
            $embedding_sth->execute($chunk_id, $model_name, $embedding_blob, $embedding_dim);
            $update_sth->execute($chunk_id);
            $stored_count++;
        }
        
        $dbh->commit();
        $self->logger->info("Stored $stored_count embeddings using model $model_name");
    };
    
    if ($@) {
        $dbh->rollback();
        $self->logger->error("Failed to store embeddings: $@");
        return 0;
    }
    
    return $stored_count;
}

# RAG: Semantic search for similar chunks 
sub semantic_search_chunks {
    my ($self, $query_embedding, $model_name, $limit, $min_similarity, $project_id) = @_;
    
    $limit ||= 10;
    $min_similarity ||= 0.3;
    $model_name ||= 'all-MiniLM-L6-v2';
    
    # Get all embeddings for the specified model, optionally filtered by project
    my ($sql, @params);
    
    if ($project_id) {
        # Ensure project schema is initialized
        $self->_ensure_project_schema();
        
        # Search within project context
        $sql = qq{
            SELECT c.id, c.content, c.chunk_type, c.section_name,
                   a.title as article_title, a.id as article_id,
                   e.embedding_blob
            FROM article_chunks c
            JOIN articles a ON c.article_id = a.id
            JOIN project_articles pa ON a.id = pa.article_id
            JOIN chunk_embeddings e ON c.id = e.chunk_id
            WHERE e.model_name = ? AND pa.project_id = ?
        };
        @params = ($model_name, $project_id);
    } else {
        # Global search across all chunks  
        $sql = qq{
        SELECT c.id, c.content, c.chunk_type, c.section_name,
               a.title as article_title, a.id as article_id,
               e.embedding_blob
        FROM article_chunks c
        JOIN articles a ON c.article_id = a.id
        JOIN chunk_embeddings e ON c.id = e.chunk_id
        WHERE e.model_name = ?
        };
        @params = ($model_name);
    }
    
    my $chunks = $self->dbh->selectall_arrayref($sql, { Slice => {} }, @params);
    
    return [] unless $chunks && @$chunks;
    
    # Calculate similarities (basic implementation - could use SQLite vector extensions)
    my @scored_chunks;
    
    for my $chunk (@$chunks) {
        my $stored_embedding = $self->json->decode($chunk->{embedding_blob});
        my $similarity = $self->_cosine_similarity($query_embedding, $stored_embedding);
        
        if ($similarity >= $min_similarity) {
            push @scored_chunks, {
                chunk_id => $chunk->{id},
                article_id => $chunk->{article_id},
                article_title => $chunk->{article_title},
                content => $chunk->{content},
                section_name => $chunk->{section_name},
                chunk_type => $chunk->{chunk_type},
                similarity => $similarity,
            };
        }
    }
    
    # Sort by similarity (highest first) and limit
    @scored_chunks = sort { $b->{similarity} <=> $a->{similarity} } @scored_chunks;
    splice @scored_chunks, $limit if @scored_chunks > $limit;
    
    return \@scored_chunks;
}

# RAG: Helper methods
# Note: _hash_content is now handled by hash_manager->hash_content()

sub _estimate_tokens {
    my ($self, $content) = @_;
    
    # Rough estimate: 1 token ≈ 4 characters for English text
    return int(length($content) / 4);
}

sub _cosine_similarity {
    my ($self, $vec1, $vec2) = @_;
    
    return 0 unless @$vec1 == @$vec2;
    
    my ($dot_product, $norm1, $norm2) = (0, 0, 0);
    
    for my $i (0 .. $#$vec1) {
        $dot_product += $vec1->[$i] * $vec2->[$i];
        $norm1 += $vec1->[$i] * $vec1->[$i];
        $norm2 += $vec2->[$i] * $vec2->[$i];
    }
    
    $norm1 = sqrt($norm1);
    $norm2 = sqrt($norm2);
    
    return ($norm1 && $norm2) ? $dot_product / ($norm1 * $norm2) : 0;
}

# Clean up old data
sub cleanup {
    my ($self, $keep_days) = @_;
    
    $keep_days ||= 30;
    
    my $cutoff = time() - ($keep_days * 24 * 60 * 60);
    
    # Remove old articles (this will cascade to links via foreign key constraints)
    my $deleted = $self->dbh->do(
        "DELETE FROM articles WHERE fetched_at < ?",
        {}, $cutoff
    );
    
    $self->logger->info("Cleaned up $deleted old articles");
    
    # Vacuum database
    $self->dbh->do("VACUUM");
    
    return $deleted;
}

# Close database connection
sub disconnect {
    my $self = shift;
    
    if ($self->{dbh}) {
        $self->dbh->disconnect();
        delete $self->{dbh};
    }
}

sub DEMOLISH {
    my $self = shift;
    $self->disconnect();
}

# Project-aware convenience methods

sub get_project_chunks_needing_embeddings {
    my ($self, $limit, $model_name, $project_id) = @_;
    
    $limit ||= 50;
    $model_name ||= 'all-MiniLM-L6-v2';
    
    my ($sql, @params);
    
    if ($project_id) {
        # Ensure project schema is initialized
        $self->_ensure_project_schema();
        
        $sql = qq{
            SELECT c.id, c.article_id, c.content, c.chunk_type, 
                   c.section_name, a.title as article_title
            FROM article_chunks c
            JOIN articles a ON c.article_id = a.id
            JOIN project_articles pa ON a.id = pa.article_id
            LEFT JOIN chunk_embeddings e ON c.id = e.chunk_id AND e.model_name = ?
            WHERE c.needs_embedding = 1 AND e.chunk_id IS NULL AND pa.project_id = ?
            ORDER BY c.created_at ASC
            LIMIT ?
        };
        @params = ($model_name, $project_id, $limit);
    } else {
        return $self->get_chunks_needing_embeddings($limit, $model_name);
    }
    
    my $chunks = $self->dbh->selectall_arrayref($sql, { Slice => {} }, @params);
    return $chunks || [];
}

sub search_project_articles {
    my ($self, $query, $project_id, $limit) = @_;
    return $self->project_manager->search_project_articles($project_id, $query, $limit);
}

1;

__END__

=head1 NAME

WikiCrawler::Storage - Database storage layer for WikiCrawler

=head1 SYNOPSIS

    use WikiCrawler::Storage;
    
    my $storage = WikiCrawler::Storage->new(
        config => $config_hashref
    );
    
    my $article_id = $storage->store_article($article_data);
    my $article = $storage->get_article_by_title('Perl');

=head1 DESCRIPTION

This module provides database storage capabilities for Wikipedia articles and
the knowledge graph. It uses SQLite for persistence and provides methods for
storing, retrieving, and searching articles and their relationships.

=head1 METHODS

=head2 store_article($article_data)

Stores or updates an article in the database.

=head2 store_link($from_id, $to_id, $anchor_text, $relevance_score)

Stores a link between two articles.

=head2 get_article_by_title($title)

Retrieves an article by its title.

=head2 search_articles($query, $limit)

Searches for articles matching the given query.

=head1 AUTHOR

WikiCrawler Project

=cut
