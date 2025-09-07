package TestHelper;

use strict;
use warnings;
use v5.20;

use Exporter 'import';
our @EXPORT = qw(
    get_test_config
    create_test_storage
    create_mock_html
    create_mock_article_data
    create_mock_links
    get_sample_wikipedia_html
    create_sample_article
    generate_sample_content
    generate_sample_categories
);

use Moo;

use YAML::XS qw(LoadFile);
use File::Spec;
use FindBin;

# Get test configuration
sub get_test_config {
    my $config_file = File::Spec->catfile($FindBin::Bin, 'test_config.yaml');
    my $config = LoadFile($config_file);
    
    # Initialize Log4perl for testing (allow all levels but send to stderr)
    require Log::Log4perl;
    Log::Log4perl->init(\qq{
        log4perl.rootLogger = ERROR, ScreenAppender
        log4perl.appender.ScreenAppender = Log::Log4perl::Appender::Screen
        log4perl.appender.ScreenAppender.stderr = 1
        log4perl.appender.ScreenAppender.layout = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.ScreenAppender.layout.ConversionPattern = [TEST] %p - %m%n
    });
    
    return $config;
}

# Create test storage instance
sub create_test_storage {
    require Tessera::Storage;
    my $config = get_test_config();
    return Tessera::Storage->new(config => $config);
}

# Create mock HTML content for testing
sub create_mock_html {
    my ($title, $content) = @_;
    $title ||= "Test Article";
    $content ||= "This is test content for the article.";
    
    return qq{
<!DOCTYPE html>
<html>
<head>
    <title>$title - Wikipedia</title>
</head>
<body>
    <div id="content">
        <h1 class="firstHeading">$title</h1>
        <div id="mw-content-text">
            <div class="mw-parser-output">
                <p>$content</p>
                <p>This article contains information about <a href="/wiki/Related_Article">Related Article</a>.</p>
                <div class="infobox">
                    <table class="infobox">
                        <tr><th>Type</th><td>Test</td></tr>
                        <tr><th>Category</th><td>Testing</td></tr>
                    </table>
                </div>
                <h2>Section One</h2>
                <p>Content for section one.</p>
                <h3>Subsection</h3>
                <p>Content for subsection.</p>
            </div>
        </div>
    </div>
    <div id="catlinks">
        <a href="/wiki/Category:Test_Articles">Test Articles</a>
        <a href="/wiki/Category:Sample_Data">Sample Data</a>
    </div>
</body>
</html>
    };
}

# Create mock article data structure
sub create_mock_article_data {
    my ($title, %options) = @_;
    $title ||= "Test Article";
    
    return {
        title => $title,
        url => "https://en.wikipedia.org/wiki/" . $title =~ s/ /_/gr,
        content => $options{content} || "This is test content for $title.",
        summary => $options{summary} || "Test summary for $title.",
        infobox => $options{infobox} || { type => 'Test', category => 'Testing' },
        categories => $options{categories} || ['Test Articles', 'Sample Data'],
        sections => $options{sections} || [
            { level => 2, title => 'Section One' },
            { level => 3, title => 'Subsection' }
        ],
        images => $options{images} || [
            { src => '/static/test.jpg', alt => 'Test image', width => 200, height => 150 }
        ],
        coordinates => $options{coordinates} || {},
        links => $options{links} || create_mock_links(),
        parsed_at => time(),
    };
}

# Create mock links array
sub create_mock_links {
    return [
        {
            title => 'Related Article',
            url => 'https://en.wikipedia.org/wiki/Related_Article',
            anchor_text => 'Related Article',
        },
        {
            title => 'Test Topic',
            url => 'https://en.wikipedia.org/wiki/Test_Topic',
            anchor_text => 'test topic',
        },
        {
            title => 'Sample Page',
            url => 'https://en.wikipedia.org/wiki/Sample_Page',
            anchor_text => 'sample page',
        },
    ];
}

# Get sample Wikipedia HTML for parser testing
sub get_sample_wikipedia_html {
    return qq{
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Artificial Intelligence - Wikipedia</title>
</head>
<body>
    <div id="content">
        <h1 class="firstHeading">Artificial Intelligence</h1>
        <div id="mw-content-text">
            <div class="mw-parser-output">
                <p><b>Artificial intelligence</b> (AI) is intelligence demonstrated by machines, in contrast to the natural intelligence displayed by humans and animals.</p>
                
                <table class="infobox">
                    <tr><th colspan="2">Artificial Intelligence</th></tr>
                    <tr><td>Type</td><td>Computer Science Field</td></tr>
                    <tr><td>Founded</td><td>1956</td></tr>
                </table>
                
                <p>Leading AI textbooks define the field as the study of <a href="/wiki/Intelligent_agent">"intelligent agents"</a>.</p>
                
                <h2>History</h2>
                <p>The field of AI research was born at <a href="/wiki/Dartmouth_workshop">Dartmouth College</a> in 1956.</p>
                
                <h3>Early development</h3>
                <p>Early AI researchers included <a href="/wiki/Alan_Turing">Alan Turing</a> and <a href="/wiki/John_McCarthy_(computer_scientist)">John McCarthy</a>.</p>
                
                <div class="thumb">
                    <img src="//upload.wikimedia.org/wikipedia/commons/thumb/ai_robot.jpg/220px-ai_robot.jpg" 
                         alt="AI Robot" width="220" height="165">
                </div>
                
                <span class="geo">40.7589;-73.9851</span>
            </div>
        </div>
    </div>
    
    <div id="catlinks">
        <div id="mw-normal-catlinks">
            <ul>
                <li><a href="/wiki/Category:Artificial_intelligence">Artificial intelligence</a></li>
                <li><a href="/wiki/Category:Computer_science">Computer science</a></li>
                <li><a href="/wiki/Category:Emerging_technologies">Emerging technologies</a></li>
            </ul>
        </div>
    </div>
</body>
</html>
    };
}

# Create sample article for benchmarks
sub create_sample_article {
    my ($self, %options) = @_;
    
    my $id = $options{id} || 1;
    my $title = $options{title} || "Test Article $id";
    my $content = $options{content} || generate_sample_content(500);
    my $categories = $options{categories} || generate_sample_categories(3);
    
    return {
        id => $id,
        title => $title,
        url => "https://en.wikipedia.org/wiki/" . ($title =~ s/ /_/gr),
        content => $content,
        summary => substr($content, 0, 200) . "...",
        categories => $categories,
        sections => [
            { level => 2, title => "Introduction" },
            { level => 2, title => "History" },
            { level => 3, title => "Early Development" },
            { level => 2, title => "Applications" }
        ],
        coordinates => {},
        parsed_at => time(),
    };
}

# Generate sample content of specified length
sub generate_sample_content {
    my ($length) = @_;
    $length ||= 500;
    
    my @words = qw(
        research study analysis investigation examination exploration
        development implementation application utilization methodology
        framework approach technique strategy process procedure
        concept principle theory hypothesis assumption conclusion
        algorithm computation calculation optimization performance
        system architecture design structure organization pattern
        data information knowledge intelligence learning understanding
        technology innovation advancement progress evolution transformation
        science mathematics physics chemistry biology psychology
        computer software hardware network database programming
    );
    
    my $content = "";
    while (length($content) < $length) {
        my $word = $words[int(rand(@words))];
        $content .= "$word ";
    }
    
    return substr($content, 0, $length);
}

# Generate sample categories
sub generate_sample_categories {
    my ($count) = @_;
    $count ||= 3;
    
    my @categories = qw(
        Computer_Science Mathematics Physics Chemistry Biology
        Technology Programming Algorithms Data_Structures
        Artificial_Intelligence Machine_Learning Research
        Academic_Topics Scientific_Methods Engineering
    );
    
    my @selected;
    for my $i (1..$count) {
        push @selected, $categories[int(rand(@categories))];
    }
    
    return \@selected;
}

1;
