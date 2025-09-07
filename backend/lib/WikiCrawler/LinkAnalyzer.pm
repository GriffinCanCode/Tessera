package WikiCrawler::LinkAnalyzer;

use strict;
use warnings;
use v5.20;

use List::Util qw(sum max min);
use Log::Log4perl;
use Text::Trim qw(trim);

use Moo;
use namespace::clean;

# Attributes
has 'config' => (
    is       => 'ro',
    required => 1,
);

has 'interests' => (
    is      => 'rw',
    default => sub { [] },
);

has 'boost_keywords' => (
    is      => 'rw', 
    default => sub { [] },
);

has 'min_relevance' => (
    is      => 'rw',
    default => 0.3,
);

has 'logger' => (
    is      => 'lazy',
    builder => '_build_logger',
);

sub _build_logger {
    my $self = shift;
    return Log::Log4perl->get_logger(__PACKAGE__);
}

# Initialize with interests from config or parameters
sub BUILD {
    my $self = shift;
    
    if (my $interests_config = $self->config->{interests}) {
        $self->interests($interests_config->{default} || []);
        $self->boost_keywords($interests_config->{boost_keywords} || []);
        $self->min_relevance($interests_config->{min_relevance} || 0.3);
    }
}

# Analyze links and assign relevance scores
sub analyze_links {
    my ($self, $links, $source_article) = @_;
    
    return [] unless $links && @$links;
    
    $self->logger->debug("Analyzing " . @$links . " links for relevance");
    
    my @relevant_links;
    
    for my $link (@$links) {
        my $relevance = $self->calculate_relevance($link, $source_article);
        
        if ($relevance >= $self->min_relevance) {
            $link->{relevance_score} = $relevance;
            push @relevant_links, $link;
        }
    }
    
    # Sort by relevance score
    @relevant_links = sort { $b->{relevance_score} <=> $a->{relevance_score} } @relevant_links;
    
    $self->logger->info(sprintf(
        "Found %d relevant links out of %d total (%.1f%%)",
        scalar(@relevant_links),
        scalar(@$links),
        (scalar(@relevant_links) / scalar(@$links)) * 100
    ));
    
    return \@relevant_links;
}

# Calculate relevance score for a single link
sub calculate_relevance {
    my ($self, $link, $source_article) = @_;
    
    my $score = 0;
    my @factors;
    
    # Interest matching in title
    my $title_score = $self->_match_interests($link->{title});
    $score += $title_score * 0.4;  # 40% weight for title matching
    push @factors, "title:$title_score";
    
    # Interest matching in anchor text
    if ($link->{anchor_text}) {
        my $anchor_score = $self->_match_interests($link->{anchor_text});
        $score += $anchor_score * 0.2;  # 20% weight for anchor text
        push @factors, "anchor:$anchor_score";
    }
    
    # Boost keywords matching
    my $boost_score = $self->_match_boost_keywords($link->{title});
    if ($link->{anchor_text}) {
        $boost_score = max($boost_score, $self->_match_boost_keywords($link->{anchor_text}));
    }
    $score += $boost_score * 0.3;  # 30% weight for boost keywords
    push @factors, "boost:$boost_score";
    
    # Contextual relevance (if source article is available)
    if ($source_article) {
        my $context_score = $self->_calculate_context_score($link, $source_article);
        $score += $context_score * 0.1;  # 10% weight for context
        push @factors, "context:$context_score";
    }
    
    # Exploratory bonus - give small boost to any valid Wikipedia link
    # This ensures we always follow some links even without interest matches
    $score += 0.15;  # 15% baseline score for exploration
    
    $self->logger->debug(sprintf(
        "Link '%s' relevance: %.3f (%s)",
        $link->{title},
        $score,
        join(", ", @factors)
    ));
    
    return $score;
}

# Match text against interest keywords
sub _match_interests {
    my ($self, $text) = @_;
    
    return 0 unless $text && @{$self->interests};
    
    $text = lc(trim($text));
    my $max_score = 0;
    
    for my $interest (@{$self->interests}) {
        my $interest_lc = lc($interest);
        
        # Exact match gets highest score
        if ($text eq $interest_lc) {
            $max_score = max($max_score, 1.0);
        }
        # Substring match
        elsif ($text =~ /\Q$interest_lc\E/) {
            $max_score = max($max_score, 0.8);
        }
        # Word boundary match
        elsif ($text =~ /\b\Q$interest_lc\E\b/) {
            $max_score = max($max_score, 0.9);
        }
        # Partial word match
        elsif ($interest_lc =~ /\b\Q$text\E\b/ && length($text) > 3) {
            $max_score = max($max_score, 0.6);
        }
    }
    
    return $max_score;
}

# Match against boost keywords
sub _match_boost_keywords {
    my ($self, $text) = @_;
    
    return 0 unless $text && @{$self->boost_keywords};
    
    $text = lc(trim($text));
    my $score = 0;
    my $matches = 0;
    
    for my $keyword (@{$self->boost_keywords}) {
        my $keyword_lc = lc($keyword);
        
        if ($text =~ /\b\Q$keyword_lc\E\b/) {
            $score += 1.0;
            $matches++;
        } elsif ($text =~ /\Q$keyword_lc\E/) {
            $score += 0.5;
            $matches++;
        }
    }
    
    # Normalize score based on number of boost keywords
    if ($matches > 0) {
        $score = $score / @{$self->boost_keywords};
        # Cap at 1.0
        $score = $score > 1.0 ? 1.0 : $score;
    }
    
    return $score;
}

# Calculate contextual relevance based on source article
sub _calculate_context_score {
    my ($self, $link, $source_article) = @_;
    
    my $score = 0;
    
    # Check if link title appears in source article content
    if ($source_article->{content}) {
        my $content_lc = lc($source_article->{content});
        my $link_title_lc = lc($link->{title});
        
        # Count mentions
        my $mentions = () = $content_lc =~ /\Q$link_title_lc\E/g;
        if ($mentions > 0) {
            # More mentions = higher relevance, but with diminishing returns
            $score += ($mentions > 5 ? 5 : $mentions) / 10;
        }
    }
    
    # Check category overlap
    if ($source_article->{categories} && @{$source_article->{categories}}) {
        my $category_score = $self->_match_interests(join(" ", @{$source_article->{categories}}));
        $score += $category_score * 0.3;
    }
    
    # Check if in same topic area (simplified heuristic)
    if ($self->_is_same_topic_area($link->{title}, $source_article->{title})) {
        $score += 0.2;
    }
    
    return $score > 1.0 ? 1.0 : $score;
}

# Simple heuristic to check if two articles are in the same topic area
sub _is_same_topic_area {
    my ($self, $title1, $title2) = @_;
    
    return 0 unless $title1 && $title2;
    
    # Convert to lowercase and split into words
    my @words1 = split(/\s+/, lc($title1));
    my @words2 = split(/\s+/, lc($title2));
    
    # Remove common stop words
    my %stopwords = map { $_ => 1 } qw(the a an and or but in on at to for of with);
    @words1 = grep { !$stopwords{$_} && length($_) > 2 } @words1;
    @words2 = grep { !$stopwords{$_} && length($_) > 2 } @words2;
    
    # Check for common words
    my %words1_hash = map { $_ => 1 } @words1;
    my $common = 0;
    
    for my $word (@words2) {
        $common++ if $words1_hash{$word};
    }
    
    # If more than 25% of words are common, consider same topic area
    my $total_words = @words1 + @words2;
    return $total_words > 0 && ($common * 2 / $total_words) > 0.25;
}

# Filter links based on various criteria
sub filter_links {
    my ($self, $links, %options) = @_;
    
    return [] unless $links && @$links;
    
    my @filtered = @$links;
    
    # Filter by minimum relevance score
    if (defined $options{min_relevance}) {
        @filtered = grep { $_->{relevance_score} >= $options{min_relevance} } @filtered;
    }
    
    # Filter by maximum count
    if ($options{max_count} && @filtered > $options{max_count}) {
        @filtered = splice(@filtered, 0, $options{max_count});
    }
    
    # Filter out certain patterns
    if ($options{exclude_patterns}) {
        my @patterns = @{$options{exclude_patterns}};
        for my $pattern (@patterns) {
            @filtered = grep { $_->{title} !~ /$pattern/i } @filtered;
        }
    }
    
    # Deduplicate by title
    if ($options{deduplicate}) {
        my %seen;
        @filtered = grep { !$seen{$_->{title}}++ } @filtered;
    }
    
    return \@filtered;
}

# Update interests dynamically
sub set_interests {
    my ($self, $interests) = @_;
    
    $self->interests($interests || []);
    $self->logger->info("Updated interests: " . join(", ", @{$self->interests}));
}

# Extract and add interests from article content (adaptive learning)
sub extract_interests_from_article {
    my ($self, $article) = @_;
    
    return unless $article && $article->{title};
    
    my @new_interests;
    
    # Extract keywords from title (split and clean)
    my @title_words = split(/[^\w\s]/, lc($article->{title}));
    for my $word (@title_words) {
        $word = trim($word);
        next unless $word && length($word) > 3;
        next if $word =~ /^(the|and|for|with|from|into|that|this|they|them|their|there|then)$/;
        push @new_interests, $word;
    }
    
    # Extract from categories if available
    if ($article->{categories} && @{$article->{categories}}) {
        for my $category (@{$article->{categories}}) {
            my @cat_words = split(/[^\w\s]/, lc($category));
            for my $word (@cat_words) {
                $word = trim($word);
                next unless $word && length($word) > 3;
                push @new_interests, $word;
            }
        }
    }
    
    # Add to current interests if not already present
    my %current = map { lc($_) => 1 } @{$self->interests};
    my @filtered_new = grep { !$current{lc($_)} } @new_interests;
    
    if (@filtered_new) {
        my @combined = (@{$self->interests}, @filtered_new[0..min(4, $#filtered_new)]); # Add up to 5 new interests
        $self->interests(\@combined);
        $self->logger->info("Extracted interests from article '$article->{title}': " . join(", ", @filtered_new[0..min(4, $#filtered_new)]));
    }
}

# Add boost keywords
sub add_boost_keywords {
    my ($self, $keywords) = @_;
    
    return unless $keywords;
    
    my @current = @{$self->boost_keywords};
    push @current, @$keywords;
    
    # Remove duplicates
    my %seen;
    @current = grep { !$seen{lc($_)}++ } @current;
    
    $self->boost_keywords(\@current);
    $self->logger->info("Added boost keywords: " . join(", ", @$keywords));
}

# Get link recommendations for an article
sub get_recommendations {
    my ($self, $article, $candidate_links, %options) = @_;
    
    my $max_recommendations = $options{limit} || 10;
    
    # Analyze all candidate links
    my $analyzed_links = $self->analyze_links($candidate_links, $article);
    
    # Filter and sort
    my $filtered_links = $self->filter_links(
        $analyzed_links,
        min_relevance => $options{min_relevance} || $self->min_relevance,
        max_count     => $max_recommendations,
        deduplicate   => 1,
    );
    
    return $filtered_links;
}

1;

__END__

=head1 NAME

WikiCrawler::LinkAnalyzer - Intelligent link analysis and filtering

=head1 SYNOPSIS

    use WikiCrawler::LinkAnalyzer;
    
    my $analyzer = WikiCrawler::LinkAnalyzer->new(
        config => $config_hashref
    );
    
    $analyzer->set_interests(['programming', 'algorithms']);
    my $relevant_links = $analyzer->analyze_links($links, $source_article);

=head1 DESCRIPTION

This module analyzes Wikipedia links and determines their relevance based on
configured interests and contextual factors. It provides intelligent filtering
to build personalized knowledge graphs.

=head1 METHODS

=head2 analyze_links($links, $source_article)

Analyzes an array of links and returns those meeting relevance criteria.

=head2 calculate_relevance($link, $source_article)

Calculates a relevance score (0-1) for a single link.

=head2 set_interests($interests_arrayref)

Updates the list of interest keywords for filtering.

=head1 AUTHOR

WikiCrawler Project

=cut
