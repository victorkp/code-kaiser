#!/usr/bin/perl
{ 
    package CodeKaiser::PRProcessor;

    use File::Slurp;
    use Text::Diff::Parser;
    use Storable;
    use strict;
    use warnings;

    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);

    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(process_pr);

    ## Given a PR, use its configuration rules to 
    ## determine if the PR should be accepted. Statuses
    ## are posted to GitHub, and a pr_status file is
    ## saved in output_directory/pr_number
    # Arguments: repo_owner, repo_name, pr_number, pr_config, output_directory
    # Return: boolean for success 
    sub process_pr($$$$) {
        my ($self, $repo_owner, $repo_name, $pr_number, $pr_sha) = @_;

        if(!$repo_owner || !$repo_name || !$pr_number || !$pr_sha) {
            log_error "An argument was null: $repo_owner, $repo_name, $pr_number, $pr_sha";
            return 0;
        }

        log_debug "Proccessing PR: number $pr_number, on repo $repo_owner/$repo_name for commit with SHA $pr_sha";

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

        # Start by posting pending status to GitHub
        my $status_response = $api->post_status($pr_sha,
                                                $CodeKaiser::GitHubApi::STATUS_PENDING, 
                                                "Code Kaiser is running rules");

        if(!$status_response->is_success) {
            # TODO surface error
            log_error "Could not post PENDING status";
            log_error $status_response->status_line();
            log_error $status_response->decoded_content();
            return 0;
        }

        log_verbose "Posted pending status";

        # Process comments, and run rules

        # Post success or failure, with message,
        # as well as store a corresponding pr_status file
        
        return 1;
    }

    1;
}
