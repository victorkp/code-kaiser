#!/bin/perl
{
    package CodeKaiser::PRStatus;
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
                      merge_status
                      status_message
                      recheck_time
                      write_status
                     );

    # Status file path key
    my  $STATUS_FILE              = 'status_file';

    # Pull Request's name on GitHub
    my  $PR_NAME           = 'pr_name';

    # PR's status, whether it is open, closed (not merged),
    # or merged (and closed)
    my  $PR_STATUS         = 'pr_status';
    our $PR_UNKNOWN        = 'unknown';
    our $PR_OPEN           = 'open';
    our $PR_CLOSED         = 'closed';
    our $PR_MERGED         = 'merged';

    # If the merge is allowed based on rules checked
    # by PRProcessor
    my  $MERGE_STATUS      = 'merge_status';
    our $MERGE_UNKNOWN     = 'unknown';
    our $MERGE_BLOCKED     = 'blocked';
    our $MERGE_OK          = 'allowed';
    our $MERGE_ERROR       = 'error';

    # Status message that may be null,
    # set by PRProcessor (E.g. "victorkp blocked merge")
    my $STATUS_MESSAGE     = 'status_message';

    # If a PR merge was blocked, but blocking
    # timeouts are enabled, we should recheck the PR
    # status at this time (when the blocking comment expires)
    my $RECHECK_TIME       = 'recheck_time';

    ## Load a pull rules configuration file,
    ## creating a configuration file with defaults
    ## if none exists at specified path
    # Expects { pr_status_file => <filename> }
    sub new($) {
        my ($class, %args) = @_;

        my $status_file = $args{status_file};
        if(! $status_file) {
            return undef;
        } else {
            my $status = load_status($status_file);
            return bless $status, $class;
        }
    }

    # Assert that status file path is defined
    sub assert_values {
        my ($self) = @_;
        if(!$self->{$STATUS_FILE}) {
            die "No PR status file specified: $!";
        }
    }

    ## Get or set the PR's name 
    # Argument: pr_name (optional)
    # Return:   pr_name
    sub pr_name {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{$PR_NAME} = $value;
            write_status($self);
        }
        return $self->{$PR_NAME};
    }

    ## Get or set the PR's status (open, closed, merged)
    # Argument: one of $PRStatus::PR_OPEN, $PRStatus::PR_CLOSED, $PRStatus::PR_MERGED
    # Return:   one of $PRStatus::PR_OPEN, $PRStatus::PR_CLOSED, $PRStatus::PR_MERGED, or 
    #           $PRStatus::PR_UNKNOWN
    sub pr_status {
        my ($self, $value) = @_;
        if (scalar(@_) == 2) {
            if($value eq $PR_OPEN  || $value eq $PR_CLOSED || $value eq $PR_MERGED) {           
                $self->{$PR_STATUS} = $value;
                write_status($self);
            } else {
                die "Bad argument, expecting one of $PR_OPEN, $PR_CLOSED, or $PR_MERGED";
            }
        }
        return $self->{$MERGE_STATUS};
    }

    ## Get or set if merge is allowed
    # Argument: one of $PRStatus::MERGE_OK, $PRStatus::MERGE_BLOCKED, $PRStatus::MERGE_ERROR
    # Return:   one of $PRStatus::MERGE_OK, $PRStatus::MERGE_BLOCKED, $PRStatus::MERGE_ERROR, or 
    #           $PRStatus::MERGE_UNKNOWN
    sub merge_status {
        my ($self, $value) = @_;
        if (scalar(@_) == 2) {
            if($value eq $MERGE_BLOCKED || $value eq $MERGE_OK || $value eq $MERGE_ERROR) {           
                $self->{$MERGE_STATUS} = $value;
                write_status($self);
            } else {
                die "Bad argument, expecting one of $MERGE_BLOCKED, $MERGE_OK, or $MERGE_ERROR";
            }
        }
        return $self->{$MERGE_STATUS};
    }


    ## Get or set the status message associated with this status
    # Argument: status_message (optional)
    # Return:   status_message
    sub status_message {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{$STATUS_MESSAGE} = $value;
            write_status($self);
        }
        return $self->{$STATUS_MESSAGE};
    }

    ## Get or set the time to recheck if PR can be merged
    # Argument: recheck_time (optional)
    # Return:   recheck_time 
    sub recheck_time {
        my ($self, $value) = @_;
        if (@_ == 2) {
            if(Scalar::Util::looks_like_number($value)) {
                $self->{$RECHECK_TIME} = $value;
                write_status($self);
            } else {
                die 'Bad argument, expecting numeric';
            }
        }
        return $self->{$RECHECK_TIME};
    }

    # Write the configuration
    # to the config file - for use
    # when updating or saving configs
    sub write_status {
        my ($status) = @_;
        assert_values $status;

        my $dirname = dirname($status->{$STATUS_FILE});
        system "mkdir -p $dirname" if $dirname;

        open(my $STATUS, ">$status->{$STATUS_FILE}")
                or die "Could not write status: $status->{$STATUS_FILE}";

        print $STATUS "$PR_NAME          : \'", $status->{$PR_NAME},  "\'\n";
        print $STATUS "$PR_STATUS        : \'", $status->{$PR_STATUS},  "\'\n";
        print $STATUS "$MERGE_STATUS     : \'", $status->{$MERGE_STATUS},  "\'\n";
        print $STATUS "$STATUS_MESSAGE   : \'", $status->{$STATUS_MESSAGE}, "\'\n";
        print $STATUS "$RECHECK_TIME     : ",   $status->{$RECHECK_TIME},   "\n";
        close($STATUS);
    }

    # Load a configuration file into a hash,
    # creating a new configuration with defaults,
    # if needed
    sub load_status {
        my ($status_file) = @_;

        # Start with default values
        my %config_hash = ( $PR_NAME          => '',
                            $PR_STATUS        => $PR_UNKNOWN,
                            $STATUS_FILE      => $status_file,
                            $MERGE_STATUS     => $MERGE_UNKNOWN,
                            $STATUS_MESSAGE   => '',
                            $RECHECK_TIME     => 0);

        my $config = \%config_hash;

        # Write defaults at least, if no config present
        if (! -e $status_file) {
            log_debug "Writing default status file";
            write_status($config);
            return $config;
        }
        
        open(my $CONFIG, "<$config->{$STATUS_FILE}")
            or die "Could not read config: $config->{$STATUS_FILE}";
        
        while(my $line = <$CONFIG>) {
            chomp($line);
            parse_config_line($config, $line);
        }

        close($CONFIG);
        return $config;
    }

    sub parse_config_line($) {
        my ($self, $line) = @_;
        
        if ($line =~ m/^$PR_NAME\s*:\s*'(.*)'\s*/) {
            $self->{$PR_NAME} = $1;
        } elsif ($line =~ m/^$PR_STATUS\s*:\s*'(.*)'\s*/) {
            $self->{$PR_STATUS} = $1;
        } elsif($line =~ m/^$MERGE_STATUS\s*:\s*'(.+)'\s*/) {
            $self->{$MERGE_STATUS} = $1;
        } elsif ($line =~ m/^$STATUS_MESSAGE\s*:\s*'(.*)'\s*/) {
            $self->{$STATUS_MESSAGE} = $1;
        } elsif ($line =~ m/^$RECHECK_TIME\s*:\s*(\d+)\s*/) {
            if(Scalar::Util::looks_like_number($1)) {           
                $self->{$RECHECK_TIME} = $1;
            } else {
                log_error "Bad configuration line, non-numeric: $line\n";
            }
        } else {
            log_error "Bad configuration line: $line\n";
        }
    }
    
    1;
}
