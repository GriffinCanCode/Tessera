package Tessera::Logger;

use strict;
use warnings;
use v5.20;

use Log::Log4perl;
use Log::Log4perl::Appender::ScreenColoredLevels;
use Term::ANSIColor qw(colored);
use File::Spec;
use File::Path qw(make_path);
use Time::HiRes qw(time);
use Data::Dumper;

use Moo;
use namespace::clean;

=head1 NAME

Tessera::Logger - Centralized logging configuration for Tessera

=head1 DESCRIPTION

Modern structured logging with colors, organization, and strategic placement
Features:
- Colored console output with emoji indicators
- File logging with rotation
- Performance metrics tracking
- Structured context data
- Strategic log placement

=cut

# Class attributes
has 'service_name' => (
    is       => 'ro',
    required => 1,
);

has 'log_level' => (
    is      => 'ro',
    default => 'INFO',
);

has 'log_file' => (
    is      => 'lazy',
    builder => '_build_log_file',
);

has 'logger' => (
    is      => 'lazy',
    builder => '_build_logger',
);

has '_start_times' => (
    is      => 'rw',
    default => sub { {} },
);

# Build log file path
sub _build_log_file {
    my $self = shift;
    my $service = lc($self->service_name);
    $service =~ s/\s+/_/g;
    return "logs/tessera_${service}.log";
}

# Initialize enhanced logging
sub _build_logger {
    my $self = shift;
    
    my $log_level = $self->log_level;
    my $log_file = $self->log_file;
    
    # Ensure log directory exists
    my $log_dir = File::Spec->rel2abs((File::Spec->splitpath($log_file))[1]);
    unless (-d $log_dir) {
        make_path($log_dir);
    }
    
    # Enhanced log configuration with colors and structure
    my $log_config = qq{
        log4perl.rootLogger = $log_level, ColorScreen, FileAppender
        
        # Colored console output
        log4perl.appender.ColorScreen = Log::Log4perl::Appender::ScreenColoredLevels
        log4perl.appender.ColorScreen.stderr = 0
        log4perl.appender.ColorScreen.layout = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.ColorScreen.layout.ConversionPattern = [%d{HH:mm:ss}] %p %c{2} - %m%n
        
        # File output with detailed format
        log4perl.appender.FileAppender = Log::Log4perl::Appender::File
        log4perl.appender.FileAppender.filename = $log_file
        log4perl.appender.FileAppender.mode = append
        log4perl.appender.FileAppender.layout = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.FileAppender.layout.ConversionPattern = [%d{ISO8601}] %p %c - %m%n
        log4perl.appender.FileAppender.utf8 = 1
    };
    
    Log::Log4perl->init(\$log_config);
    
    return Log::Log4perl->get_logger($self->service_name);
}

# Service lifecycle logging
sub log_service_start {
    my ($self, %context) = @_;
    
    my $emoji = "🚀";
    my $message = sprintf("%s Starting %s", $emoji, $self->service_name);
    
    if ($context{port}) {
        $message .= sprintf(" on port %d", $context{port});
    }
    
    $self->logger->info($message);
    
    if (%context) {
        $self->logger->debug("Service context: " . $self->_format_context(%context));
    }
}

sub log_service_ready {
    my ($self, %context) = @_;
    
    my $emoji = "✅";
    my $message = sprintf("%s %s ready", $emoji, $self->service_name);
    
    $self->logger->info($message);
    
    if (%context) {
        $self->logger->debug("Ready context: " . $self->_format_context(%context));
    }
}

sub log_service_shutdown {
    my ($self, %context) = @_;
    
    my $emoji = "🛑";
    my $message = sprintf("%s Shutting down %s", $emoji, $self->service_name);
    
    $self->logger->info($message);
}

# API request/response logging
sub log_api_request {
    my ($self, $method, $path, %context) = @_;
    
    my $emoji = "🌐";
    my $message = sprintf("%s %s %s", $emoji, $method, $path);
    
    $self->logger->info($message);
    
    if (%context) {
        $self->logger->debug("Request context: " . $self->_format_context(%context));
    }
    
    # Store start time for response logging
    my $request_id = $self->_generate_request_id($method, $path);
    $self->_start_times->{$request_id} = time();
}

sub log_api_response {
    my ($self, $method, $path, $status_code, %context) = @_;
    
    # Calculate duration
    my $request_id = $self->_generate_request_id($method, $path);
    my $start_time = delete $self->_start_times->{$request_id};
    my $duration_ms = $start_time ? sprintf("%.1f", (time() - $start_time) * 1000) : "?";
    
    # Color code by status
    my ($emoji, $level);
    if ($status_code < 300) {
        $emoji = "✅";
        $level = "info";
    } elsif ($status_code < 400) {
        $emoji = "⚠️";
        $level = "warn";
    } else {
        $emoji = "❌";
        $level = "error";
    }
    
    my $message = sprintf("%s %s %s → %d (%sms)", 
                         $emoji, $method, $path, $status_code, $duration_ms);
    
    if ($level eq 'info') {
        $self->logger->info($message);
    } elsif ($level eq 'warn') {
        $self->logger->warn($message);
    } else {
        $self->logger->error($message);
    }
    
    if (%context) {
        $self->logger->debug("Response context: " . $self->_format_context(%context));
    }
}

# Database operations
sub log_database_operation {
    my ($self, $operation, $table, %context) = @_;
    
    my $emoji = "🗄️";
    my $message = sprintf("%s %s on %s", $emoji, $operation, $table);
    
    $self->logger->debug($message);
    
    if (%context) {
        $self->logger->debug("DB context: " . $self->_format_context(%context));
    }
}

# Processing tasks
sub log_processing_start {
    my ($self, $task, %context) = @_;
    
    my $emoji = "⚙️";
    my $message = sprintf("%s Starting: %s", $emoji, $task);
    
    $self->logger->info($message);
    
    # Store start time
    my $task_id = $self->_generate_task_id($task);
    $self->_start_times->{$task_id} = time();
    
    if (%context) {
        $self->logger->debug("Processing context: " . $self->_format_context(%context));
    }
}

sub log_processing_complete {
    my ($self, $task, %context) = @_;
    
    # Calculate duration
    my $task_id = $self->_generate_task_id($task);
    my $start_time = delete $self->_start_times->{$task_id};
    my $duration_ms = $start_time ? sprintf("%.1f", (time() - $start_time) * 1000) : "?";
    
    my $emoji = "✅";
    my $message = sprintf("%s Completed: %s (%sms)", $emoji, $task, $duration_ms);
    
    $self->logger->info($message);
    
    if (%context) {
        $self->logger->debug("Completion context: " . $self->_format_context(%context));
    }
}

# Error logging
sub log_error {
    my ($self, $error_msg, $context_msg, %context) = @_;
    
    my $emoji = "❌";
    my $message = sprintf("%s %s: %s", $emoji, $context_msg, $error_msg);
    
    $self->logger->error($message);
    
    if (%context) {
        $self->logger->error("Error context: " . $self->_format_context(%context));
    }
}

# Performance metrics
sub log_performance_metric {
    my ($self, $metric_name, $value, $unit, %context) = @_;
    
    $unit //= "ms";
    
    my $emoji = "📊";
    my $message = sprintf("%s %s: %.2f%s", $emoji, $metric_name, $value, $unit);
    
    $self->logger->info($message);
    
    if (%context) {
        $self->logger->debug("Metric context: " . $self->_format_context(%context));
    }
}

# External API calls
sub log_external_api_call {
    my ($self, $service, $endpoint, %context) = @_;
    
    my $emoji = "🔗";
    my $message = sprintf("%s Calling %s: %s", $emoji, $service, $endpoint);
    
    $self->logger->info($message);
    
    if (%context) {
        $self->logger->debug("External API context: " . $self->_format_context(%context));
    }
}

# Cache operations
sub log_cache_operation {
    my ($self, $operation, $key, %context) = @_;
    
    my $emoji = $operation eq 'hit' ? "🎯" : $operation eq 'miss' ? "❌" : "💾";
    my $message = sprintf("%s Cache %s: %s", $emoji, $operation, $key);
    
    $self->logger->debug($message);
    
    if (%context) {
        $self->logger->debug("Cache context: " . $self->_format_context(%context));
    }
}

# R integration
sub log_r_operation {
    my ($self, $operation, %context) = @_;
    
    my $emoji = "📈";
    my $message = sprintf("%s R operation: %s", $emoji, $operation);
    
    $self->logger->info($message);
    
    if (%context) {
        $self->logger->debug("R context: " . $self->_format_context(%context));
    }
}

# Private helper methods
sub _format_context {
    my ($self, %context) = @_;
    
    return "" unless %context;
    
    my @parts;
    for my $key (sort keys %context) {
        my $value = $context{$key};
        if (ref $value) {
            $value = Data::Dumper->new([$value])->Terse(1)->Indent(0)->Dump;
            chomp $value;
        }
        push @parts, "$key=$value";
    }
    
    return join(", ", @parts);
}

sub _generate_request_id {
    my ($self, $method, $path) = @_;
    return "${method}:${path}:" . time();
}

sub _generate_task_id {
    my ($self, $task) = @_;
    return "${task}:" . time();
}

# Convenience class method for getting logger instances
sub get_logger {
    my ($class, $service_name, %options) = @_;
    
    return $class->new(
        service_name => $service_name,
        %options
    );
}

1;

__END__

=head1 USAGE

    use Tessera::Logger;
    
    # Create logger instance
    my $logger = Tessera::Logger->get_logger('MyService');
    
    # Service lifecycle
    $logger->log_service_start(port => 3000);
    $logger->log_service_ready();
    
    # API logging
    $logger->log_api_request('GET', '/api/search', query => 'test');
    $logger->log_api_response('GET', '/api/search', 200);
    
    # Processing tasks
    $logger->log_processing_start('data_analysis');
    $logger->log_processing_complete('data_analysis');
    
    # Error handling
    $logger->log_error($@, "Failed to process data", id => 123);
    
    # Performance metrics
    $logger->log_performance_metric('query_time', 45.2, 'ms');

=head1 AUTHOR

Tessera Project

=cut
