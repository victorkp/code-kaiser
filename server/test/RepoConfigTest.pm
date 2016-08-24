#!/usr/bin/perl -I../lib

use CodeKaiser::RepoConfig;

# No configuration file argument should return undef
print "No config file           ";
my $config = CodeKaiser::RepoConfig->new;
!$config or die;
print "| PASSED\n";

### Testing default values
#
`rm tmp/test-config > /dev/null 2>&1`;
$config = CodeKaiser::RepoConfig->new(config_file => 'tmp/test-config');

print "Creates default file     ";
-e 'tmp/test-config' or die;
print "| PASSED\n";

print "Default file values      ";
$config->github_token()     == $CodeKaiser::RepoConfig::DEFAULT_GITHUB_TOKEN     or die;
$config->reviewers_needed() == $CodeKaiser::RepoConfig::DEFAULT_REVIEWERS_NEEDED or die;
$config->blocking_enabled() == $CodeKaiser::RepoConfig::DEFAULT_BLOCKING_ENABLED or die;
$config->blocking_timeout() == $CodeKaiser::RepoConfig::DEFAULT_BLOCKING_TIMEOUT or die;
print "| PASSED\n";

# Test persistance
print "Persistent values        ";
$config->github_token(100);
$config->reviewers_needed(100);
$config->blocking_enabled(100);
$config->blocking_timeout(100);
$config = CodeKaiser::RepoConfig->new(config_file => 'tmp/test-config');
$config->github_token()     == 100 or die;
$config->reviewers_needed() == 100 or die;
$config->blocking_enabled() == 100 or die;
$config->blocking_timeout() == 100 or die;
print "| PASSED\n";

print "Die on bad values        ";
eval { $config->github_token('zzzz');     }; $@ or die;
eval { $config->reviewers_needed('zzzz'); }; $@ or die;
eval { $config->blocking_enabled('zzzz'); }; $@ or die;
eval { $config->blocking_timeout('zzzz'); }; $@ or die;
print "| PASSED\n";

`rm tmp/test-config > /dev/null 2>&1`;
