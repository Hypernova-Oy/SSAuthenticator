#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;

use GPIO::Relay;

use SSAuthenticator;
use SSAuthenticator::Config;
use SSAuthenticator::OLED;

my $defaultConfTempFile = t::Examples::writeDefaultConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

#$ENV{SSA_LOG_LEVEL} = -4; #Debug verbosity
my $readTime = 1;

subtest "Manually inspect LEDs", \&ledInspection;
sub ledInspection {
    my $ledDuration = 1;

    SSAuthenticator::Device::RGBLed::init();

    SSAuthenticator::OLED::showOLEDMsg(
        ["Turning red led on  ","for ".sprintf("%2.2f", $ledDuration)." seconds   "]);
    ok(SSAuthenticator::Device::RGBLed::ledOn('red'), "Red on");
    sleep($ledDuration);
    ok(SSAuthenticator::Device::RGBLed::ledOff('red'), "Red off");

    SSAuthenticator::OLED::showOLEDMsg(
        ["Turning green led on","for ".sprintf("%2.2f", $ledDuration)." seconds   "]);
    ok(SSAuthenticator::Device::RGBLed::ledOn('green'), "Green on");
    sleep($ledDuration);
    ok(SSAuthenticator::Device::RGBLed::ledOff('green'), "Green off");

    SSAuthenticator::OLED::showOLEDMsg(
        ["Turning blue led on ","for ".sprintf("%2.2f", $ledDuration)." seconds   "]);
    ok(SSAuthenticator::Device::RGBLed::ledOn('blue'), "Blue on");
    sleep($ledDuration);
    ok(SSAuthenticator::Device::RGBLed::ledOff('blue'), "Blue off");
}

subtest "Manually inspect the lock signaling relay", \&lockControl;
sub lockControl {
    my GPIO::Relay $lockControlRelay = SSAuthenticator::lockControl()->relay();

    if (ref($lockControlRelay) eq 'GPIO::Relay::DoubleLatch') {
        subtest "Manually inspect the lock controlling double-latch relay.", \&doubleLatchLockInspection;
    }
    elsif (ref($lockControlRelay) eq 'GPIO::Relay::SingleLatch') {
        subtest "Manually inspect the lock controlling single-latch relay.", \&singleLatchLockInspection;
    }
    else {
        die "Unknown latch type '".ref($lockControlRelay)."'";
    }
}

sub doubleLatchLockInspection {
    SSAuthenticator::OLED::showOLEDMsg(
        ["You should hear one ","click from the relay", "with 1 second delay ", "Door opens.         "]);
    sleep($readTime);
    ok(SSAuthenticator::lockControl()->on(), "Lock open signal on");
    sleep(1);
    ok(SSAuthenticator::lockControl()->off(), "Lock open signal off");

    sleep(1);

    SSAuthenticator::OLED::showOLEDMsg(
        ["You should hear one ","click from the relay", "with 1 second delay ", "Door closes.        "]);
    sleep($readTime);
    ok(SSAuthenticator::lockControl()->on(), "Lock close signal on");
    sleep(1);
    ok(SSAuthenticator::lockControl()->off(), "Lock close signal off");
}

sub singleLatchLockInspection {
    SSAuthenticator::OLED::showOLEDMsg(
        ["You should hear two ","clicks from the     ", "relay with 1 second ", "delay. Door opens.  "]);
    sleep($readTime);
    ok(SSAuthenticator::lockControl()->on(), "Door opened");
    sleep 1;
    ok(SSAuthenticator::lockControl()->off(), "Door closed");
}

SSAuthenticator::OLED::showOLEDMsg( #Flush excess rows
  ["                    ","                    ","                    ","                    "]);

subtest "Manually inspect beeper.", \&beeperInspection;
sub beeperInspection {
    SSAuthenticator::OLED::showOLEDMsg(
        ["You should hear the ","access granted sound"]);
    ok(SSAuthenticator::RTTTL::playAccessBuzz() || 1, "Access granted sound played");
}

t::Examples::rmConfig();

done_testing();
