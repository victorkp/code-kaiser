#!/usr/bin/perl -I../lib

use CodeKaiser::UserStatistics;
use Data::Dumper;

# No configuration file argument should return undef
print "No user file             ";
my $user = CodeKaiser::UserStatistics->new;
!$user or die;
print "| PASSED\n";

### Testing default values
#
`rm tmp/test-user > /dev/null 2>&1`;
$user = CodeKaiser::UserStatistics->new(user_file => 'tmp/test-user');
$user->write_user();

print "Creates default file     ";
-e 'tmp/test-user' or die;
print "| PASSED\n";

print "Default file values      ";
$user->user_name()               eq ""                                   or die;
print "| PASSED\n";

# Test persistance
print "Persistent values        ";
$user->user_name("test-name");
$user->file_changed_add_additions("file1", 30);
$user->file_changed_add_removals("file2", 31);
$user->file_reviewed_add_additions("file3", 32);
$user->file_reviewed_add_removals("file4", 33);
$user->write_user();

$user = CodeKaiser::UserStatistics->new(user_file => 'tmp/test-user');
$user->user_name()                             eq "test-name"      or die;
$user->file_changed_get_additions("file1")     == 30               or die;
$user->file_changed_get_removals("file2")      == 31               or die;
$user->file_changed_add_additions("file1", 30) == 60               or die;
$user->file_changed_add_removals("file2", 31)  == 62               or die;

$user->file_reviewed_get_additions("file3")     == 32               or die;
$user->file_reviewed_get_removals("file4")      == 33               or die;
$user->file_reviewed_add_additions("file3", 32) == 64               or die;
$user->file_reviewed_add_removals("file4", 33)  == 66               or die;
print "| PASSED\n";

`rm tmp/test-config > /dev/null 2>&1`;
