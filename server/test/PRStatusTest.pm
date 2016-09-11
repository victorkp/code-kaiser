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
$status->merge_status()     == $CodeKaiser::PRStatus::MERGE_UNKNOWN or die;
$status->recheck_time()     == 0                                    or die;
$status->status_message()   eq ""                                   or die;
print "| PASSED\n";

# Test persistance
print "Persistent values        ";
$status->merge_status($CodeKaiser::PRStatus::MERGE_OK);
$status->recheck_time(100);
$status->status_message("test");
$status = CodeKaiser::PRStatus->new(status_file => 'tmp/test-status');
$status->merge_status()          eq $CodeKaiser::PRStatus::MERGE_OK or die;
$status->recheck_time()          == 100;
$status->status_message()        eq "test";
print "| PASSED\n";

print "Die on bad values        ";
eval { $config->merge_status('zzzz');     }; $@ or die;
eval { $config->recheck_time('zzzz');     }; $@ or die;
print "| PASSED\n";

`rm tmp/test-config > /dev/null 2>&1`;
