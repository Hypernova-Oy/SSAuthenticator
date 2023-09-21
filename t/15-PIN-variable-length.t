#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

BEGIN {
    $ENV{SSA_LOG_LEVEL} = -4; #Logging verbosity adjustment 4 is fatal -4 is debug always
}

use Modern::Perl;

use Test::More tests => 5;
use Test::MockModule;

use HTTP::Response;
use JSON;

use t::Examples;
use t::Mocks;
use t::Mocks::HTTPResponses;
use t::Mocks::OpeningHours;
use t::Util qw(scenario);
use SSAuthenticator;
use SSAuthenticator::I18n;
use SSAuthenticator::Device::KeyPad;
use SSAuthenticator::Exception::KeyPad::WaitTimeout;
use SSAuthenticator::Transaction;


my $updateCacheTriggered = 0; #Keep track if the cache was actually updated. Occasionally return values can be the same as cached values even if no cache was updated, leading to a lot of confusion.
my $ssAuthenticatorApiMockModule;
my $ssAuthenticatorKeyPadMockModule;

=head2 11-PIN-authentication.b.t

Behavioural test case where Haisuli gets different kinds of errors while he tries to fix problems with his user account

=cut


subtest "Scenario: Set-up test context", \&testContextSetUp;
sub testContextSetUp {
    plan tests => 1;

    t::Examples::createCacheDB();
    my $defaultConfTempFile = t::Examples::writeConf('RequirePIN 1','PINLength 4','PINTimeout 150');
    SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

    SSAuthenticator::I18n::changeLanguage('en_GB', 'UTF-8');
    $SSAuthenticator::keyPad = SSAuthenticator::Device::KeyPad::init(SSAuthenticator::config());
    SSAuthenticator::Device::RGBLed::init(SSAuthenticator::config());

    $ssAuthenticatorApiMockModule = Test::MockModule->new('SSAuthenticator::API');
    $ssAuthenticatorApiMockModule->mock('_do_api_request', \&t::Mocks::_do_api_request_check_against_list);
    $ssAuthenticatorKeyPadMockModule = Test::MockModule->new('SSAuthenticator::Device::KeyPad');
    $ssAuthenticatorKeyPadMockModule->mock('_read', \&t::Mocks::_keyPad_read_inputs);

    # Configure cached opening hours to be always open. The cached opening hours are only used in the offline-mode.
    # Otherwise we always check the newest opening information from Koha.
    my $ohs = t::Mocks::OpeningHours::createAlwaysOpen();
    ok(SSAuthenticator::OpeningHours::_persistOpeningHoursToDB($ohs), "Given the OpeningHours: Always open");    
}

subtest "Scenario: Fixed-length PIN-code requires no termination sign.", \&fixedLengthPIN;
sub fixedLengthPIN {
    SSAuthenticator::Config::getConfig()->param('PINLength', 4);
    SSAuthenticator::Config::getConfig()->param('PINLengthMin', 4);
    $SSAuthenticator::keyPad = SSAuthenticator::Device::KeyPad::init(SSAuthenticator::config());


    SSAuthenticator::Config::getConfig()->param('PINDisplayStyle', 'hide');
    scenario({
        name => "PIN timeouts",
        pinCharInput => [
            ['1', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            [undef, 200, 'SSAuthenticator::Exception::KeyPad::WaitTimeout'],
            ['4', 100, 'KEYPAD_INACTIVE'],
        ],
        assert_pinAuthStatus => $SSAuthenticator::ERR_PINTIMEOUT,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showAccessMsg      => 'PIN entry timeouted'],
        ],
        postTests => sub {
            ok(not($SSAuthenticator::keyPad->isOn()), 'KeyPad is off after querying the PIN-code');
        },
    });

    SSAuthenticator::Config::getConfig()->param('PINDisplayStyle', 'show');
    scenario({
        name => "PIN malformed from device",
        pinCharInput => [
            ['1', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['ÿ', 100, $KEYPAD_TRANSACTION_UNDERFLOW], #Malformed character read
            ['4', 100, $KEYPAD_TRANSACTION_DONE],
            ['5', 100, 'KEYPAD_INACTIVE'],
        ],
        assert_pinAuthStatus => $SSAuthenticator::ERR_PININVALID,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '1  I'],
            [showPINProgress    => '12 I'],
            [showPINProgress    => '12ÿI'],
            [showPINProgress    => '12ÿ4 '],
            [showPINStatusWrongPIN => '   Wrong PIN code   '],
            [showAccessMsg      => 'Reading PIN failed.+?PIN device error'],
        ],
        postTests => sub {
            ok(not($SSAuthenticator::keyPad->isOn()), 'KeyPad is off after querying the PIN-code');
        },
    });

    SSAuthenticator::Config::getConfig()->param('PINDisplayStyle', 'last');
    scenario({
        name => "Correct PIN",
        assert_pinCode => "1234",
        pinCharInput => [
            ['1', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['4', 100, $KEYPAD_TRANSACTION_DONE],
            ['5', 100, 'KEYPAD_INACTIVE'],
        ],
        assert_pinAuthStatus => 1,
        assert_oledMsgs => [
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '1  I'],
            [showPINProgress    => '\*2 I'],
            [showPINProgress    => '\*\*3I'],
            [showPINProgress    => '\*\*\*4 '],
            [showPINStatusOKPIN => 'PIN OK'],
        ],
    });
}

subtest "Scenario: Variable-length PIN-code requires no termination sign once max length is reached.", \&variableLengthPIN;
sub variableLengthPIN {
    SSAuthenticator::Config::getConfig()->param('PINLength', 8);
    SSAuthenticator::Config::getConfig()->param('PINLengthMin', 4);
    SSAuthenticator::Config::getConfig()->param('PINDisplayStyle', 'hide');
    $SSAuthenticator::keyPad = SSAuthenticator::Device::KeyPad::init(SSAuthenticator::config());

    scenario({
        name => "PIN timeouts",
        pinCharInput => [
            ['1', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['4', 100, $KEYPAD_TRANSACTION_MAYBE_DONE],
            ['5', 100, $KEYPAD_TRANSACTION_MAYBE_DONE],
            [undef, 200, 'SSAuthenticator::Exception::KeyPad::WaitTimeout'],
            ['7', 100, 'KEYPAD_INACTIVE'],
        ],
        assert_pinAuthStatus => $SSAuthenticator::ERR_PINTIMEOUT,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showPINProgress    => '\*\*\*I'],
            [showPINProgress    => '\*\*\*\*'],
            [showPINOptions     => '\\#.+\\$'],
            [showPINProgress    => '\*\*\*\*\*'],
            [showAccessMsg      => 'PIN entry timeouted'],
        ],
        postTests => sub {
            ok(not($SSAuthenticator::keyPad->isOn()), 'KeyPad is off after querying the PIN-code');
        },
    });

    scenario({
        name => "Correct PIN",
        assert_pinCode => "12345678",
        pinCharInput => [
            ['1', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 100, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['4', 100, $KEYPAD_TRANSACTION_MAYBE_DONE],
            ['5', 100, $KEYPAD_TRANSACTION_MAYBE_DONE],
            ['6', 100, $KEYPAD_TRANSACTION_MAYBE_DONE],
            ['7', 100, $KEYPAD_TRANSACTION_MAYBE_DONE],
            ['8', 100, $KEYPAD_TRANSACTION_DONE],
        ],
        assert_pinAuthStatus => 1,
        assert_oledMsgs => [
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showPINProgress    => '\*\*\*I'],
            [showPINProgress    => '\*\*\*\* '],
            [showPINStatusOKPIN => 'PIN OK'],
        ],
    });
}

subtest "Scenario: Variable-length PIN-code is sent after #-key is pressed. PIN-entry is reset with \$-key", \&variableLengthSpecialCharactersPIN;
sub variableLengthSpecialCharactersPIN {
    SSAuthenticator::Config::getConfig()->param('PINLength', 10);
    SSAuthenticator::Config::getConfig()->param('PINLengthMin', 5);
    SSAuthenticator::Config::getConfig()->param('PINDisplayStyle', 'hide');
    $SSAuthenticator::keyPad = SSAuthenticator::Device::KeyPad::init(SSAuthenticator::config());

    scenario({
        name => "Correct short PIN after user reset",
        assert_pinCode => "12345678",
        pinCharInput => [
            ['1', 50, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 50, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['6', 50, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['$', 50, $KEYPAD_TRANSACTION_RESET],
            ['1', 50, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 50, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 50, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['4', 50, $KEYPAD_TRANSACTION_UNDERFLOW],
            ['5', 50, $KEYPAD_TRANSACTION_MAYBE_DONE],
            ['6', 50, $KEYPAD_TRANSACTION_MAYBE_DONE],
            ['7', 50, $KEYPAD_TRANSACTION_MAYBE_DONE],
            ['8', 50, $KEYPAD_TRANSACTION_MAYBE_DONE],
            ['#', 50, $KEYPAD_TRANSACTION_DONE],
        ],
        assert_pinAuthStatus => 1,
        assert_oledMsgs => [
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showPINProgress    => '\*\*\*I'],
            [showPINProgress    => '   I'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showPINProgress    => '\*\*\*I'],
            [showPINProgress    => '\*\*\*\* '],
            [showPINProgress    => '\*\*\*\*\*'],
            [showPINOptions     => '\\#.+\\$'],
            [showPINProgress    => '\*\*\*\*\*\*'],
            [showPINProgress    => '\*\*\*\*\*\*\*'],
            [showPINProgress    => '\*\*\*\*\*\*\*\*'],
            [showPINStatusOKPIN => 'PIN OK'],
        ],
    });
}

subtest "Scenario: Tear-down test context", \&testContextTearDown;
sub testContextTearDown {
    t::Examples::rmConfig();
    ok(t::Examples::rmCacheDB(), "Remove cache db");
}

done_testing();
