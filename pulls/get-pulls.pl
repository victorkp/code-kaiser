#!/usr/bin/perl
use strict;
use warnings;

my $url = "https://patch-diff.githubusercontent.com/raw/StephenBlackWasAlreadyTaken/xDrip-Experimental/pull/";

# Get the last 200 pull requests
for(my $i = 355; $i > 0; $i--) {
    system "wget ${url}${i}.diff";
}

system "rm -f wget.log";

# Remove not-merged pulls (closed pull requests show up as HTML pages, with no diff)
system "find . -type f -exec grep -q DOCTYPE {} \; -exec echo rm {} \;"
