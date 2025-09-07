package Tessera::LearningManager;

use strict;
use warnings;
use v5.20;

use JSON;
use Time::HiRes qw(time);
use Digest::SHA qw(sha256_hex);
use List::Util qw(min max);
use Moo;
use namespace::clean;

has 'storage' => (
    is => 'ro',
    required => 1,
);

has 'config' => (
    is => 'ro',
    required => 1,
);

has 'logger' => (
    is => 'ro',
    required => 1,
);

has 'json' => (
    is => 'lazy',
    default => sub { JSON->new->utf8->pretty },
);

# Add learning content
sub add_content {
    my ($self, %args) = @_;
    
    my $required = [qw(title content_type)];
    for my $field (@$required) {
        die "Missing required field: $field" unless defined $args{$field};
    }
    
    my $dbh = $self->storage->dbh;
    
    my $content_data = {
        title => $args{title},
        content_type => $args{content_type}, # book, video, article, course, documentation
        url => $args{url},
        content => $args{content},
        summary => $args{summary},
        metadata => $args{metadata} ? $self->json->encode($args{metadata}) : '{}',
        source => $args{source} || 'manual',
        difficulty_level => $args{difficulty_level} || 1,
        estimated_time_minutes => $args{estimated_time_minutes} || 0,
        rating => $args{rating},
        notes => $args{notes},
        tags => $args{tags} ? $self->json->encode($args{tags}) : '[]',
    };
    
    my $sql = qq{
        INSERT INTO learning_content (
            title, content_type, url, content, summary, metadata,
            source, difficulty_level, estimated_time_minutes, rating, notes, tags
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    };
    
    my $sth = $dbh->prepare($sql);
    $sth->execute(
        $content_data->{title},
        $content_data->{content_type},
        $content_data->{url},
        $content_data->{content},
        $content_data->{summary},
        $content_data->{metadata},
        $content_data->{source},
        $content_data->{difficulty_level},
        $content_data->{estimated_time_minutes},
        $content_data->{rating},
        $content_data->{notes},
        $content_data->{tags}
    );
    
    my $content_id = $dbh->last_insert_id;
    
    # Associate with subjects if provided
    if ($args{subjects} && @{$args{subjects}}) {
        $self->associate_content_with_subjects($content_id, $args{subjects});
    }
    
    # Create chunks if content is provided
    if ($args{content} && length($args{content}) > 0) {
        $self->create_content_chunks($content_id, $args{content}, $args{content_type});
    }
    
    $self->logger->info("Added learning content", 
                       content_id => $content_id,
                       title => $args{title},
                       type => $args{content_type});
    
    return $content_id;
}

# Associate content with subjects
sub associate_content_with_subjects {
    my ($self, $content_id, $subjects) = @_;
    
    my $dbh = $self->storage->dbh;
    my $sth = $dbh->prepare(qq{
        INSERT OR IGNORE INTO content_subjects (content_id, subject_id, relevance_score)
        VALUES (?, ?, ?)
    });
    
    for my $subject_info (@$subjects) {
        my ($subject_id, $relevance) = ref($subject_info) eq 'HASH' 
            ? ($subject_info->{id}, $subject_info->{relevance} || 1.0)
            : ($subject_info, 1.0);
            
        $sth->execute($content_id, $subject_id, $relevance);
    }
}

# Create content chunks for embedding
sub create_content_chunks {
    my ($self, $content_id, $content, $content_type) = @_;
    
    my $chunks = $self->_split_content_into_chunks($content, $content_type);
    
    my $dbh = $self->storage->dbh;
    my $sth = $dbh->prepare(qq{
        INSERT INTO content_chunks (
            content_id, chunk_type, chunk_identifier, content_text,
            char_count, token_count, content_hash, needs_embedding
        ) VALUES (?, ?, ?, ?, ?, ?, ?, 1)
    });
    
    my $chunk_count = 0;
    for my $chunk (@$chunks) {
        my $char_count = length($chunk->{content});
        my $token_count = $self->_estimate_token_count($chunk->{content});
        my $content_hash = sha256_hex($chunk->{content});
        
        $sth->execute(
            $content_id,
            $chunk->{type},
            $chunk->{identifier},
            $chunk->{content},
            $char_count,
            $token_count,
            $content_hash
        );
        $chunk_count++;
    }
    
    $self->logger->info("Created content chunks", 
                       content_id => $content_id,
                       chunk_count => $chunk_count);
    
    return $chunk_count;
}

# Split content into chunks based on content type
sub _split_content_into_chunks {
    my ($self, $content, $content_type) = @_;
    
    my @chunks;
    
    if ($content_type eq 'book' || $content_type eq 'documentation') {
        # Split by chapters/sections
        my @sections = split /\n\s*(?:Chapter|Section|\#\#?)\s*\d+/i, $content;
        for my $i (0 .. $#sections) {
            next unless $sections[$i] && length(trim($sections[$i])) > 100;
            push @chunks, {
                type => 'chapter',
                identifier => "Chapter " . ($i + 1),
                content => trim($sections[$i])
            };
        }
    } elsif ($content_type eq 'article') {
        # Split by paragraphs, but group them
        my @paragraphs = split /\n\s*\n/, $content;
        my $current_chunk = '';
        my $chunk_num = 1;
        
        for my $para (@paragraphs) {
            $para = trim($para);
            next unless $para;
            
            if (length($current_chunk . $para) > 1000) {
                if ($current_chunk) {
                    push @chunks, {
                        type => 'section',
                        identifier => "Section $chunk_num",
                        content => $current_chunk
                    };
                    $chunk_num++;
                }
                $current_chunk = $para;
            } else {
                $current_chunk .= ($current_chunk ? "\n\n" : '') . $para;
            }
        }
        
        # Add final chunk
        if ($current_chunk) {
            push @chunks, {
                type => 'section',
                identifier => "Section $chunk_num",
                content => $current_chunk
            };
        }
    } else {
        # Default: split into fixed-size chunks
        my $chunk_size = 1000;
        my $overlap = 100;
        my $pos = 0;
        my $chunk_num = 1;
        
        while ($pos < length($content)) {
            my $chunk_end = min($pos + $chunk_size, length($content));
            my $chunk_text = substr($content, $pos, $chunk_end - $pos);
            
            push @chunks, {
                type => 'chunk',
                identifier => "Chunk $chunk_num",
                content => $chunk_text
            };
            
            $pos = $chunk_end - $overlap;
            $chunk_num++;
            last if $pos >= length($content);
        }
    }
    
    return \@chunks;
}

# Record learning progress
sub record_progress {
    my ($self, %args) = @_;
    
    my $required = [qw(content_id time_spent_minutes)];
    for my $field (@$required) {
        die "Missing required field: $field" unless defined $args{$field};
    }
    
    my $dbh = $self->storage->dbh;
    
    # Insert progress record
    my $sth = $dbh->prepare(qq{
        INSERT INTO learning_progress (
            content_id, time_spent_minutes, progress_delta,
            comprehension_score, session_notes
        ) VALUES (?, ?, ?, ?, ?)
    });
    
    $sth->execute(
        $args{content_id},
        $args{time_spent_minutes},
        $args{progress_delta} || 0,
        $args{comprehension_score},
        $args{session_notes}
    );
    
    # Update content completion and actual time
    if ($args{progress_delta}) {
        $dbh->do(qq{
            UPDATE learning_content 
            SET completion_percentage = min(100, completion_percentage + ?),
                actual_time_minutes = actual_time_minutes + ?,
                updated_at = strftime('%s', 'now')
            WHERE id = ?
        }, {}, $args{progress_delta}, $args{time_spent_minutes}, $args{content_id});
    } else {
        $dbh->do(qq{
            UPDATE learning_content 
            SET actual_time_minutes = actual_time_minutes + ?,
                updated_at = strftime('%s', 'now')
            WHERE id = ?
        }, {}, $args{time_spent_minutes}, $args{content_id});
    }
    
    $self->logger->info("Recorded learning progress",
                       content_id => $args{content_id},
                       time_spent => $args{time_spent_minutes},
                       progress_delta => $args{progress_delta} || 0);
    
    return $dbh->last_insert_id;
}

# Get subject progress summary
sub get_subject_progress {
    my ($self, $subject_id, $days_back) = @_;
    
    $days_back ||= 30;
    my $cutoff_time = time() - ($days_back * 24 * 3600);
    
    my $dbh = $self->storage->dbh;
    
    my $sql = qq{
        SELECT 
            s.name as subject_name,
            COUNT(DISTINCT lc.id) as total_content,
            COUNT(DISTINCT CASE WHEN lc.completion_percentage > 0 THEN lc.id END) as started_content,
            COUNT(DISTINCT CASE WHEN lc.completion_percentage >= 100 THEN lc.id END) as completed_content,
            AVG(lc.completion_percentage) as avg_completion,
            SUM(lc.actual_time_minutes) as total_time_minutes,
            SUM(lp.time_spent_minutes) as recent_time_minutes,
            AVG(lp.comprehension_score) as avg_comprehension
        FROM subjects s
        LEFT JOIN content_subjects cs ON s.id = cs.subject_id
        LEFT JOIN learning_content lc ON cs.content_id = lc.id
        LEFT JOIN learning_progress lp ON lc.id = lp.content_id AND lp.session_date >= ?
        WHERE s.id = ?
        GROUP BY s.id, s.name
    };
    
    my $result = $dbh->selectrow_hashref($sql, {}, $cutoff_time, $subject_id);
    
    # Get recent learning sessions
    my $sessions_sql = qq{
        SELECT 
            DATE(lp.session_date, 'unixepoch') as date,
            SUM(lp.time_spent_minutes) as daily_minutes,
            COUNT(*) as session_count,
            AVG(lp.comprehension_score) as avg_comprehension
        FROM learning_progress lp
        JOIN learning_content lc ON lp.content_id = lc.id
        JOIN content_subjects cs ON lc.id = cs.content_id
        WHERE cs.subject_id = ? AND lp.session_date >= ?
        GROUP BY DATE(lp.session_date, 'unixepoch')
        ORDER BY date DESC
        LIMIT 14
    };
    
    my $sessions = $dbh->selectall_arrayref($sessions_sql, {Slice => {}}, $subject_id, $cutoff_time);
    
    return {
        %$result,
        recent_sessions => $sessions
    };
}

# Get learning recommendations
sub get_learning_recommendations {
    my ($self, $subject_id, $limit) = @_;
    
    $limit ||= 5;
    my $dbh = $self->storage->dbh;
    
    # Recommend content based on difficulty progression and completion status
    my $sql = qq{
        SELECT 
            lc.*,
            cs.relevance_score,
            CASE 
                WHEN lc.completion_percentage = 0 THEN 'new'
                WHEN lc.completion_percentage < 100 THEN 'continue'
                ELSE 'review'
            END as recommendation_type,
            (cs.relevance_score * (101 - lc.completion_percentage) * 
             CASE WHEN lc.difficulty_level <= 3 THEN 2 ELSE 1 END) as priority_score
        FROM learning_content lc
        JOIN content_subjects cs ON lc.id = cs.content_id
        WHERE cs.subject_id = ? AND lc.completion_percentage < 100
        ORDER BY priority_score DESC, lc.difficulty_level ASC
        LIMIT ?
    };
    
    return $dbh->selectall_arrayref($sql, {Slice => {}}, $subject_id, $limit);
}

# Utility functions
sub _estimate_token_count {
    my ($self, $text) = @_;
    # Rough estimation: ~4 characters per token
    return int(length($text) / 4);
}

sub trim {
    my ($text) = @_;
    return '' unless defined $text;
    $text =~ s/^\s+|\s+$//g;
    return $text;
}

1;

__END__

=head1 NAME

Tessera::LearningManager - Personal learning content and progress management

=head1 SYNOPSIS

    use Tessera::LearningManager;
    
    my $learning = Tessera::LearningManager->new(
        storage => $storage,
        config => $config,
        logger => $logger
    );
    
    # Add learning content
    my $content_id = $learning->add_content(
        title => "Python Crash Course",
        content_type => "book",
        content => $book_text,
        subjects => [{id => 1, relevance => 1.0}],
        difficulty_level => 2,
        estimated_time_minutes => 1200
    );
    
    # Record progress
    $learning->record_progress(
        content_id => $content_id,
        time_spent_minutes => 45,
        progress_delta => 5.0,
        comprehension_score => 4,
        session_notes => "Learned about functions and classes"
    );
    
    # Get subject progress
    my $progress = $learning->get_subject_progress(1, 30);

=head1 DESCRIPTION

This module manages learning content and progress tracking for the Personal Learning Tracker.
It handles diverse content types (books, videos, articles, courses) and tracks learning
progress across different subjects with intelligent chunking for embeddings.

=head1 METHODS

=head2 add_content(%args)

Add new learning content. Required args: title, content_type.
Optional: url, content, summary, subjects, difficulty_level, etc.

=head2 record_progress(%args)

Record learning session progress. Required: content_id, time_spent_minutes.
Optional: progress_delta, comprehension_score, session_notes.

=head2 get_subject_progress($subject_id, $days_back)

Get comprehensive progress summary for a subject.

=head2 get_learning_recommendations($subject_id, $limit)

Get personalized learning recommendations based on progress and difficulty.

=head1 AUTHOR

Personal Learning Tracker Project

=cut
