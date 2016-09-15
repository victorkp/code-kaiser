#!/usr/bin/perl
{ 
    package CodeKaiser::PRProcessor;

    use File::Slurp;
    use Text::Diff::Parser;
    use Storable;
    use strict;
    use warnings;

    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);
    use CodeKaiser::PRStatus;

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
    # Arguments: repo_config, comments_json, pr_status
    # Return: 1 if compliant, a string message if non-compliant, -1 if error
    #         pr_status->recheck_time is set as appropriate
    sub process_comments {
        my ($self, $repo_config, $comments_json, $pr_status) = @_;

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
                $pr_status->recheck_time($CodeKaiser::PRStatus::RECHECK_ERROR_TIME);
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
            # Keep track of the shortest comment to time-out,
            # so that we can re-run processing at that time
            my $recheck_time = 0;

            # If blocking expiry is enabled...
            if($repo_config->blocking_timeout() > -1) {
                # ... then remove blocks older than blocking_timeout hours ago
                my $timeout = $repo_config->blocking_timeout() * 3600; # hours to seconds 
                
                my $time_now = DateTime->now()->epoch();
                foreach my $user (keys %users_blocking) {
                    my $time_comment = DateTime::Format::ISO8601->parse_datetime($users_blocking{$user})
                                                                ->epoch();

                    # time_now - time_comment yields a difference in seconds
                    if(($time_now - $time_comment) > $timeout) {
                        log_debug "Removing timed-out comment";
                        delete($users_blocking{$user});
                    } else {
                        # This block will expire at expiration_time, so better
                        # reprocess all comments when the block expires
                        my $expiration_time = $time_comment + $timeout; 
                        if($recheck_time == 0 || $expiration_time < $recheck_time) {
                            $recheck_time = $expiration_time
                        }
                    }
                }
            }

            # A comment expires at $recheck_time, or 0 indicates no rechecks needed
            $pr_status->recheck_time($recheck_time);

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

        # PR is allowed to merge, no need to recheck
        $pr_status->recheck_time(0);
        return 1;
    }

    ## Given a PR, use its configuration rules to 
    ## determine if the PR should be accepted. Statuses
    ## are posted to GitHub, and a pr_status file is
    ## saved in output_directory/pr_number
    # Arguments: repo_owner, repo_name, pr_number
    # Return: boolean if merge is allowed
    sub process_pr {
        my ($self, $repo_owner, $repo_name, $pr_number) = @_;

        if(!$repo_owner || !$repo_name || !$pr_number) {
            log_error "An argument was null: $repo_owner, $repo_name, $pr_number";
            return 0;
        }

        my $repo_config = CodeKaiser::DataManager->get_repo_config($repo_owner, $repo_name);

        if(!$repo_config || !$repo_config->github_token()) {
            log_error "Bad repo config or token";
            return 0;
        }

        my $output_path = CodeKaiser::DataManager->get_pr_status_path($repo_owner, $repo_name, $pr_number);
        my $status = CodeKaiser::PRStatus->new(status_file => $output_path);
        if(!$status) {
            log_error "Could not open PRStatus";
            return 0;
        }

        my $api = CodeKaiser::GitHubApi->new(token      => $repo_config->github_token(),
                                             repo_owner => $repo_owner,
                                             repo_name  => $repo_name); 


        log_debug "Getting PR for $repo_owner/$repo_name, pull $pr_number";
        my $pr_response = $api->get_pull($pr_number);
        if(!$pr_response->is_success) {
            # TODO surface error through some other means
            log_error "Could not get PR details for $repo_owner/$repo_name, pull request $pr_number";
            log_error $pr_response->status_line();
            log_error $pr_response->decoded_content();

            $status->merge_status($CodeKaiser::PRStatus::MERGE_ERROR);
            $status->status_message("Could not get PR details for $repo_owner/$repo_name, pull request $pr_number");
            $status->recheck_time(0);
            $status->write_status();
            return 0;
        }

        # Get all kinds of basic metadata about the PR
        my $pr_details = decode_json($pr_response->decoded_content());
        my $pr_sha      = $pr_details->{'head'}{'sha'};
        my $pr_name     = $pr_details->{'title'};
        my $pr_creator  = $pr_details->{'user'}{'login'};
        my $branch_base = $pr_details->{'base'}{'ref'};
        my $branch_head = $pr_details->{'head'}{'ref'};
        my $pr_closed   = $pr_details->{'state'}  eq 'closed';
        my $pr_merged   = $pr_details->{'merged'} eq 'true';  # API returns true or false 

        # Set basic PR name / status metadata
        $status->pr_name($pr_name);
        $status->pr_sha($pr_sha);
        $status->pr_creator($pr_creator);
        $status->branch_base($branch_base);
        $status->branch_head($branch_head);
        if($pr_merged) {
            $status->pr_status($CodeKaiser::PRStatus::PR_MERGED);
        } elsif ($pr_closed) {
            $status->pr_status($CodeKaiser::PRStatus::PR_CLOSED);
        } else {
            $status->pr_status($CodeKaiser::PRStatus::PR_OPEN);
        }
        $status->write_status();

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

            $status->merge_status($CodeKaiser::PRStatus::MERGE_ERROR);
            $status->status_message("Could not post PENDING status" .  $status_response->status_line());
            $status->recheck_time(0);
            $status->write_status();
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

            $status->merge_status($CodeKaiser::PRStatus::MERGE_ERROR);
            $status->status_message("Could get PR comments: " . $comments_response->status_line());
            $status->recheck_time(0);
            $status->write_status();
            return 0;
        }
        
        # Process comments and run rules
        my $compliance = $self->process_comments($repo_config,
                                                 $comments_response->decoded_content(),
                                                 $status);

        # Post success or failure, with message,
        # as well as store a corresponding pr_status file
        if($compliance eq 1) {
            # PR can be merged
            log_debug "PR merge posting SUCCESS";
            $status_response = $api->post_status($pr_sha,
                                                 $CodeKaiser::GitHubApi::STATUS_SUCCESS, 
                                                 $SUCCESS_MESSAGE);

            $status->merge_status($CodeKaiser::PRStatus::MERGE_OK);
            $status->status_message("");
        } elsif($compliance eq -1) {
            # An error occurred in process_comments
            log_debug "PR merge posting ERROR";
            $status_response = $api->post_status($pr_sha,
                                                 $CodeKaiser::GitHubApi::STATUS_ERROR, 
                                                 $ERROR_MESSAGE);

            $status->merge_status($CodeKaiser::PRStatus::MERGE_ERROR);
            $status->status_message("");
        } else {
            # Non-compliant failure, where $compliance is reason why (e.g. user blocked)
            log_debug "PR merge posting FAILURE: $compliance";
            $status_response = $api->post_status($pr_sha,
                                                 $CodeKaiser::GitHubApi::STATUS_FAILURE, 
                                                 $compliance);

            $status->merge_status($CodeKaiser::PRStatus::MERGE_BLOCKED);
            $status->status_message($compliance);
        }

        # Persist updated status to file
        $status->write_status();

        # Return boolean if merge allowed
        return $compliance eq 1;
    }

    1;
}
