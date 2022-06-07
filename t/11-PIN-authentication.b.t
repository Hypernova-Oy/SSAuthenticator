#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

BEGIN {
    $ENV{SSA_LOG_LEVEL} = -4; #Logging verbosity adjustment 4 is fatal -4 is debug always
}

use Modern::Perl;

use Test::More;
use Test::MockModule;

use HTTP::Response;
use JSON;

use t::Examples;
use t::Mocks;
use t::Mocks::HTTPResponses;
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



subtest "Scenario: Haisuli tries to access a self-service resource using PIN-auth. Having redeemed his ways, he has challenges with his PIN-code.", \&haisuliRedemption;
sub haisuliRedemption {
    my ($module, $moduleApi);

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

    scenario({
        name => "Haisuli tries to authenticate, but the server API authentication is broken, error not cached!",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_API_AUTH,
        assert_cardCached => undef,
        assert_cardCacheUsed => 0,
        assert_pinAuthStatus => undef,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg    => 'Device API failure.+?Bad authentication'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '167A006007',
                },
                response => HTTP::Response->parse(t::Mocks::HTTPResponses::SSStatus401Unauthenticated()),
            },
        ],
        postTests => sub {
            ok(SSAuthenticator::API::isMalfunctioning(), 'API is not malfunctioning');
        },
    });

    scenario({
        name => "Haisuli tries to authenticate, but the cardnumber is wrong",
        cardnumber => '700600A761',
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_BADCARD,
        assert_cardCached => undef,
        assert_cardCacheUsed => undef,
        assert_pinAuthStatus => undef,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg    => 'Card not recognized'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '700600A761',
                },
                response => {
                    httpCode => 404,
                    headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
                    body     => JSON::encode_json({error => 'Koha::Exception::UnknownObject'}),
            },  },
        ],
        postTests => sub {
            ok(not(SSAuthenticator::API::isMalfunctioning()), 'API is not malfunctioning');
        },
    });

    scenario({
        name => "Haisuli has proper card and enters PIN correctly, both get cached",
        assert_authStatus => 1,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => 1,
        assert_cardCacheUsed => undef,
        pinCharInput => [
            ['1', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['4', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_DONE],
        ],
        assert_pinAuthStatus => $SSAuthenticator::OK,
        assert_pinAuthCached => 1,
        assert_pinAuthCacheUsed => 0,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showPINProgress    => '\*\*\*I'],
            [showPINProgress    => '\*\*\*\* '],
            [showPINStatusOKPIN => 'PIN OK'],
            [showAccessMsg      => 'Access granted'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '167A006007',
                },
                response => t::Mocks::api_response_card_authz_ok(),
            },
            {   request => {
                    password => '1234',
                },
                response => t::Mocks::api_response_pin_authn_ok(),
            },
        ],
        postTests => sub {
            ok(not($SSAuthenticator::keyPad->isOn()), 'KeyPad is off after querying the PIN-code');
        },
    });

    scenario({
        name => "Haisuli has proper card and enters PIN correctly, network down, cache used",
        assert_authStatus => 1,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => undef,
        assert_cardCacheUsed => 1,
        pinCharInput => [
            ['1', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['4', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_DONE],
        ],
        assert_pinAuthStatus => $SSAuthenticator::OK,
        assert_pinAuthCached => undef,
        assert_pinAuthCacheUsed => 1,
        assert_oledMsgs => [
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showPINProgress    => '\*\*\*I'],
            [showPINProgress    => '\*\*\*\* '],
            [showPINStatusOKPIN => 'PIN OK'],
            [showAccessMsg      => 'Access granted.+?I Remembered you!'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '167A006007',
                },
                response => {
                    _no_connection => 1, # No response, the API timeouts internally.
            },  },
            {   request => {
                    password => '1234',
                },
                response => {
                    _no_connection => 1, # No response, the API timeouts internally.
            },  },
        ],
    });

    scenario({
        name => "Haisuli has a bad card, network down",
        cardnumber => '700600A761',
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_SERVERCONN,
        assert_cardCached => undef,
        assert_cardCacheUsed => 0,
        assert_pinAuthStatus => undef,
        assert_oledMsgs => [
            [showAccessMsg      => 'Access denied.+?Connection error'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '700600A761',
                },
                response => {
                    _no_connection => 1, # No response, the API timeouts internally.
            },  },
        ],
    });

    scenario({
        name => "Haisuli has proper card and enters the wrong PIN, network down, so caches are not flushed",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => undef,
        assert_cardCacheUsed => 1,
        assert_cardCacheFlushed => undef,
        pinCharInput => [
            ['4', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['1', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_DONE],
        ],
        assert_pinAuthStatus => $SSAuthenticator::ERR_PINBAD,
        assert_pinAuthCached => undef,
        assert_pinAuthCacheUsed => 1,
        assert_pinCacheFlushed => undef,
        assert_oledMsgs => [
            [showEnterPINMsg       => 'Please enter PIN'],
            [showPINProgress       => '\*  I'],
            [showPINProgress       => '\*\* I'],
            [showPINProgress       => '\*\*\*I'],
            [showPINProgress       => '\*\*\*\* '],
            [showPINStatusWrongPIN => 'Wrong PIN code'],
            [showAccessMsg         => 'Invalid PIN-code.+?I Remembered you!'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '167A006007',
                },
                response => {
                    _no_connection => 1, # No response, the API timeouts internally.
            },  },
            {   request => {
                    password => '4321',
                },
                response => {
                    _no_connection => 1, # No response, the API timeouts internally.
            },  },
        ],
        postTests => sub {
            ok(SSAuthenticator::API::isMalfunctioning(), 'API is malfunctioning');
        },
    });

    scenario({
        name => "Haisuli has proper card and enters the wrong PIN, PIN cache is not updated",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => 1,
        assert_cardCacheUsed => undef,
        assert_cardCacheFlushed => undef,
        pinCharInput => [
            ['0', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['*', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['#', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['1', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_DONE],
        ],
        assert_pinAuthStatus => $SSAuthenticator::ERR_PINBAD,
        assert_pinAuthCached => undef,
        assert_pinAuthCacheUsed => 0,
        assert_pinCacheFlushed => undef,
        assert_oledMsgs => [
            [showEnterPINMsg       => 'Please enter PIN'],
            [showPINProgress       => '\*  I'],
            [showPINProgress       => '\*\* I'],
            [showPINProgress       => '\*\*\*I'],
            [showPINProgress       => '\*\*\*\* '],
            [showPINStatusWrongPIN => 'Wrong PIN code'],
            [showAccessMsg         => 'Invalid PIN-code'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '167A006007',
                },
                response => t::Mocks::api_response_card_authz_ok(),
            },
            {   request => {
                    password => '0*#1',
                },
                response => t::Mocks::api_response_pin_authn_bad(),
            },
        ],
    });

    scenario({
        name => "Haisuli has proper card and enters PIN correctly, network down, PIN cache hit, access granted",
        assert_authStatus => 1,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => undef,
        assert_cardCacheUsed => 1,
        pinCharInput => [
            ['1', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['4', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_DONE],
        ],
        assert_pinAuthStatus => $SSAuthenticator::OK,
        assert_pinAuthCached => undef,
        assert_pinAuthCacheUsed => 1,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showPINProgress    => '\*\*\*I'],
            [showPINProgress    => '\*\*\*\* '],
            [showPINStatusOKPIN => 'PIN OK'],
            [showAccessMsg      => 'Access granted'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '167A006007',
                },
                response => {
                    _no_connection => 1, # No response, the API timeouts internally.
            },  },
            {   request => {
                    password => '1234',
                },
                response => {
                    _no_connection => 1, # No response, the API timeouts internally.
            },  },
        ],
    });

    scenario({
        name => "Haisuli has proper card and enters PIN too slowly, PIN timeouts",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => 1,
        assert_cardCacheUsed => undef,
        assert_cardCacheFlushed => undef,
        pinCharInput => [
            ['1', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 200, 'SSAuthenticator::Exception::KeyPad::WaitTimeout'],
            ['4', 100, 'KEYPAD_INACTIVE'],
        ],
        assert_pinAuthStatus => $SSAuthenticator::ERR_PINTIMEOUT,
        assert_pinAuthCached => undef,
        assert_pinAuthCacheUsed => undef,
        assert_pinCacheFlushed => undef,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showAccessMsg      => 'PIN entry timeouted'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '167A006007',
                },
                response => t::Mocks::api_response_card_authz_ok(),
            },
        ],
        postTests => sub {
            ok(not($SSAuthenticator::keyPad->isOn()), 'KeyPad is off after querying the PIN-code');
        },
    });

    scenario({
        name => "Haisuli has proper card and enters PIN correctly, both get cached",
        assert_authStatus => 1,
        assert_authStatus => $SSAuthenticator::OK,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => 1,
        assert_cardCacheUsed => undef,
        pinCharInput => [
            ['1', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['2', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['3', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW],
            ['4', 100, $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_DONE],
        ],
        assert_pinAuthStatus => 1,
        assert_pinAuthCached => 1,
        assert_pinAuthCacheUsed => 0,
        assert_oledMsgs => [
            [showEnterPINMsg    => 'Please enter PIN'],
            [showPINProgress    => '\*  I'],
            [showPINProgress    => '\*\* I'],
            [showPINProgress    => '\*\*\*I'],
            [showPINProgress    => '\*\*\*\* '],
            [showPINStatusOKPIN => 'PIN OK'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '167A006007',
                },
                response => t::Mocks::api_response_card_authz_ok(),
            },
            {   request => {
                    password => '1234',
                },
                response => t::Mocks::api_response_pin_authn_ok(),
            },
        ],
    });

    scenario({
        name => "Haisuli has too many fines and is blocked, cache card permissions, preserve PIN",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_NAUGHTY,
        assert_cardCached => 1,
        assert_cardCacheUsed => undef,
        assert_pinAuthStatus => undef,
        assert_oledMsgs => [
            [showAccessMsg    => 'Access denied.+?Circulation rules'],
        ],
        httpTransactions => [
            {   request => {
                    cardnumber => '167A006007',
                },
                response => t::Mocks::api_response_card_authz_bad(),
            },
        ],
        postTests => sub {
            ok(SSAuthenticator::Password::check_password('167A006007', '1234', SSAuthenticator::db()->{'167A006007'}->{pin}), 'Password is still properly cached');
            ok(not($SSAuthenticator::keyPad->isOn()), 'KeyPad is off after querying the PIN-code');
        },
    });

    t::Examples::rmConfig();
    t::Examples::rmCacheDB();
}




done_testing();
