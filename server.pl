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

    # New issue comments have action 'created'
    my $PR_CREATED     = 'created';

    # Dispatch various URLs to respective handler subroutines 
    my %dispatch = ('/event_handler' => \&event_handler,
                    '/log_processes' => \&log_processes);

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

    # Debug handler that logs the status of dispatched processes
    sub log_processes {
        CodeKaiser::Dispatcher->log_processes();
        print "HTTP/1.0 200 OK\r\n";
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
        my ($repo_owner, $repo_name) = split /\//, $$payload{'repository'}{'full_name'}, 2;

        my $action = $$payload{'action'};
        log_debug "Action: $action";

        # Actions other than 'opened' or 'closed' may put PR Number
        # in a different hierarchy
        if(!$pr_number) {
            $pr_number = $$payload{'issue'}{'number'};
        }

        if(!$repo_owner || !$repo_name || !$pr_number) {
            log_error "Bad owner, repo name, or pr number from $$payload{'name'}";
            return 0;
        }

        if($action eq $PR_CLOSED) {
            # If PR was closed and merged, then
            # get and store the diff, so that further
            # processing can be done on the diff (e.g. hotspot detection)
            if($$payload{'pull_request'}{'merged'}) {
                log_debug "Payload was merged, retrieving new diff";
                CodeKaiser::Dispatcher->dispatch_diff_process($repo_owner, $repo_name, $pr_number);
            }
        }

        # Update the PR's status, and determine if PR is
        # allowed to be merged or not, posting status accordingly
        CodeKaiser::Dispatcher->dispatch_pr_check_process($repo_owner, $repo_name, $pr_number);

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

