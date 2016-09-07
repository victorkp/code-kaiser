#!/usr/bin/perl -Ilib
use JSON qw( decode_json encode_json );

{
    package CodeKaiser;

    use HTTP::Server::Simple::CGI;
    use base qw(HTTP::Server::Simple::CGI);

    use CodeKaiser::GitHubApi;
    use CodeKaiser::DataManager;
    use CodeKaiser::Dispatcher;
    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);

    use Async;

    use Data::Dumper;
    use JSON qw( decode_json encode_json );

    use strict;
    use warnings;

    my $PR_OPENED      = 'opened';
    my $PR_REOPENED    = 'reopened';
    my $PR_EDITED      = 'edited';
    my $PR_CLOSED      = 'closed';
    my $PR_SYNCHRONIZE = 'synchronize';
    my $PR_LABELED     = 'labeled';
    my $PR_UNLABELED   = 'unlabled';
    my $PR_ASSIGNED    = 'assigned';
    my $PR_UNASSIGNED  = 'unassigned';

    # Dispatch various URLs to respective handler subroutines 
    my %dispatch = ('/event_handler' => \&event_handler);

    my %dispatch_github = ('pull_request' => \&github_pr_handler,
                           'issue_comment' => \&github_pr_handler);

    sub handle_request {
        my ($self, $cgi) = @_;
      
        my $path = $cgi->path_info();
        my $handler = $dispatch{$path};
    
        # If there exists a handler for the path,
        if (ref($handler) eq "CODE") {
            # Return 200, and run handler
            $handler->($cgi);
        } else {
            print "HTTP/1.0 404 Not found\r\n";
            print $cgi->header,
                  $cgi->start_html('Not found'),
                  $cgi->h1('Not found'),
                  $cgi->end_html;
        }
    }
    
    # GitHub POSTs to event handler
    sub event_handler {
        my ($cgi) = @_;   # CGI.pm object
        if(!ref $cgi) {
            return;
        }

        my $event = $cgi->http('X-GitHub-Event');
        my $payload = $cgi->param('payload');
        log_verbose "New Event: $event";

        my $success = 1;

        # "payload" parameter is obviously required,
        # as it contains all information that GitHub posts
        if(! $payload || ! $event) {
            $success = 0;
        } else {
            # If this is a GitHub event that we care about,
            # then process it accordingly
            my $github_handler = $dispatch_github{$event};
            if(ref($github_handler) eq 'CODE') {
                $success = $github_handler->($payload);
            } else {
                log_verbose "No ref handler for event $event";
            }
        }

        # If processing worked as expected, then ACK,
        # else return Bad Request to GitHub
        if($success) {
            # ACK GitHub's event post
            print "HTTP/1.0 200 OK\r\n";
            print $cgi->header,
                  $cgi->header('application/json');
        } else {
            print "HTTP/1.0 400 Bad Request\r\n";
            print $cgi->header,
                  $cgi->header('application/json');
            print '{ "reason" : "No \'payload\' parameter given"}';

            log_error "Bad request";
        }

        # log_event($payload);
        log_line;
    }

    # Given a PR event, determine appropriate
    # course of action, based on the "action" attribute.
    # May post a status of the PR, if appropriate.
    sub github_pr_handler($) {
        my ($payload_json) = @_;

        my $coder = JSON->new->utf8->pretty->allow_nonref;
        my $payload = $coder->decode($payload_json);
        my $pr_number = $$payload{'number'};
        my ($owner, $repo_name) = split /\//, $$payload{'repository'}{'full_name'}, 2;

        my $action = $$payload{'action'};
        log_debug "Action: $action";

        if(!$owner || !$repo_name || !$pr_number) {
            log_error "Bad owner, repo name, or pr number from $$payload{'name'}";
            return 0;
        }

        if($action eq $PR_CLOSED) {
            # If PR was closed and merged, then
            # get and store the diff, so that further
            # processing can be done on the diff
            if($$payload{'pull_request'}{'merged'}) {
                log_debug "Payload was merged";

                # Get and store PR's diff
                my $repo_config = CodeKaiser::DataManager->get_repo_config($owner, $repo_name);
                my $token = $repo_config->github_token();

                if(! $repo_config || ! $repo_config->github_token()) {
                    log_error "Bad configuration, or no access token for $owner/$repo_name";
                    return 0;
                }

                my $api = CodeKaiser::GitHubApi->new(token      => $repo_config->github_token,
                                                     repo_owner => $owner,
                                                     repo_name  => $repo_name); 

                # Get diff from PR
                my $diff_response = $api->get_diff($pr_number);
                my $diff_body;
                if($diff_response->is_success) {
                    $diff_body = $diff_response->decoded_content;
                } else {
                    return 0;
                }

                open(my $OUT, '>', CodeKaiser::DataManager->get_diff_path($owner, $repo_name, $pr_number))
                        or die "Couldn't open output for diff file: $!";
                print $OUT $diff_body;
                close $OUT;

                CodeKaiser::Dispatcher->dispatch_diff_process($owner, $repo_name);
            } else {
                log_debug "PR was not merged";
            }
        } else {
            # Otherwise, determine if the PR should
            # be allowed to be merged, and post status
            my $pr_sha = $$payload{'pull_request'}{'head'}{'sha'};
            CodeKaiser::Dispatcher->dispatch_pr_check_process($owner, $repo_name, $pr_number, $pr_sha);
        }

        # Success
        return 1;
    }

    # Given JSON string for event, log it out
    sub log_event($) {
        my ($payload_json) = @_;

        my $coder = JSON->new->utf8->pretty->allow_nonref;
        my $payload = $coder->decode($payload_json);

        log_verbose "Got Event: ";
        log_verbose $coder->encode($payload), "\n\n";
    }
} 


# start the server on port 8080
CodeKaiser->new(8080)->run();

# my $api = CodeKaiser::GitHubApi->new(token      => '236ceea5c4582dbdd71400ad2166e298a9b7c822',
#                                      repo_owner => 'victorkp',
#                                      repo_name  => 'dummy-test');
# 
# print $api->token . "\n";
# print $api->repo_owner . "\n";
# print $api->repo_name . "\n\n";
# 
# my $response = $api->get_issue_comments(2);
# print $response->request()->uri() . "\n";
# print $response->status_line() . "\n";
# if ($response->is_success) {
#     my @payload = @{decode_json($response->decoded_content)};
# 
#     for my $comment(@payload){
#         print "Comment:\n";
#         printf "    User: %s\n", $comment->{user}{login};
#         printf "    Body: %s\n", $comment->{body};
#         printf "    Time: %s\n", $comment->{updated_at};
#         printf "    Time: %s\n", $comment->{html_url};
#     }
# }
# 
# print "\n\n";
# $response = $api->post_status("144fe97f8bc30ea81138509e7cbce2432d836d78",
#                               response->STATUS_FAILURE, 
#                               "victorkp blocked merge");
# print $response->request()->uri() . "\n";
# print $response->status_line() . "\n";
#     print $response->decoded_content;

