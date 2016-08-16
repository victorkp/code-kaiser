#!/bin/perl
{
    package CodeKaiser::Dispatcher;
    use strict;
    use warnings;
     
    use Exporter;
    use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

    $VERSION     = 1.00;
    @ISA         = qw(Exporter);
    @EXPORT      = ();
    @EXPORT_OK   = qw(dispatch);

    ## Dispatch a subroutine asynchronously,
    ## running a callback on its result
    sub dispatch {
        print "TODO: dispatch\n";
        die "$!";
    }
    
    1;
}
