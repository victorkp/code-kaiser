#!/usr/bin/perl
{ 
    package CodeKaiser::DiffProcessor;

    use File::Slurp;
    use Text::Diff::Parser;
    use JSON;
    use strict;
    use warnings;

    use CodeKaiser::Logger qw(log_debug log_error log_verbose log_line);

    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(process_diffs);

    my $JSON = JSON->new->pretty;

    ## Process diff files in a directory, using
    ## a specified file as a temp-save file, 
    ## and returning a processed structure of
    ## statistics collected for each file modified
    # Arguments: diff_directory, save_file
    # Return: ref of hash mapping files to statistics
    sub process_diffs($$) {
        # Iterate through diff files, keeping track of
        # file change statistics for each file here
        my %files;

        # Start processing file "$start_file.diff"
        my $last_diff_processed = -1;

        my ($self, $diff_dir, $save_file) = @_;

        # Load previously processed statistics, if save file exists
        if(-f $save_file) {
            open (my $SAVE, "<$save_file") or die "Could not open diff processor's save file: $!";
            my $file_text = read_file($SAVE);
            close($SAVE);

            my $last_save_hash = $JSON->decode($file_text);

            # If save file was bad, then remove it, otherwise
            # start from that save file's checkpoint
            if(!$last_save_hash) {
                unlink $save_file;
            } else {
                $last_diff_processed = $$last_save_hash{last_diff_processed};
                %files               = %{$$last_save_hash{files}};
            }
        }

        scalar(@_) == 3 or die "Required parameters: <diff-directory> <save-file>\n";

        opendir(DIFF_DIR, $diff_dir) or die "Could not open diff directory: $diff_dir\n";
        my @dir_files = readdir(DIFF_DIR);
        closedir(DIFF_DIR);

        # Sort pull request diff files to be in order
        my @files;
        foreach my $f (@dir_files) {
            if($f =~ m/(\d+)\.diff/) {
                push @files, $1;
            }
        }
        my @diff_files = sort { $a <=> $b } @files;
        my $LAST_DIFF_NUMBER = $diff_files[-1]; # Last diff number

        foreach my $diff_file (@diff_files) {
            # Don't reprocess already seen files
            if($diff_file <= $last_diff_processed) {
                next;
            }
            $last_diff_processed = $diff_file;

            print "Processing file $diff_file.diff\n";

            # Strip one directory, because GitHub uses 'a/' and 'b/'
            # base branch and branch to merge
            my $parser = Text::Diff::Parser->new("$diff_dir/$diff_file.diff");
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
                $files{$f}{changes_score} += ($changes**2) * ($diff_file / $LAST_DIFF_NUMBER)**2;
            }
        }

        # Calculate a hotspot score per file
        for my $f (keys %files) {
            $files{$f}{hotspot_score} = $files{$f}{changes_score} * $files{$f}{pr_count}**2;
        }

        # Store everything to save file, in JSON format
        open (my $SAVE, ">$save_file") or die "Could not open diff processor's save file: $!";
        print $SAVE $JSON->encode({ last_diff_processed => $last_diff_processed,
                                    files               => \%files } );
        close($SAVE);

        return \%files;
    }

    1;
}
