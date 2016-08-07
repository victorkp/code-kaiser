#!/usr/bin/perl -Ilib
use JSON qw( decode_json encode_json );

{
    package CodeKaiser;

    use HTTP::Server::Simple::CGI;
    use base qw(HTTP::Server::Simple::CGI);

    use CodeKaiser::GitHubApi;

    use Data::Dumper;
    use JSON qw( decode_json encode_json );

    use strict;
    use warnings;

    # Dispatch various URLs to respective handler subroutines 
    my %dispatch = ('/event_handler' => \&event_handler);

    # Open logfile, and make it "hot", so that flushes happen frequently
    open(my $LOG, ">", "logfile") or die "Couldn't open logfile";
    { my $ofh = select $LOG;
      $| = 1;
      select $ofh;
    }
    
    sub handle_request {
        my $self = shift;
        my $cgi  = shift;
      
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
    
    sub event_handler {
        my $cgi = shift;   # CGI.pm object
        if(!ref $cgi) {
            return;
        }

        my $payload = $cgi->param('payload');

        # "payload" parameter is obviously required,
        # as it contains all information that GitHub posts
        if(! $payload) {
            print "HTTP/1.0 400 Bad Request\r\n";
            print $cgi->header,
                  $cgi->header('application/json');
            print '{ "reason" : "No \'payload\' parameter given"}';

            print $LOG "Bad request";

            return;
        }

        print "HTTP/1.0 200 OK\r\n";
        print $cgi->header,
              $cgi->header('application/json');

        log_event($payload);
    }

    sub log_event($) {
        my $payload_json = shift;

        my $coder = JSON->new->utf8->pretty->allow_nonref;
        my $payload = $coder->decode($payload_json);

        print $LOG "Got update: ";
        print $LOG "$$payload{'id'} ($$payload{'name'})";;
    }
} 


# start the server on port 4567
#CodeKaiser->new(4567)->run();

my $api = CodeKaiser::GitHubApi->new(token      => '236ceea5c4582dbdd71400ad2166e298a9b7c822',
                                     repo_owner => 'augmate',
                                     repo_name  => 'augmate-wear');

print $api->token . "\n";
print $api->repo_owner . "\n";
print $api->repo_name . "\n\n";

### Get PR comments
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

for(my $i = 20; $i < 114; $i++) {
    my $response = $api->get_diff($i);
    print $response->request()->uri() . "\n";
    print $response->status_line() . "\n";

    if ($response->is_success) {
        open(FILE, ">$i.diff") or die;
        print FILE $response->decoded_content;
        close FILE
    }
}
