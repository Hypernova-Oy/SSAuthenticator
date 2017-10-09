#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;
use t::Mocks;

use SSAuthenticator;
use SSAuthenticator::Config;

my $defaultConfTempFile = t::Examples::writeDefaultConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

#$ENV{SSA_LOG_LEVEL} = -4; #Debug verbosity

#Test that the relay actually is closed for the given duration.
subtest "Door control relay closed duration", \&doorClosedDuration;
sub doorClosedDuration {
    my $ssAuthenticatorMockModule = Test::MockModule->new('SSAuthenticator');
    $ssAuthenticatorMockModule->mock('doorOn', \&t::Mocks::doorOnTimed);
    $ssAuthenticatorMockModule->mock('doorOff', \&t::Mocks::doorOffTimed);

    my $doorOpenDuration = SSAuthenticator::Config::setDoorOpenDuration(5000);
    is($doorOpenDuration, 5000, "Configuration 'DoorOpenDuration' properly set");

    SSAuthenticator::grantAccess(SSAuthenticator::OK);
    my $duration = $t::Mocks::doorOffTime - $t::Mocks::doorOnTime;
    ok($duration >= 5, "Kept the relay on for the configured duration");
}

t::Examples::rmConfig();

done_testing();
