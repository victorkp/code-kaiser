#!/usr/bin/perl -I../lib

use CodeKaiser::PRStatus;

# No configuration file argument should return undef
print "No status file           ";
my $status = CodeKaiser::PRStatus->new;
!$status or die;
print "| PASSED\n";

### Testing default values
#
`rm tmp/test-status > /dev/null 2>&1`;
$status = CodeKaiser::PRStatus->new(status_file => 'tmp/test-status');

print "Creates default file     ";
-e 'tmp/test-status' or die;
print "| PASSED\n";

print "Default file values      ";
$status->pr_name()          eq ""                                   or die;
$status->pr_status          == $CodeKaiser::PRStatus::PR_UNKNOWN    or die;
$status->merge_status()     == $CodeKaiser::PRStatus::MERGE_UNKNOWN or die;
$status->recheck_time()     == 0                                    or die;
$status->status_message()   eq ""                                   or die;
print "| PASSED\n";

# Test persistance
print "Persistent values        ";
$status->pr_name("test-name");
$status->pr_status($CodeKaiser::PRStatus::PR_MERGED);
$status->merge_status($CodeKaiser::PRStatus::MERGE_OK);
$status->recheck_time(100);
$status->status_message("test");
$status = CodeKaiser::PRStatus->new(status_file => 'tmp/test-status');
$status->pr_name()               eq "test-name"                         or die;
$status->pr_status               == $CodeKaiser::PRStatus::PR_MERGED    or die;
$status->merge_status()          eq $CodeKaiser::PRStatus::MERGE_OK     or die;
$status->recheck_time()          == 100                                 or die;
$status->status_message()        eq "test"                              or die;
print "| PASSED\n";

print "Die on bad values        ";
eval { $config->pr_status('zzzz');        }; $@ or die;
eval { $config->merge_status('zzzz');     }; $@ or die;
eval { $config->recheck_time('zzzz');     }; $@ or die;
print "| PASSED\n";

`rm tmp/test-config > /dev/null 2>&1`;
