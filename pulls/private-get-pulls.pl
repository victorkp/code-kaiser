#!/usr/bin/perl
use Pithub;
use Env;
use Data::Dumper;
use strict;
use warnings;

# Get the last XX pull requests
for(my $i = 110; $i > 109; $i--) {
    if(-f "${i}.diff") {
        next;
    }

    print "\n\nGetting ${i}.diff\n";

    my $p = Pithub::PullRequests->new;
    my $pull_is_merged = $p->is_merged(user            => 'augmate',
                                       repo            => 'augmate-wear',
                                       token           => $ENV{'GITHUB_ACCESS_TOKEN'},
                                       pull_request_id => $i);

    if($pull_is_merged) {
        my $pull = $p->get(user            => 'augmate',
                           repo            => 'augmate-wear',
                           token           => $ENV{'GITHUB_ACCESS_TOKEN'},
                           pull_request_id => $i);

        print Data::Dumper->Dump([$pull]);
    }


}

system "rm -f wget.log";

# Remove not-merged pulls
system 'grep -lrIZ --include \*.diff DOCTYPE . | xargs -0 rm -f --'
