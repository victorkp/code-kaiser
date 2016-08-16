#!/bin/perl
{
    package CodeKaiser::DataManager;
    use CodeKaiser::PullRulesConfig;
    use strict;
    use warnings;
     
    use Exporter;
    use Scalar::Util;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(get_diff_path get_config);

    my $DATA_DIR = './data/';

    ## Get file path for a diff file
    # Arguments: repo_owner, repo_name, diff_number
    sub get_diff_path($$$) {
        my ($repo_owner, $repo_name, $diff_number) = @_;

        Scalar::Util::looks_like_number($1) or die "Diff number is non numeric: $diff_number\n$!";

        system "mkdir -p $DATA_DIR/$repo_owner/$repo_name";
        return "$DATA_DIR/$repo_owner/$repo_name/diffs/$diff_number.diff";
    }

    ## Get a PullRulesConfig instance for the given repository 
    # Arguments: repo_owner, repo_name
    sub get_pull_config($$) {
        my ($repo_owner, $repo_name) = @_;

        system "mkdir -p $DATA_DIR/$repo_owner/$repo_name";
        return CodeKaiser::PullRulesConfig->new(config_file => "$DATA_DIR/$repo_owner/$repo_name/pr-config");
    }
    
    1;
}
