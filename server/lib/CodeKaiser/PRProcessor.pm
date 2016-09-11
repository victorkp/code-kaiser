#!/usr/bin/perl
{ 
    package CodeKaiser::PRProcessor;

    use File::Slurp;
    use Text::Diff::Parser;
    use Storable;
    use strict;
    use warnings;

    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);

    use JSON qw( decode_json encode_json );
    use DateTime;
    use DateTime::Format::ISO8601;

    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(process_pr);

    my $FAILURE_USER_BLOCKING       = "PR is blocked by %s";
    my $FAILURE_NEED_MORE_APPROVALS = "PR has %d of %d needed approvals";
    my $SUCCESS_MESSAGE             = "PR can be merged";
    my $ERROR_MESSAGE               = "Code Kaiser is having issues processing your PR";

    ## Given a repo's config file, and comments as a JSON string,
    ## determines if this repo is compliant with the rules set
    ## in the config
    # Arguments: repo_config, comments_json
    # Return: 1 if compliant, a string message if non-compliant, -1 if error
    sub process_comments($$) {
        my ($self, $repo_config, $comments_json) = @_;

        # Iterate through comments, keeping track of 
        # comments with !good, and !block, by user->time
        my %users_approving;
        my %users_blocking;

        my @comments = @{decode_json($comments_json)};

        my $body;
        my $user;
        foreach my $comment (@comments) {
            my $body = $comment->{'body'};
            my $user = $comment->{'user'}{'login'};

            # Must have valid comment body and user login
            if(!$body || !$user) {
                return -1;
            }

            if($body =~ /!block/) {
                $users_blocking{$user} = $comment->{'updated_at'};
            }

            if($body =~ /!good/) {
                $users_approving{$user} = $comment->{'updated_at'};
            }
        }

        # Check if there are users with valid blocks remaining 
        if(scalar(keys %users_blocking)) {
            # If blocking expiry is enabled...
            if($repo_config->blocking_timeout() > -1) {
                # ... then remove blocks older than blocking_timeout hours ago
                my $timeout = $repo_config->blocking_timeout() * 3600000; # hours to millis
                
                my $time_now = DateTime->now()->epoch();
                foreach my $user (keys %users_blocking) {
                    my $time_comment = DateTime::Format::ISO8601->parse_datetime($users_blocking{$user})->epoch();
                    log_debug "Time of block is $time_comment, time now is $time_now";
                    log_debug "Time difference is ", ($time_now - $time_comment);
                    log_debug "Expire time is $timeout";
                    if(($time_now - $time_comment) > $timeout) {
                        log_debug "Removing timed-out comment";
                        delete($users_blocking{$user});
                    }
                }
            }

            log_debug scalar(keys %users_blocking), " users are blocking merge";
            if(scalar(keys %users_blocking)) {
                # If there are still users blocking, then don't allow PR merge
                my $user_list;
                foreach $user (keys %users_blocking) {
                    if($user_list) {
                        $user_list = "$user_list, $user";
                    } else  {
                        $user_list = $user;
                    }
                }
                return sprintf($FAILURE_USER_BLOCKING, $user_list);
            }
        }

        # Check if there are enough approvals to continue 
        log_debug scalar(keys %users_approving), " users are approving merge";
        if(scalar(keys %users_approving) < $repo_config->reviewers_needed()) {
            return sprintf($FAILURE_NEED_MORE_APPROVALS,
                           scalar(keys %users_approving),
                           $repo_config->reviewers_needed());
        }

        return 1;
    }

    ## Given a PR, use its configuration rules to 
    ## determine if the PR should be accepted. Statuses
    ## are posted to GitHub, and a pr_status file is
    ## saved in output_directory/pr_number
    # Arguments: repo_owner, repo_name, pr_number, pr_config, output_directory
    # Return: boolean for success 
    sub process_pr($$$$) {
        my ($self, $repo_owner, $repo_name, $pr_number) = @_;

        if(!$repo_owner || !$repo_name || !$pr_number) {
            log_error "An argument was null: $repo_owner, $repo_name, $pr_number";
            return 0;
        }

        my $repo_config = CodeKaiser::DataManager->get_repo_config($repo_owner, $repo_name);
        my $output_path = CodeKaiser::DataManager->get_pr_output_path($repo_owner, $repo_name);

        if(!$repo_config || !$repo_config->github_token()) {
            log_error "Bad repo config or token";
            return 0;
        }

        if(!$output_path) {
            log_error "No output path specified";
            return 0;
        }

        my $api = CodeKaiser::GitHubApi->new(token      => $repo_config->github_token(),
                                             repo_owner => $repo_owner,
                                             repo_name  => $repo_name); 


        log_debug "Getting PR for $repo_owner/$repo_name, pull $pr_number";
        my $pr_response = $api->get_pull($pr_number);
        if(!$pr_response->is_success) {
            # TODO surface error through some other means
            log_error "Could get PR details for $repo_owner/$repo_name, pull $pr_number";
            log_error $pr_response->status_line();
            log_error $pr_response->decoded_content();
            return 0;
        }

        my $pr_details = decode_json($pr_response->decoded_content());
        my $pr_sha = $pr_details->{'head'}{'sha'};

        log_debug "Proccessing PR: number $pr_number, on repo $repo_owner/$repo_name for commit with SHA $pr_sha";

        # Start by posting pending status to GitHub
        my $status_response = $api->post_status($pr_sha,
                                                $CodeKaiser::GitHubApi::STATUS_PENDING, 
                                                "Code Kaiser is running rules");

        if(!$status_response->is_success) {
            # TODO surface error through some other means
            log_error "Could not post PENDING status";
            log_error $status_response->status_line();
            log_error $status_response->decoded_content();
            return 0;
        }

        log_verbose "Posted pending status";

        # Get comments from PR
        my $comments_response = $api->get_issue_comments($pr_number);

        if(!$comments_response->is_success) {
            # TODO surface error through some other means
            log_error "Could not get PR comments";
            log_error $status_response->status_line();
            log_error $status_response->decoded_content();
        }
        
        # Process comments, and run rules
        log_line;
        log_debug "Processing comments: " , $comments_response->decoded_content();

        # Post success or failure, with message,
        # as well as store a corresponding pr_status file
        my $compliance = $self->process_comments($repo_config, $comments_response->decoded_content());

        # Post status based on compliance:
        if($compliance eq 1) {
            # PR can be merged
            log_debug "PR merge posting SUCCESS";
            $status_response = $api->post_status($pr_sha,
                                                 $CodeKaiser::GitHubApi::STATUS_SUCCESS, 
                                                 $SUCCESS_MESSAGE);
        } elsif($compliance eq -1) {
            # An error occurred in process_comments
            log_debug "PR merge posting ERROR";
            $status_response = $api->post_status($pr_sha,
                                                 $CodeKaiser::GitHubApi::STATUS_ERROR, 
                                                 $ERROR_MESSAGE);
        } else {
            # Non-compliant failure, where $compliance is reason why (e.g. user blocked)
            log_debug "PR merge posting FAILURE: $compliance";
            $status_response = $api->post_status($pr_sha,
                                                 $CodeKaiser::GitHubApi::STATUS_FAILURE, 
                                                 $compliance);
        }

        # 1 if success, 0 for any other reason
        return $compliance eq 1;
    }

    1;
}
