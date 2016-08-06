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
    @EXPORT_OK   = qw(new assert_values token repo_owner repo_name);

    my $BASE         = "https://api.github.com";
    my $API_REPO     = "$BASE/repos/:owner/:repo";
    my $API_COMMENTS = "$BASE/repos/:owner/:repo/comments";
    my $API_PULL     = "$BASE/repos/:owner/:repo/pull";
    
    # Expects { token => $<my_token>,
    #           repo_owner => <owner>,
    #           repo_name => $<repo_name> }
    sub new($) {
        my ($class, %args) = @_;
        return bless \%args, $class;
    }

    # Replaces instances of ':owner' and ':repo'
    # in a URL with values set in this GitHubApi
    sub get_url($) {
        my ($self, $base) = @_;
        
        if(scalar(@_) != 2) {
            die "Usage: get_url(<url>0: $!";
        }

        $self->assert_values();

        $base =~ s/:owner/$self->{repo_owner}/;
        $base =~ s/:repo/$self->{repo_name}/;
        return $base;
    }

    # Get or set GitHub API token
    sub token {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{token} = $value;
        }
        return $self->{token};
    }

    # Get or set repo owner
    sub repo_owner {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{repo_owner} = $value;
        }
        return $self->{repo_owner};
    }

    # Get or set repo name
    sub repo_name {
        my ($self, $value) = @_;
        if (@_ == 2) {
            $self->{repo_name} = $value;
        }
        return $self->{repo_name};
    }

    # Die if API token, repo owner, or name
    # is not defined
    sub assert_values {
        my ($self) = @_;
        if(!$self || !$self->{token}
           || !$self->{repo_owner} || !$self->{repo_name}) {
            die "Token, repo owner, and repo name must be defined: $!";
        }
    }

    sub make_request {
        my ($self, $url) = @_;
        $self->assert_values();

        if(@_ != 2) {
            die "Usage: make_request(<url>) $!";
        }

        my $request = HTTP::Request->new(GET => $self->get_url($url));
        $request->header('Authorization' => "token $self->{'token'}");

        my $ua = LWP::UserAgent->new;
        my $response = $ua->request($request);

        return $response;
    }

    sub get_repo {
        my ($self) = @_;
        $self->assert_values();
        return $self->make_request($API_REPO);
    }

    sub get_comments {
        my ($self) = @_;
        $self->assert_values();
        return $self->make_request($API_COMMENTS);
    }

    sub get_diff {
        my ($self, $diff_number) = @_;
        $self->assert_values();

        if(@_ != 2) {
            die "Usage: get_diff(<pull_number>) $!";
        }

        return $self->make_request("$API_PULL/$diff_number.diff");
    }

    1;
}

my $api = CodeKaiser::GitHubApi->new(token      => '236ceea5c4582dbdd71400ad2166e298a9b7c822',
                                     repo_owner => 'victorkp',
                                     repo_name  => 'dummy-test');

print $api->token . "\n";
print $api->repo_owner . "\n";
print $api->repo_name . "\n\n";

my $response = $api->get_comments;
print $response->request()->uri() . "\n";
print $response->status_line() . "\n";
if ($response->is_success) {
    print $response->decoded_content;  # or whatever
    print "\n\n"
}
