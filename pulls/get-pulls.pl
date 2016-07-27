#!/usr/bin/perl
use strict;
use warnings;

my $url = "https://patch-diff.githubusercontent.com/raw/StephenBlackWasAlreadyTaken/xDrip-Experimental/pull/";

# Get the last XX pull requests
for(my $i = 355; $i > 0; $i--) {
    # Only get missing pulls
    if(! -f "${i}.diff") { 
        print "Getting ${i}.diff";
        system "wget ${url}${i}.diff > /dev/null 2>&1";
    }
}

system "rm -f wget.log";

# Remove not-merged pulls
system 'grep -lrIZ --include \*.diff DOCTYPE . | xargs -0 rm -f --'
