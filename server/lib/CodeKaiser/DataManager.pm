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
    @EXPORT_OK   = qw(get_diff_path get_repo_config get_diff_save_file_path);

    my $DATA_DIR = './data/';

    ## Get directory path for a repo's diff files
    # Arguments: repo_owner, repo_name
    sub get_diff_directory($$) {
        my $self;
        my $repo_owner;
        my $repo_name;
        if(scalar(@_) == 3) {
            ($self, $repo_owner, $repo_name) = @_;
        } elsif(scalar(@_) == 2) {
            ($repo_owner, $repo_name) = @_;
        } else {
            die "Need two or three params";
        }

        my $diff_dir = "$DATA_DIR/$repo_owner/$repo_name/diffs";
        system "mkdir -p $diff_dir";
        return $diff_dir;;
    }

    ## Get file path for a diff file
    # Arguments: repo_owner, repo_name, diff_number
    sub get_diff_path($$$) {
        my $self;
        my $repo_owner;
        my $repo_name;
        my $diff_number;
        if(scalar(@_) == 4) {
            ($self, $repo_owner, $repo_name, $diff_number) = @_;
        } elsif(scalar(@_) == 2) {
            ($repo_owner, $repo_name, $diff_number) = @_;
        } else {
            die "Need two or three params";
        }

        Scalar::Util::looks_like_number($1) or die "Diff number is non numeric: $diff_number\n$!";

        my $diff_dir = get_diff_directory($repo_owner, $repo_name);
        return "$diff_dir/$diff_number.diff";
    }

    ## Get save file path for diff processor
    # Arguments: repo_owner, repo_name
    sub get_diff_save_file_path($$) {
        my $self;
        my $repo_owner;
        my $repo_name;
        if(scalar(@_) == 3) {
            ($self, $repo_owner, $repo_name) = @_;
        } elsif(scalar(@_) == 2) {
            ($repo_owner, $repo_name) = @_;
        } else {
            die "Need two or three params";
        }

        my $diff_dir = get_diff_directory($repo_owner, $repo_name);
        return "$diff_dir/diff-processor.save";
    }

    ## Get a RepoConfig instance for the given repository 
    # Arguments: repo_owner, repo_name
    sub get_repo_config($$) {
        my $self;
        my $repo_owner;
        my $repo_name;
        if(scalar(@_) == 3) {
            ($self, $repo_owner, $repo_name) = @_;
        } elsif(scalar(@_) == 2) {
            ($repo_owner, $repo_name) = @_;
        } else {
            die "Need two or three params";
        }

        system "mkdir -p $DATA_DIR/$repo_owner/$repo_name";
        return CodeKaiser::RepoConfig->new(config_file => "$DATA_DIR/$repo_owner/$repo_name/repo.config");
    }
    
    1;
}
