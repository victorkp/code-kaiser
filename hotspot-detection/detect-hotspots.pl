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
my @files = readdir(PULLS);
closedir(PULLS);

foreach my $diff_file (@files) {
    # skip non *.diff files
    next if($diff_file =~ /^\.$/);
    next if($diff_file =~ /^\.\.$/);
    next if(! ($diff_file =~ /^.*\.diff$/));

    print "Processing file $diff_file\n";

    # Strip one directory, because GitHub uses 'a/' and 'b/'
    # base branch and branch to merge
    my $parser = Text::Diff::Parser->new("../pulls/$diff_file");
    $parser->simplify();

    # Find results
    foreach my $change ( $parser->changes ) {
        # print "\nFile1: ", $change->filename1;
        # print "\nLine1: ", $change->line1;
        # print "\nFile2: ", $change->filename2;
        # print "\nLine2: ", $change->line2;
        # print "\nType: ", $change->type;
        my $size = $change->size;
        # foreach my $line ( 0..($size-1) ) {
        #     print "\nLine: ", $change->text( $line );
        # }
        # printf "\n\n";

        # Create hash value for filename if needed
        if(! exists $files{$change->filename1}) {
            $files{$change->filename1}{changes} = 0;
            $files{$change->filename1}{pr_count} = 0;
            $files{$change->filename1}{adds} = 0;
            $files{$change->filename1}{removes} = 0;
        }

        # Update our statistics for this filename
        $files{$change->filename1}{changes} += $size;
        $files{$change->filename1}{pr_count} += 1;
        if($change->type eq "ADD") {
            $files{$change->filename1}{adds}++;
        } elsif($change->type eq "REMOVE") {
            $files{$change->filename1}{removes}++;
        } else { # Change is a "modify" 
            $files{$change->filename1}{adds}++;
            $files{$change->filename1}{removes}++;
        }
        
        if(! exists $files{$change->filename1}{pull_requests}){
            push(@{$files{$change->filename1}{pull_requests}}, $diff_file);
        } elsif(${$files{$change->filename1}{pull_requests}}[-1] ne $diff_file) {
            push(@{$files{$change->filename1}{pull_requests}}, $diff_file);
        }
        
    }
}

my @sorted = sort { $files{$b}{changes} <=> $files{$a}{changes} } keys %files;
foreach my $file (@sorted) {
    print "$file \n";
    print Dumper $files{$file};
}
