#!/usr/bin/perl -Ilib
use JSON qw( decode_json encode_json );

{
    package CodeKaiser;

    use HTTP::Server::Simple::CGI;
    use base qw(HTTP::Server::Simple::CGI);

    use CodeKaiser::GitHubApi;
    use CodeKaiser::DataManager;

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

    # Open logfile, and make it "hot", so that flushes happen frequently
    open(my $LOG, ">", "logfile") or die "Couldn't open logfile";
    { my $ofh = select $LOG;
      $| = 1;
      select $ofh;
    }
    
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
        print $LOG "New Event: $event\n";

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

            print $LOG "Bad request";
        }

        log_event($payload);
    }

    # Given a PR event, determine appropriate
    # course of action, based on the "action" attribute.
    # May post a status of the PR, if appropriate.
    sub github_pr_handler($) {
        my ($payload_json) = @_;

        my $coder = JSON->new->utf8->pretty->allow_nonref;
        my $payload = $coder->decode($payload_json);

        my $action = $$payload{'action'};
        print $LOG "Action: $action\n";

        if($action eq $PR_CLOSED) {
            # If PR was closed and merged, then
            # get and store the diff, so that further
            # processing can be done on the diff
            print $LOG "Payload merged: $$payload{'pull_request'}{'merged'}\n";
            if($$payload{'pull_request'}{'merged'}) {
                # Get and store PR's diff
                my ($owner, $repo_name) = split /\//, $$payload{'repository'}{'full_name'}, 2;
                my $pr_number = $$payload{'number'};
                if($owner && $repo_name && $pr_number) {
                    # TODO lookup OAuth token for owner/repo
                    my $token = '236ceea5c4582dbdd71400ad2166e298a9b7c822';
                    my $api = CodeKaiser::GitHubApi->new(token      => $token,
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

                    open(my $OUT, '>',CodeKaiser::DataManager->get_diff_path($owner, $repo_name, $pr_number))
                            or die "Couldn't open output for diff file: $!";
                    print $OUT $diff_body;
                    close $OUT;

                    # TODO kick off processing on diff
                } else {
                    my $sha = $$payload{'sha'};
                    print $LOG "Bad owner or repo name from $$payload{'name'}\n";
                    return 0;
                }
            } else {
                print $LOG "PR was not merged\n";
            }
        } else {
            # Otherwise, determine if the PR should
            # be allowed to be merged, and post status
            # TODO
            printf "TODO determine if allow merge, and post status"
        }

        return 1;
    }

    # Given JSON string for event, log it out
    sub log_event($) {
        my ($payload_json) = @_;

        my $coder = JSON->new->utf8->pretty->allow_nonref;
        my $payload = $coder->decode($payload_json);

        print $LOG "Got Event: ";
        print $LOG $coder->encode($payload), "\n\n";
    }
} 


# start the server on port 4567
CodeKaiser->new(4567)->run();

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

