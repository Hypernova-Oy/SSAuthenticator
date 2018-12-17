#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;

use GPIO::Relay;

use SSAuthenticator;
use SSAuthenticator::Config;

my $defaultConfTempFile = t::Examples::writeDefaultConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

#$ENV{SSA_LOG_LEVEL} = -4; #Debug verbosity


# rtttl-player might not return correctly, and makes the whole SSAuthenticator freeze.
# Fork the player to the background instead of waiting for it to finish.
# Add a timeout to kill dangling processes.

subtest "rtttl-player is asynchronous", sub {
  my $start = Time::HiRes::time();
  SSAuthenticator::playRTTTL("toveri_access_denied");
  my $duration = Time::HiRes::time() - $start;
  print "$duration\n";
  ok($duration < 0.1, "rtttl-player invoked non-blocking");

  sleep(2); # Wait for the song to end.
};

subtest "Catch the rtttl-player from freezing indefinitely", sub {
  ok(SSAuthenticator::playRTTTL('toveri_access_granted', 1),
      "");
};


done_testing;
