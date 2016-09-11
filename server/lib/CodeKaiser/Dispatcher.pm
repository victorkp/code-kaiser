#!/bin/perl
{
    package CodeKaiser::Dispatcher;
    use strict;
    use warnings;
     
    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    use Async;
    use Data::Dumper;

    use CodeKaiser::DataManager;
    use CodeKaiser::DiffProcessor;
    use CodeKaiser::PRProcessor;
    use CodeKaiser::ChartGenerator;
    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(log_processes dispatch_diff_process dispatch_pr_check_process);

    ## Check @processes every POLL_TIME seconds
    my $POLL_TIME = 5;

    my $process_id = 0;
    my @processes;
    my @processes_descriptions;

    # Sets up the re-ocurring timer that checks
    # async process progress
    # local $SIG{ALRM} = sub { log_processes() };
    # alarm $POLL_TIME;
    
    ## Push a dispatched process on to @processes,
    ## along with a process description for @processes_descriptions
    sub push_process($$) {
        my ($self, $process, $description) = @_;
        
        push @processes, $process;
        push @processes_descriptions, "$process_id: $description";
        $process_id++;
    }

    ## Checks if any processes have exited,
    ## logging to a log file in /var/log
    sub log_processes() {
        log_line;
        log_debug "DISPATCHER_CURRENT_PROCESSES:";
        my $error;
        for(my $i = scalar(@processes) - 1; $i != -1; $i--) {
            if($processes[$i]->ready) {
                if ($error = $processes[$i]->error) {
                    log_debug "           ERROR    $processes_descriptions[$i]: $error";
                } else {
                    log_debug "           SUCCESS  $processes_descriptions[$i]: ", $processes[$i]->result();
                }

                splice @processes, $i, 1;
                splice @processes_descriptions, $i, 1;
            } else {
                log_debug "           WORKING  $processes_descriptions[$i]";
            }
        }
    }

    ## Start processing possibly new diffs
    # Arugments: repo_owner, repo_name
    sub dispatch_diff_process($$) {
        my ($self, $repo_owner, $repo_name, $pr_number) = @_;

        my $proc = Async->new(sub {
                # Get and store PR's diff
                my $repo_config = CodeKaiser::DataManager->get_repo_config($repo_owner, $repo_name);
                my $token = $repo_config->github_token();

                if(! $repo_config || ! $repo_config->github_token()) {
                    log_error "Bad configuration, or no access token for $repo_owner/$repo_name";
                    return 0;
                }

                my $api = CodeKaiser::GitHubApi->new(token      => $repo_config->github_token,
                                                     repo_owner => $repo_owner,
                                                     repo_name  => $repo_name); 

                # Get diff from PR
                my $diff_response = $api->get_diff($pr_number);
                my $diff_body;
                if($diff_response->is_success) {
                    $diff_body = $diff_response->decoded_content;
                } else {
                    return 0;
                }

                open(my $OUT, '>', CodeKaiser::DataManager->get_diff_path($repo_owner, $repo_name, $pr_number))
                        or die "Couldn't open output for diff file: $!";
                print $OUT $diff_body;
                close $OUT;
               
                my $files = CodeKaiser::DiffProcessor->process_diffs(
                                                    CodeKaiser::DataManager->get_diff_directory($repo_owner, $repo_name),
                                                    CodeKaiser::DataManager->get_diff_save_file_path($repo_owner, $repo_name));

                CodeKaiser::ChartGenerator->chart_hotspot_from_struct(
                                        $files, CodeKaiser::DataManager->get_processing_output_path($repo_owner, $repo_name));
            }) or die "Can't Async execute";

        $self->push_process($proc, "diff_process: $repo_owner/$repo_name");

        log_processes
    }

    ## Using a repo's configuration, run a check of all
    ## the rules for the specified PR, submitting a status
    ## update to GitHub once completed
    # Arguments: repo_owner, repo_name, pr_number
    sub dispatch_pr_check_process($$$$) {
        my ($self, $repo_owner, $repo_name, $pr_number) = @_;

        if(!$repo_owner || !$repo_name || !$pr_number) {
            log_error "An argument was null";
            return 0;
        }

        my $proc = Async->new(sub {
                                    CodeKaiser::PRProcessor->process_pr($repo_owner, $repo_name, $pr_number);
                                  }) or die "Can't Async execute";

        $self->push_process($proc, "pr_check_process: $repo_owner/$repo_name pr-$pr_number)");

        log_processes
    }
    
    1;
}
