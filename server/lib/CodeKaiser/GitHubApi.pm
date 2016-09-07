#!/bin/perl
{
    package CodeKaiser::GitHubApi;
    use strict;
    use warnings;
     
    use Exporter;
    use HTTP::Request;
    use LWP::UserAgent;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(STATUS_FAILURE STATUS_PENDING STATUS_SUCCESS STATUS_ERROR
                      new assert_values token repo_owner repo_name
                      get_repo get_comments get_issue_comments get_diff get_pull);

    my $STATUS_URL     = "https://www.google.com";
    my $STATUS_CONTEXT = "Code Kaiser";

    my $CONTENT_TYPE_DIFF  = 'application/vnd.github.diff';

    our $STATUS_PENDING     = 'pending';
    our $STATUS_SUCCESS     = 'success';
    our $STATUS_FAILURE     = 'failure';
    our $STATUS_ERROR       = 'error';

    my $BASE               = "https://api.github.com";
    my $API_REPO           = "$BASE/repos/:owner/:repo";
    my $API_COMMENTS       = "$BASE/repos/:owner/:repo/comments";
    my $API_ISSUE_COMMENTS = "$BASE/repos/:owner/:repo/issues/:number/comments";
    my $API_PULL           = "$BASE/repos/:owner/:repo/pulls";
    my $API_STATUS         = "$BASE/repos/:owner/:repo/statuses";
    
    # Expects { token => $<my_token>,
    #           repo_owner => <owner>,
    #           repo_name => $<repo_name> }
    sub new($) {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }

    ## Replaces instances of ':owner' and ':repo'
    ## in a URL with values set in this GitHubApi
    # Argument: url
    # Return:   modified_url
    sub get_url($) {
        my ($self, $base) = @_;
        
        if(scalar(@_) != 2) {
            die "Usage: get_url(<url>0: $!";
        }

        $self->assert_values;

        $base =~ s/:owner/$self->{repo_owner}/;
        $base =~ s/:repo/$self->{repo_name}/;
        return $base;
    }

    ## Get or set OAuth token
    # Argument: token (optional)
    # Return:   token
    sub token {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{token} = $value;
        }
        return $self->{token};
    }

    ## Get or set repo owner 
    # Argument: repo_owner (optional)
    # Return:   repo_owner
    sub repo_owner {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{repo_owner} = $value;
        }
        return $self->{repo_owner};
    }

    ## Get or set repo name
    # Argument: repo_name (optional)
    # Return:   repo_name
    sub repo_name {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{repo_name} = $value;
        }
        return $self->{repo_name};
    }

    ## Die if API token, repo owner, or name
    ## is not defined
    sub assert_values {
        my ($self) = @_;
        if(!$self || !$self->{token}
           || !$self->{repo_owner} || !$self->{repo_name}) {
            die "Token, repo owner, and repo name must be defined: $!";
        }
    }

    ## Helper to make an API request, replacing
    ## values in the URL based on this GitHubApi
    # Argument: URL, [content-type-accepted]
    # Return:   HTTP::Response
    sub make_request {
        my ($self, $url, $content_type) = @_;
        $self->assert_values;

        if(@_ < 2) {
            die "Usage: make_request(<url>, [<Accept-Header>]) $!";
        }

        my $request = HTTP::Request->new(GET => $self->get_url($url));
        $request->header('Authorization' => "token $self->{'token'}");

        if(@_ == 3) {
            $request->header('Accept' => $content_type);
        }

        my $ua = LWP::UserAgent->new;
        my $response = $ua->request($request);

        return $response;
    }

    ## Helper to make an API post, replacing
    ## values in the URL based on this GitHubApi
    # Argument: URL, payload, [content-type]
    # Return:   HTTP::Response
    sub make_post {
        my ($self, $url, $content, $content_type) = @_;
        $self->assert_values;

        if(@_ < 3) {
            die "Usage: make_request(<url>, payload, [<Accept-Header>]) $!";
        }

        my $request = HTTP::Request->new(POST => $self->get_url($url));
        $request->header('Authorization' => "token $self->{'token'}");

        print $content, "\n";

        $request->content($content);

        if(@_ == 4) {
            $request->header('Content-Type' => $content_type);
        }

        my $ua = LWP::UserAgent->new;
        my $response = $ua->request($request);

        return $response;
    }

    ## Get repo metadata
    # Return: HTTP::Response
    sub get_repo {
        my ($self) = @_;
        $self->assert_values;
        return $self->make_request($API_REPO);
    }

    ## Get PR metadata
    # Return: HTTP::Response
    sub get_pull {
        my ($self, $pr_number) = @_;
        $self->assert_values;
        return $self->make_request("$API_PULL/$pr_number");
    }

    ## Get comments on a repo
    # Return: HTTP::Response
    sub get_comments {
        my ($self) = @_;
        $self->assert_values;
        return $self->make_request($API_COMMENTS);
    }

    ## Get comments on an issue (or pull request)
    # Argument: issue_number
    # Return:   HTTP::Response
    sub get_issue_comments {
        my ($self, $issue_number) = @_;
        $self->assert_values;

        if(@_ != 2) {
            die "Usage: get_issue_comments(<issue-or-pull-number>) $!";
        }

        my $url = $API_ISSUE_COMMENTS;
        $url =~ s/:number/$issue_number/;
        return $self->make_request($url);
    }

    ## Get diff for a pull request
    # Argument: pr_number
    # Return:   HTTP::Response
    sub get_diff {
        my ($self, $diff_number) = @_;
        $self->assert_values;

        if(@_ != 2) {
            die "Usage: get_diff(<pull_number>) $!";
        }

        return $self->make_request("$API_PULL/$diff_number", $CONTENT_TYPE_DIFF);
    }

    ## Post status for a commit
    # Argument: commit_sha, status, description
    # Return:   HTTP::Response
    sub post_status {
        my ($self, $commit_sha, $status, $description) = @_;
        $self->assert_values;

        if(@_ != 4) {
            die "Usage: post_status(<commit_sha>, <status>, <description>) $!";
        }

        my $status_json = "{ \"state\" : \"$status\", \"target_url\" : \"$STATUS_URL\","
                          . " \"description\" : \"$description\", \"context\" : \"$STATUS_CONTEXT\" }";
        return $self->make_post("$API_STATUS/$commit_sha", $status_json, 'application/json');
    }

    1;
}
