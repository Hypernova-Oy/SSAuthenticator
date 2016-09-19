#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;

use Authenticator;

my $defaultConfTempFile = t::Examples::writeDefaultConf();
Authenticator::setConfigFile($defaultConfTempFile->filename());

subtest "Manually inspect LEDs", \&ledInspection;
sub ledInspection {
    my $ledDuration = 1;

    print "Turning red led on for $ledDuration seconds\n";
    ok(Authenticator::ledOn('red'), "Red on");
    sleep($ledDuration);
    ok(Authenticator::ledOff('red'), "Red off");

    print "Turning green led on for $ledDuration seconds\n";
    ok(Authenticator::ledOn('green'), "Green on");
    sleep($ledDuration);
    ok(Authenticator::ledOff('green'), "Green off");

    print "Turning blue led on for $ledDuration seconds\n";
    ok(Authenticator::ledOn('blue'), "Blue on");
    sleep($ledDuration);
    ok(Authenticator::ledOff('blue'), "Blue off");
}

subtest "Manually inspect door non-latching relay.", \&doorInspection;
sub doorInspection {
    print "You should hear two clicks from the relay with a 1 second delay\n";
    ok(Authenticator::doorOn(), "Door opened");
    sleep 1;
    ok(Authenticator::doorOff(), "Door closed");
}

subtest "Manually inspect beeper.", \&beeperInspection;
sub beeperInspection {
    print "You should hear the access granted sound\n";
    ok(Authenticator::playRTTTL('toveri_access_granted'), "Access granted sound played");
}

t::Examples::rmConfig();

done_testing();
