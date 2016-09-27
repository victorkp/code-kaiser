#!/usr/bin/perl -I../lib

use CodeKaiser::DiffStatistics;
use Data::Compare;
use Data::Dumper;

# No configuration file argument should return undef
print "No status file           ";
my $status = CodeKaiser::DiffStatistics->new;
!$status or die;
print "| PASSED\n";

### Testing default values
#
`rm tmp/test-diff-stat > /dev/null 2>&1`;
$status = CodeKaiser::DiffStatistics->new(diff_stat_file => 'tmp/test-diff-stat');

print "Creates default file     ";
-e 'tmp/test-diff-stat' or die;
print "| PASSED\n";

print "Default file values      ";
$status->diff_sha()              eq ""   or die;
$status->diff_number()           == 0    or die;
$status->get_total_additions()   == 0    or die;
$status->get_total_removals()    == 0    or die;
print "| PASSED\n";

# Test persistance
print "Persistent values        ";
$status->diff_sha("abcd1234");
$status->add_additions("file1", 1000);
$status->add_additions("file2", 2000);
$status->write_file();
$status = CodeKaiser::DiffStatistics->new(diff_stat_file => 'tmp/test-diff-stat');
$status->diff_sha()                      eq "abcd1234"                     or die;
$status->get_all_additions()->{'file1'}  eq 1000                           or die;
$status->get_all_additions()->{'file2'}  eq 2000                           or die;
$status->get_total_additions()           eq 3000                           or die;
print "| PASSED\n";

print "Die on bad values        ";
eval { $config->diff_sha('zzzz'); }; $@ or die;
print "| PASSED\n";

`rm tmp/test-config > /dev/null 2>&1`;
