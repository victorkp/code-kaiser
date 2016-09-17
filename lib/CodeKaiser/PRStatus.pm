#!/bin/perl
{
    package CodeKaiser::PRStatus;
    use strict;
    use warnings;
     
    use File::Spec;
    use File::Basename;
    use File::Slurp;
    use Scalar::Util;
    use Data::Dumper;
    use JSON;
    use Data::Structure::Util qw( unbless );

    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);

    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(new
                      pr_name
                      pr_creator
                      pr_merger
                      pr_status
                      branch_base
                      branch_head
                      merge_status
                      status_message
                      recheck_time
                      write_status
                      TO_JSON
                     );

    my $JSON = JSON->new->allow_blessed->convert_blessed->pretty;

    # Status file path key
    my  $STATUS_FILE              = 'status_file';

    # Pull Request's name on GitHub
    my  $PR_NAME           = 'pr_name';

    # Pull Request's latest commit SHA
    my  $PR_SHA            = 'pr_sha';

    # Which user started the PR
    my  $PR_CREATOR        = 'pr_creator';

    # Which user merged the PR (if any)
    my  $PR_MERGER         = 'pr_merger';

    # To and From branches
    my  $BRANCH_BASE       = 'branch_base';
    my  $BRANCH_HEAD       = 'branch_head';

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
            return $value;
        }
        return $self->{$PR_NAME};
    }

    ## Get or set the PR head branch's latest commit's SHA
    # Argument: pr_ha (optional)
    # Return:   pr_ha
    sub pr_sha {
        my ($self, $value) = @_;
        if (@_ == 2) {
            if($value =~ /^[0-9a-fA-F]+$/) {           
                $self->{$PR_SHA} = $value;
                return $value;
            } else {
                die 'Bad argument, expecting hex string for commit SHA';
            }
        }
        return $self->{$PR_SHA};
    }

    ## Get or set the PR's creator 
    # Argument: pr_creator (optional)
    # Return:   pr_creator
    sub pr_creator {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{$PR_CREATOR} = $value;
            return $value;
        }
        return $self->{$PR_CREATOR};
    }

    ## Get or set the PR's merger
    # Argument: pr_merger (optional)
    # Return:   pr_merger
    sub pr_merger {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{$PR_MERGER} = $value;
            return $value;
        }
        return $self->{$PR_MERGER};
    }

    ## Get or set the PR's Base (destination) branch
    # Argument: branch_base (optional)
    # Return:   branch_base
    sub branch_base {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{$BRANCH_BASE} = $value;
            return $value;
        }
        return $self->{$BRANCH_BASE};
    }

    ## Get or set the PR's Head (source) branch
    # Argument: branch_head (optional)
    # Return:   branch_head
    sub branch_head {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{$BRANCH_HEAD} = $value;
            return $value;
        }
        return $self->{$BRANCH_HEAD};
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
                return $value;
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
                return $value;
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
            return $value;
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
                return $value;
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

        # Open, write, and close file
        open(my $STATUS, ">$status->{$STATUS_FILE}")
                or die "Could not write status: $status->{$STATUS_FILE}";
        print $STATUS $JSON->encode($status);
        close($STATUS);
    }

    # Load a status file into a hash,
    # using a new default status if needed
    sub load_status {
        my ($status_file) = @_;

        my $status = make_default_status($status_file);

        # Write defaults at least, if no status present
        if (! -e $status_file) {
            log_debug "Writing default status file";
            write_status($status);
            return $status;
        }
        
        open(my $STATUS, "<$status_file")
            or die "Could not read status: $status_file";
        my $file_text = read_file($STATUS);
        close($STATUS);

        my $loaded_status = $JSON->decode($file_text);

        if(!$loaded_status) {
            log_debug "Writing default status file";
            write_status($status);
            return $status;
        }
        
        # Overlay all loaded values on top of default values.
        # For cases where the stored status is missing a member,
        # this enfoces a default value for that key
        while (my ($key, $value) = each (%{$loaded_status})) {
            $status->{$key} = $value;
        }

        return $status;
    }

    ## Make default status, with mostly empty values
    # Arguments: status_file_path
    # Return: hash reference of default status
    sub make_default_status {
        my ($status_file) = @_;

        my %config_hash = ( $PR_NAME          => '',
                            $PR_CREATOR       => '',
                            $PR_MERGER        => '',
                            $PR_SHA           => '',
                            $BRANCH_BASE      => '',
                            $BRANCH_HEAD      => '',
                            $PR_STATUS        => $PR_UNKNOWN,
                            $STATUS_FILE      => $status_file,
                            $MERGE_STATUS     => $MERGE_UNKNOWN,
                            $STATUS_MESSAGE   => '',
                            $RECHECK_TIME     => 0);

        return \%config_hash;
    }

    sub TO_JSON {
        my ($status) = @_;

        # Remove underlying file store, and
        # don't have a blessing as an object
        my %copy = %{$status};
        delete($copy{$STATUS_FILE});
        unbless \%copy;

        return \%copy;
    }

    1;
}
