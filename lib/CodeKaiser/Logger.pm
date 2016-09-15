#!/usr/bin/perl
{ 
    package CodeKaiser::Logger;

    use strict;
    use warnings;

    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);


    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(log_debug log_error log_verbose log_line);

    my $LOGFILE = "/tmp/code-kaiser";

    # Open logfile, and make it "hot", so that flushes happen frequently
    open(my $LOG, ">$LOGFILE") or die "Couldn't open logfile";
    { my $ofh = select $LOG;
      $| = 1;
      select $ofh;
    }

    sub get_caller() {
        my @caller = caller(2);
        if(@caller) {
            return sprintf("%-45s", $caller[3]);
        }

        return '';
    }

    sub log_line() {
        print $LOG "\n";
    }

    sub log_verbose {
        print $LOG "$$ Verb. | ", get_caller(),' | ', @_, "\n";
    }

    sub log_debug {
        print $LOG "$$ Debug | ", get_caller(),' | ', @_, "\n";
    }
    
    sub log_error {
        print $LOG "$$ Error | ", get_caller(),' | ', @_, "\n";
    }

}
