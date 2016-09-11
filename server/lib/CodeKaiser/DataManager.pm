#!/bin/perl
{
    package CodeKaiser::DataManager;
    use CodeKaiser::RepoConfig;
    use strict;
    use warnings;
     
    use Exporter;
    use Scalar::Util;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(get_diff_path get_repo_config get_diff_save_file_path
                      get_processing_output_path get_pr_status_directory
                      get_pr_status_path);

    my $DATA_DIR = './data/';

    ## Get directory path for a repo's diff files
    # Arguments: repo_owner, repo_name
    sub get_diff_directory {
        if(scalar(@_) == 3) {
            shift @_;
        }
        my ($repo_owner, $repo_name) = @_;

        my $diff_dir = "$DATA_DIR/$repo_owner/$repo_name/diffs";
        system "mkdir -p $diff_dir";
        return $diff_dir;;
    }

    ## Get file path for a diff file
    # Arguments: repo_owner, repo_name, diff_number
    sub get_diff_path {
        if(scalar(@_) == 4) {
            shift @_;
        }
        my ($repo_owner, $repo_name, $diff_number) = @_;

        Scalar::Util::looks_like_number($1) or die "Diff number is non numeric: $diff_number\n$!";

        my $diff_dir = get_diff_directory($repo_owner, $repo_name);
        return "$diff_dir/$diff_number.diff";
    }

    ## Get save file path for diff processor
    # Arguments: repo_owner, repo_name
    sub get_diff_save_file_path {
        if(scalar(@_) == 3) {
            shift @_;
        }
        my ($repo_owner, $repo_name) = @_;

        my $diff_dir = get_diff_directory($repo_owner, $repo_name);
        return "$diff_dir/diff-processor.save";
    }

    ## Get directory path for diff processor output files
    # Arguments: repo_owner, repo_name
    sub get_processing_output_path {
        if(scalar(@_) == 3) {
            shift @_;
        }
        my ($repo_owner, $repo_name) = @_;

        my $out_dir = "$DATA_DIR/$repo_owner/$repo_name/output";
        system "mkdir -p $out_dir";
        return $out_dir;
    }

    ## Get directory path for PR processor output files
    # Arguments: repo_owner, repo_name
    sub get_pr_status_directory {
        if(scalar(@_) == 3) {
            shift @_;
        }
        my ($repo_owner, $repo_name) = @_;

        my $out_dir = "$DATA_DIR/$repo_owner/$repo_name/pr";
        system "mkdir -p $out_dir";
        return $out_dir;
    }

    ## Get path for a PR status output file
    # Arguments: repo_owner, repo_name, pr_number
    sub get_pr_status_path {
        if(scalar(@_) == 4) {
            shift @_;
        }
        my ($repo_owner, $repo_name, $pr_number) = @_;

        my $dir = get_pr_status_directory($repo_owner, $repo_name);

        my $out_path = "$dir/$pr_number.status";
        return $out_path;
    }

    ## Get a RepoConfig instance for the given repository 
    # Arguments: repo_owner, repo_name
    sub get_repo_config {
        if(scalar(@_) == 3) {
            shift @_;
        }
        my ($repo_owner, $repo_name) = @_;

        system "mkdir -p $DATA_DIR/$repo_owner/$repo_name";
        return CodeKaiser::RepoConfig->new(config_file =>
                                            "$DATA_DIR/$repo_owner/$repo_name/repo.config");
    }
    
    1;
}
