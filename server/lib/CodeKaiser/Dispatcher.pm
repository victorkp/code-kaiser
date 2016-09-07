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
    @EXPORT_OK   = qw(dispatch_diff_process);

    ## Check @processes every POLL_TIME seconds
    my $POLL_TIME = 5;

    my $process_id = 0;
    my @processes;
    my @processes_descriptions;

    # Sets up the re-ocurring timer that checks
    # async process progress
    # local $SIG{ALRM} = sub { check_processes() };
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
    sub check_processes() {
        log_debug "DISPATCHER | Current Processes:";
        my $error;
        for(my $i = scalar(@processes) - 1; $i != -1; $i--) {
            if($processes[$i]->ready) {
                if ($error = $processes[$i]->error) {
                    log_debug "DISPATCHER | ERROR    $processes_descriptions[$i]: $error";
                } else {
                    log_debug "DISPATCHER | SUCCESS  $processes_descriptions[$i]: ", $processes[$i]->result();
                }

                splice @processes, $i, 1;
                splice @processes_descriptions, $i, 1;
            } else {
                log_debug "DISPATCHER | WORKING  $processes_descriptions[$i]";
            }
        }
    }

    ## Start processing possibly new diffs
    # Arugments: repo_owner, repo_name
    sub dispatch_diff_process($$) {
        my ($self, $repo_owner, $repo_name) = @_;

        my $proc = Async->new(sub { my $files = CodeKaiser::DiffProcessor->process_diffs(
                                                    CodeKaiser::DataManager->get_diff_directory($repo_owner, $repo_name),
                                                    CodeKaiser::DataManager->get_diff_save_file_path($repo_owner, $repo_name));
                                    CodeKaiser::ChartGenerator->chart_hotspot_from_struct(
                                                $files, CodeKaiser::DataManager->get_processing_output_path($repo_owner, $repo_name));
                                  }) or die "Can't Async execute";

        $self->push_process($proc, "dispatch_diff_process($repo_owner, $repo_name)");

        check_processes
    }

    ## Using a repo's configuration, run a check of all
    ## the rules for the specified PR, submitting a status
    ## update to GitHub once completed
    # Arguments: repo_owner, repo_name, pr_number
    sub dispatch_pr_check_process($$$$) {
        my ($self, $repo_owner, $repo_name, $pr_number, $pr_sha) = @_;

        my $proc = Async->new(sub {
                                    CodeKaiser::PRProcessor->process_pr($repo_owner, $repo_name, $pr_number, $pr_sha);
                                  }) or die "Can't Async execute";

        $self->push_process($proc, "dispatch_pr_check_process($repo_owner, $repo_name, $pr_number, $pr_sha)");

        check_processes
    }
    
    1;
}
