package Tessera::Parser;

use strict;
use warnings;
use v5.20;

use HTML::TreeBuilder;
use HTML::Element;
use Text::Trim qw(trim);
use URI;
use URI::Escape;
use Encode qw(decode_utf8);
use Log::Log4perl;

use Moo;
use namespace::clean;

# Attributes
has 'config' => (
    is       => 'ro',
    required => 1,
);

has 'logger' => (
    is      => 'lazy',
    builder => '_build_logger',
);

sub _build_logger {
    my $self = shift;
    return Log::Log4perl->get_logger(__PACKAGE__);
}

# Parse Wikipedia page HTML and extract structured data
sub parse_page {
    my ($self, $html, $url) = @_;
    
    return unless $html && $url;
    
    $self->logger->debug("Parsing page: $url");
    
    my $tree = HTML::TreeBuilder->new();
    $tree->parse_content($html);
    $tree->eof();
    
    my $data = {
        url => $url,
        title => $self->_extract_title($tree),
        content => $self->_extract_main_content($tree),
        summary => $self->_extract_summary($tree),
        infobox => $self->_extract_infobox($tree),
        categories => $self->_extract_categories($tree),
        links => $self->_extract_links($tree, $url),
        images => $self->_extract_images($tree),
        sections => $self->_extract_sections($tree),
        coordinates => $self->_extract_coordinates($tree),
        parsed_at => time(),
    };
    
    # RAG: Create semantic chunks automatically
    $data->{chunks} = $self->create_semantic_chunks($data);
    
    $tree->delete();
    
    return $data;
}

# Extract article title
sub _extract_title {
    my ($self, $tree) = @_;
    
    # Try h1.firstHeading first (main article title)
    my $title_elem = $tree->look_down('_tag' => 'h1', 'class' => qr/firstHeading/);
    if ($title_elem) {
        return trim($title_elem->as_text);
    }
    
    # Fallback to page title
    my $title_tag = $tree->look_down('_tag' => 'title');
    if ($title_tag) {
        my $title = $title_tag->as_text;
        $title =~ s/ - Wikipedia$//;
        return trim($title);
    }
    
    return '';
}

# Extract main content from the article
sub _extract_main_content {
    my ($self, $tree) = @_;
    
    my $content_elem = $tree->look_down('_tag' => 'div', 'id' => 'mw-content-text');
    return '' unless $content_elem;
    
    # Remove unwanted elements
    $self->_clean_content($content_elem);
    
    return trim($content_elem->as_text);
}

# Extract article summary (first paragraph)
sub _extract_summary {
    my ($self, $tree) = @_;
    
    my $content_elem = $tree->look_down('_tag' => 'div', 'id' => 'mw-content-text');
    return '' unless $content_elem;
    
    # Find the first paragraph that's not empty
    my @paragraphs = $content_elem->look_down('_tag' => 'p');
    
    for my $p (@paragraphs) {
        next unless $p;
        
        my $text = trim($p->as_text);
        next unless $text;
        next if length($text) < 50; # Skip very short paragraphs
        
        return $text;
    }
    
    return '';
}

# Extract infobox data
sub _extract_infobox {
    my ($self, $tree) = @_;
    
    my $infobox = $tree->look_down('_tag' => 'table', 'class' => qr/infobox/);
    return {} unless $infobox;
    
    my %data;
    
    # Extract key-value pairs from infobox rows
    my @rows = $infobox->look_down('_tag' => 'tr');
    
    for my $row (@rows) {
        next unless $row;
        
        my @cells = $row->look_down('_tag' => qr/^(td|th)$/);
        next unless @cells >= 2;
        
        my $key = trim($cells[0]->as_text);
        my $value = trim($cells[1]->as_text);
        
        next unless $key && $value;
        
        # Clean up key
        $key =~ s/^\s*|\s*$//g;
        $key = lc($key);
        $key =~ s/[^\w\s]//g;
        $key =~ s/\s+/_/g;
        
        $data{$key} = $value;
    }
    
    return \%data;
}

# Extract categories
sub _extract_categories {
    my ($self, $tree) = @_;
    
    my @categories;
    
    # Look for category links
    my @cat_links = $tree->look_down('_tag' => 'a', 'href' => qr|^/wiki/Category:|);
    
    for my $link (@cat_links) {
        next unless $link;
        
        my $href = $link->attr('href') || '';
        if ($href =~ m|^/wiki/Category:(.+)$|) {
            my $category = uri_unescape($1);
            $category =~ s/_/ /g;
            push @categories, $category;
        }
    }
    
    return \@categories;
}

# Extract internal Wikipedia links
sub _extract_links {
    my ($self, $tree, $base_url) = @_;
    
    my @links;
    my %seen;
    
    # Find content area to avoid navigation links
    my $content_elem = $tree->look_down('_tag' => 'div', 'id' => 'mw-content-text');
    return \@links unless $content_elem;
    
    # Look for Wikipedia article links
    my @wiki_links = $content_elem->look_down('_tag' => 'a', 'href' => qr|^/wiki/[^:]+|);
    
    for my $link (@wiki_links) {
        next unless $link;
        
        my $href = $link->attr('href') || '';
        next unless $href =~ m|^/wiki/([^#?]+)|;
        
        my $title = uri_unescape($1);
        $title =~ s/_/ /g;
        
        # Skip if we've already seen this link
        next if $seen{$title}++;
        
        # Skip certain types of pages
        next if $title =~ /^(File|Category|Template|Help|Special):/;
        next if $title =~ /^(Talk|User|Wikipedia|MediaWiki):/;
        
        my $full_url = URI->new_abs($href, $base_url)->as_string;
        my $anchor_text = trim($link->as_text);
        
        push @links, {
            title => $title,
            url => $full_url,
            anchor_text => $anchor_text,
        };
    }
    
    return \@links;
}

# Extract images
sub _extract_images {
    my ($self, $tree) = @_;
    
    my @images;
    my %seen;
    
    # Look for images in content area
    my $content_elem = $tree->look_down('_tag' => 'div', 'id' => 'mw-content-text');
    return \@images unless $content_elem;
    
    my @img_tags = $content_elem->look_down('_tag' => 'img');
    
    for my $img (@img_tags) {
        next unless $img;
        
        my $src = $img->attr('src') || '';
        next unless $src;
        
        # Skip if we've seen this image
        next if $seen{$src}++;
        
        # Skip very small images (likely icons)
        my $width = $img->attr('width') || 0;
        my $height = $img->attr('height') || 0;
        next if ($width && $width < 50) || ($height && $height < 50);
        
        push @images, {
            src => $src,
            alt => $img->attr('alt') || '',
            width => $width,
            height => $height,
        };
    }
    
    return \@images;
}

# Extract section headings
sub _extract_sections {
    my ($self, $tree) = @_;
    
    my @sections;
    
    my $content_elem = $tree->look_down('_tag' => 'div', 'id' => 'mw-content-text');
    return \@sections unless $content_elem;
    
    # Look for heading tags
    my @headings = $content_elem->look_down('_tag' => qr/^h[1-6]$/);
    
    for my $heading (@headings) {
        next unless $heading;
        
        my $level = $heading->tag;
        $level =~ s/^h//;
        
        my $text = trim($heading->as_text);
        next unless $text;
        
        # Skip edit links
        $text =~ s/\[edit\]$//;
        $text = trim($text);
        
        push @sections, {
            level => int($level),
            title => $text,
        };
    }
    
    return \@sections;
}

# Extract coordinates if present
sub _extract_coordinates {
    my ($self, $tree) = @_;
    
    # Look for geo microformat
    my $geo_elem = $tree->look_down('_tag' => 'span', 'class' => 'geo');
    if ($geo_elem) {
        my $coords_text = $geo_elem->as_text;
        if ($coords_text =~ /([+-]?\d+(?:\.\d+)?)[;,\s]+([+-]?\d+(?:\.\d+)?)/) {
            return {
                latitude => $1 + 0,
                longitude => $2 + 0,
            };
        }
    }
    
    return {};
}

# Clean content by removing unwanted elements
sub _clean_content {
    my ($self, $elem) = @_;
    
    return unless $elem;
    
    # Remove unwanted elements by class patterns
    my @class_patterns = qw(navbox infobox thumb mw-references-wrap references reference mw-editsection);
    my @unwanted_selectors;
    
    for my $pattern (@class_patterns) {
        push @unwanted_selectors, sub { 
            $_[0]->attr('class') && $_[0]->attr('class') =~ /$pattern/
        };
    }
    
    for my $selector (@unwanted_selectors) {
        my @elements = $elem->look_down($selector);
        $_->delete() for @elements;
    }
}

# RAG: Create semantic chunks from parsed article
sub create_semantic_chunks {
    my ($self, $article_data) = @_;
    
    return [] unless $article_data;
    
    my @chunks = ();
    my $title = $article_data->{title} || '';
    my $content = $article_data->{content} || '';
    my $sections = $article_data->{sections} || [];
    
    # Chunk 1: Summary (if available and substantial)
    if ($article_data->{summary} && length($article_data->{summary}) > 100) {
        push @chunks, {
            type => 'summary',
            section_name => undef,
            content => $article_data->{summary},
            token_count => $self->_estimate_tokens($article_data->{summary}),
        };
    }
    
    # Chunk 2-N: Section-based chunking with intelligent splitting
    for my $section (@$sections) {
        my $section_title = $section->{title} || 'Untitled Section';
        my $section_text = $self->_extract_section_text($content, $section);
        
        next unless $section_text && length($section_text) > 50;
        
        # For large sections, split by paragraphs
        if (length($section_text) > 800) {
            my @section_chunks = $self->_split_large_section($section_text, $section_title);
            push @chunks, @section_chunks;
        } else {
            # Small section goes as single chunk
            push @chunks, {
                type => 'section',
                section_name => $section_title,
                content => $section_text,
                token_count => $self->_estimate_tokens($section_text),
            };
        }
    }
    
    # If no sections found, chunk by paragraphs
    if (!@chunks && $content) {
        my @paragraph_chunks = $self->_chunk_by_paragraphs($content);
        push @chunks, @paragraph_chunks;
    }
    
    $self->logger->debug("Created " . scalar(@chunks) . " chunks for article: $title");
    
    return \@chunks;
}

# Extract text content for a specific section
sub _extract_section_text {
    my ($self, $full_content, $section) = @_;
    
    my $section_title = $section->{title} || '';
    return '' unless $section_title;
    
    # Try to find section content using the section title as delimiter
    # This is a simplified approach - could be enhanced with HTML parsing
    if ($full_content =~ /\Q$section_title\E\s*(.*?)(?=\n\n[A-Z]|\n\n==|\z)/s) {
        my $section_text = $1 || '';
        $section_text = trim($section_text);
        
        # Clean up the section text
        $section_text =~ s/\n+/ /g;  # Replace newlines with spaces
        $section_text =~ s/\s+/ /g;  # Normalize whitespace
        
        return $section_text;
    }
    
    return '';
}

# Split large sections into smaller chunks
sub _split_large_section {
    my ($self, $section_text, $section_title) = @_;
    
    my @chunks = ();
    my @paragraphs = split /\n\n+/, $section_text;
    my $current_chunk = '';
    my $chunk_part = 1;
    
    for my $paragraph (@paragraphs) {
        $paragraph = trim($paragraph);
        next unless $paragraph;
        
        # Check if adding this paragraph would exceed our chunk size
        my $potential_chunk = $current_chunk ? "$current_chunk\n\n$paragraph" : $paragraph;
        
        if (length($potential_chunk) > 600 && $current_chunk) {
            # Save current chunk and start a new one
            push @chunks, {
                type => 'section_part',
                section_name => "$section_title (Part $chunk_part)",
                content => $current_chunk,
                token_count => $self->_estimate_tokens($current_chunk),
            };
            
            $current_chunk = $paragraph;
            $chunk_part++;
        } else {
            $current_chunk = $potential_chunk;
        }
    }
    
    # Add the final chunk if there's content
    if ($current_chunk) {
        my $final_title = $chunk_part > 1 ? "$section_title (Part $chunk_part)" : $section_title;
        push @chunks, {
            type => $chunk_part > 1 ? 'section_part' : 'section',
            section_name => $final_title,
            content => $current_chunk,
            token_count => $self->_estimate_tokens($current_chunk),
        };
    }
    
    return @chunks;
}

# Fallback chunking by paragraphs when no sections
sub _chunk_by_paragraphs {
    my ($self, $content) = @_;
    
    my @chunks = ();
    my @paragraphs = split /\n\n+/, $content;
    my $current_chunk = '';
    my $chunk_num = 1;
    
    for my $paragraph (@paragraphs) {
        $paragraph = trim($paragraph);
        next unless $paragraph;
        next if length($paragraph) < 30;  # Skip very short paragraphs
        
        my $potential_chunk = $current_chunk ? "$current_chunk\n\n$paragraph" : $paragraph;
        
        if (length($potential_chunk) > 600 && $current_chunk) {
            # Save current chunk
            push @chunks, {
                type => 'paragraph',
                section_name => "Content Part $chunk_num",
                content => $current_chunk,
                token_count => $self->_estimate_tokens($current_chunk),
            };
            
            $current_chunk = $paragraph;
            $chunk_num++;
        } else {
            $current_chunk = $potential_chunk;
        }
    }
    
    # Add final chunk
    if ($current_chunk) {
        push @chunks, {
            type => 'paragraph',
            section_name => "Content Part $chunk_num",
            content => $current_chunk,
            token_count => $self->_estimate_tokens($current_chunk),
        };
    }
    
    return @chunks;
}

# Estimate token count for content
sub _estimate_tokens {
    my ($self, $content) = @_;
    
    return 0 unless $content;
    
    # Rough estimate: 1 token ≈ 4 characters for English text
    # This is a simplified estimation - could use a proper tokenizer
    return int(length($content) / 4);
}

1;

__END__

=head1 NAME

Tessera::Parser - HTML parser for Wikipedia pages

=head1 SYNOPSIS

    use Tessera::Parser;
    
    my $parser = Tessera::Parser->new(
        config => $config_hashref
    );
    
    my $data = $parser->parse_page($html, $url);

=head1 DESCRIPTION

This module parses Wikipedia HTML pages and extracts structured data including
article content, metadata, links, categories, and more.

=head1 METHODS

=head2 parse_page($html, $url)

Parses HTML content and returns structured data about the Wikipedia article.

=head1 AUTHOR

Tessera Project

=cut
