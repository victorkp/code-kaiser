#!/usr/bin/perl -I../lib

use CodeKaiser::PullRulesConfig;

# No configuration file argument should return undef
print "No config file           ";
my $config = CodeKaiser::PullRulesConfig->new;
!$config or die;
print "| PASSED\n";

### Testing default values
#
`rm tmp/test-config`;
$config = CodeKaiser::PullRulesConfig->new(config_file => 'tmp/test-config');

print "Creates default file     ";
-e 'tmp/test-config' or die;
print "| PASSED\n";

print "Default file values      ";
$config->github_token()     == $CodeKaiser::PullRulesConfig::DEFAULT_GITHUB_TOKEN     or die;
$config->reviewers_needed() == $CodeKaiser::PullRulesConfig::DEFAULT_REVIEWERS_NEEDED or die;
$config->blocking_enabled() == $CodeKaiser::PullRulesConfig::DEFAULT_BLOCKING_ENABLED or die;
$config->blocking_timeout() == $CodeKaiser::PullRulesConfig::DEFAULT_BLOCKING_TIMEOUT or die;
print "| PASSED\n";

# Test persistance
print "Persistent values        ";
$config->github_token(0);
$config->reviewers_needed(0);
$config->blocking_enabled(0);
$config->blocking_timeout(0);
$config = CodeKaiser::PullRulesConfig->new(config_file => 'tmp/test-config');
$config->github_token()     == 0 or die;
$config->reviewers_needed() == 0 or die;
$config->blocking_enabled() == 0 or die;
$config->blocking_timeout() == 0 or die;
print "| PASSED\n";

print "Die on bad values        ";
eval { $config->github_token('zzzz');     }; $@ or die;
eval { $config->reviewers_needed('zzzz'); }; $@ or die;
eval { $config->blocking_enabled('zzzz'); }; $@ or die;
eval { $config->blocking_timeout('zzzz'); }; $@ or die;
print "| PASSED\n";
