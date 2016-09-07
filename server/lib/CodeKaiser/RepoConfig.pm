#!/bin/perl
{
    package CodeKaiser::RepoConfig;
    use strict;
    use warnings;
     
    use File::Spec;
    use File::Basename;
    use Scalar::Util;
    use Data::Dumper;

    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);

    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(new
                      github_token
                      reviewers_needed
                      blocking_enabled
                      blocking_timeout
                     );

    # Configuration File path key
    my  $CONFIG_FILE              = 'config_file';

    # GitHub OAuth token for a user, which will
    # be used to pull diffs, post PR statuses, etc.
    my  $GITHUB_TOKEN             = 'github_token';
    our $DEFAULT_GITHUB_TOKEN     = '000000000000';

    # How many individuals must sign off on a PR
    my  $REVIEWERS_NEEDED         = 'reviewers_needed';
    our $DEFAULT_REVIEWERS_NEEDED = 2;

    # If a reviewer can block a PR, even if enough
    # revierwers have signed off on the PR
    my  $BLOCKING_ENABLED         = 'blocking_enabled';
    our $DEFAULT_BLOCKING_ENABLED = 1;

    # How long (in hours) a block comment has effect for once
    # responded to. For example, an answered block comment
    # is automatically closed after 3 days, if the original
    # blocker does not close it himself. Use -1 for no-timeout
    my  $BLOCKING_TIMEOUT         = 'blocking_timeout';
    our $DEFAULT_BLOCKING_TIMEOUT = 120; # 5 day timeout

    ## Load a pull rules configuration file,
    ## creating a configuration file with defaults
    ## if none exists at specified path
    # Expects { config_file => <filename> }
    sub new($) {
        my ($class, %args) = @_;

        my $config_file = $args{config_file};
        if(! $config_file) {
            return undef;
        } else {
            my $config = load_config($config_file);
            return bless $config, $class;
        }
    }

    # Assert that config_file is defined
    sub assert_values {
        my ($self) = @_;
        if(!$self->{$CONFIG_FILE}) {
            die "No configuration file specified: $!";
        }
    }

    ## Get or set GitHub token
    # Argument: github_token (optional)
    # Return:   github_token
    sub github_token {
        my ($self, $value) = @_;
        if (@_ == 2) {
            if($value =~ /^[0-9a-fA-F]+$/) {           
                $self->{$GITHUB_TOKEN} = $value;
                write_config($self);
            } else {
                die 'Bad argument, expecting hex token';
            }
        }
        return $self->{$GITHUB_TOKEN};
    }

    ## Get or set GitHub token
    # Argument: repo_owner (optional)
    # Return:   repo_owner
    sub reviewers_needed {
        my ($self, $value) = @_;
        if (@_ == 2) {
            if(Scalar::Util::looks_like_number($value)) {           
                $self->{$REVIEWERS_NEEDED} = $value;
                write_config($self);
            } else {
                die 'Bad argument, expecting numeric';
            }
        }
        return $self->{$REVIEWERS_NEEDED};
    }

    ## Get or set GitHub token
    # Argument: repo_owner (optional)
    # Return:   repo_owner
    sub blocking_enabled {
        my ($self, $value) = @_;
        if (@_ == 2) {
            if(Scalar::Util::looks_like_number($value)) {           
                $self->{$BLOCKING_ENABLED} = $value;
                write_config($self);
            } else {
                die 'Bad argument, expecting numeric';
            }
        }
        return $self->{$BLOCKING_ENABLED};
    }

    ## Get or set GitHub token
    # Argument: repo_owner (optional)
    # Return:   repo_owner
    sub blocking_timeout {
        my ($self, $value) = @_;
        if (@_ == 2) {
            if(Scalar::Util::looks_like_number($value)) {           
                $self->{$BLOCKING_TIMEOUT} = $value;
                write_config($self);
            } else {
                die 'Bad argument, expecting numeric';
            }
        }
        return $self->{$BLOCKING_TIMEOUT};
    }

    # Write the configuration
    # to the config file - for use
    # when updating or saving configs
    sub write_config {
        my ($config) = @_;
        assert_values $config;

        my $dirname = dirname($config->{$CONFIG_FILE});
        system "mkdir -p $dirname" if $dirname;

        open(my $CONFIG, ">$config->{$CONFIG_FILE}") or die "Could not write config: $config->{$CONFIG_FILE}";
        print $CONFIG "$GITHUB_TOKEN     : $config->{$GITHUB_TOKEN}\n";
        print $CONFIG "$REVIEWERS_NEEDED : $config->{$REVIEWERS_NEEDED}\n";
        print $CONFIG "$BLOCKING_ENABLED : $config->{$BLOCKING_ENABLED}\n";
        print $CONFIG "$BLOCKING_TIMEOUT : $config->{$BLOCKING_TIMEOUT}\n";
        close($CONFIG);
    }

    # Load a configuration file into a hash,
    # creating a new configuration with defaults,
    # if needed
    sub load_config {
        my ($config_file) = @_;

        # Start with default values
        my %config_hash = ( $CONFIG_FILE      => $config_file,
                            $GITHUB_TOKEN     => $DEFAULT_GITHUB_TOKEN,
                            $REVIEWERS_NEEDED => $DEFAULT_REVIEWERS_NEEDED,
                            $BLOCKING_ENABLED => $DEFAULT_BLOCKING_ENABLED,
                            $BLOCKING_TIMEOUT => $DEFAULT_BLOCKING_TIMEOUT );

        my $config = \%config_hash;

        # Write defaults at least, if no config present
        if (! -e $config_file) {
            write_config($config);
            return $config;
        }
        
        open(my $CONFIG, "<$config->{$CONFIG_FILE}") or die "Could not read config: $config->{$CONFIG_FILE}";
        
        while(my $line = <$CONFIG>) {
            chomp($line);
            parse_config_line($config, $line);
        }

        close($CONFIG);
        return $config;
    }

    sub parse_config_line($) {
        my ($self, $line) = @_;
        
        if($line =~ m/^$GITHUB_TOKEN\s*:\s*(.+)\s*/) {
            if($line =~ m/^$GITHUB_TOKEN\s*:\s*([0-9a-fA-F]+)\s*/) {
                $self->{$GITHUB_TOKEN} = $1;
            } else {
                log_error "Bad configuration line, non-hex token: $line\n";
            }
        } elsif ($line =~ m/^$REVIEWERS_NEEDED\s*:\s*(.+)\s*/) {
            if(Scalar::Util::looks_like_number($1)) {           
                $self->{$REVIEWERS_NEEDED} = $1;
            } else {
                log_error "Bad configuration line, non-numeric: $line\n";
            }
        } elsif ($line =~ m/^$BLOCKING_ENABLED\s*:\s*(\d+)\s*/) {
            if(Scalar::Util::looks_like_number($1)) {           
                $self->{$BLOCKING_ENABLED} = $1;
            } else {
                log_error "Bad configuration line, non-numeric: $line\n";
            }
        } elsif ($line =~ m/^$BLOCKING_TIMEOUT\s*:\s*(\d+)\s*/) {
            if(Scalar::Util::looks_like_number($1)) {           
                $self->{$BLOCKING_TIMEOUT} = $1;
            } else {
                log_error "Bad configuration line, non-numeric: $line\n";
            }
        } else {
            log_error "Bad configuration line: $line\n";
        }
    }
    
    1;
}
