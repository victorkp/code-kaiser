#!/bin/perl
use strict;
use warnings;
use Text::Diff::Parser;
use Data::Dumper qw(Dumper);

# Iterate through diff files in ../pulls/, 
# keeping track of file changes. Try to identify
# files or areas that have been modified often
my %files;

opendir(PULLS, "../pulls");
my @dir_files = readdir(PULLS);
closedir(PULLS);

# Sort pull request diff files to be in order
my @files;
foreach my $f (@dir_files) {
    if($f =~ m/(\d+)\.diff/) {
        push @files, $1;
    }
}
@files = sort { $a <=> $b } @files;

my $PR_LAST = @files[-1];

foreach my $diff_file (@files) {
    print "Processing file $diff_file.diff\n";

    # Strip one directory, because GitHub uses 'a/' and 'b/'
    # base branch and branch to merge
    my $parser = Text::Diff::Parser->new("../pulls/$diff_file.diff");
    $parser->simplify();

    # Used to keep track of changes_score
    my %files_changed_by_diff;

    # Find results
    foreach my $change ( $parser->changes ) {
        # print "\nFile1: ", $change->filename1;
        # print "\nLine1: ", $change->line1;
        # print "\nFile2: ", $change->filename2;
        # print "\nLine2: ", $change->line2;
        # print "\nType: ", $change->type;
        
        my $size = $change->size;
        my $file_changed;

        # Handle cases where file was created or deleted
        if($change->filename1 eq "/dev/null") {
            # A new file was created; filename1 = /dev/null
            # and filename2 = the new file
            $file_changed = substr($change->filename2, 2);
            $files{$file_changed}{created} = $diff_file;
        } else {
            $file_changed = substr($change->filename1, 2);

            if($change->filename2 eq "/dev/null") {
                $files{$file_changed}{deleted} = $diff_file;
            }
        }

        # Create hash value for filename if needed
        if(! exists $files{$file_changed}) {
            $files{$file_changed}{changes} = 0;
            $files{$file_changed}{changes_score} = 0;
            $files{$file_changed}{pr_count} = 0;
            $files{$file_changed}{adds} = 0;
            $files{$file_changed}{removes} = 0;
        }

        # Update our statistics for this filename
        $files{$file_changed}{changes} += $size;
        if($change->type eq "ADD") {
            $files{$file_changed}{adds}++;
        } elsif($change->type eq "REMOVE") {
            $files{$file_changed}{removes}++;
        } else { # Change is a "modify" 
            $files{$file_changed}{adds}++;
            $files{$file_changed}{removes}++;
        }
        
        # If this filename has no recorded diffs, or if the last
        # diff is not the same as this one, then add this diff to the
        # list of pull requests that modified this file. This avoids
        # recording duplicate diff files, when a diff has multiple 
        # entries for the same file (e.g. multiple modifications
        # in different places)
        if(! exists $files{$file_changed}{pull_requests} ||
                ${$files{$file_changed}{pull_requests}}[-1] ne $diff_file) {
            push(@{$files{$file_changed}{pull_requests}}, $diff_file);
            $files{$file_changed}{pr_count} += 1;
        }

        if(! exists $files_changed_by_diff{$file_changed}) {
            $files_changed_by_diff{$file_changed}{changes} = $size;
        } else {
            $files_changed_by_diff{$file_changed}{changes} += $size;
        }
    }

    # Now that all changes have been made by this diff, 
    # add to the changes_score for this file
    foreach my $f (keys %files_changed_by_diff) {
        # Changes_Score for this PR is changes^2 * recency
        my $changes = $files_changed_by_diff{$f}{changes};
        $files{$f}{changes_score} += ($changes**2) * ($diff_file / $PR_LAST)**2;
    }
}

# Calculate a hotspot score per file
for my $f (keys %files) {
    my $pr_sum = 0;
    for my $pr ($files{$f}{pull_requests}) {
        $pr_sum += ($pr * $pr) / ($PR_LAST / $PR_LAST);
    }
    $files{$f}{hotspot_score} = $files{$f}{changes_score} * $files{$f}{pr_count};
}

my @sorted = sort { $files{$a}{hotspot_score} 
                    <=> $files{$b}{hotspot_score} } keys %files;
foreach my $file (@sorted) {
    print "$file \n";
    print Dumper $files{$file};
}
