#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

BEGIN {
    $ENV{SSA_LOG_LEVEL} = -4; #Logging verbosity adjustment 4 is fatal -4 is debug always
    $ENV{SSA_TEST_MODE} = 1;
}

use Modern::Perl;

use Test::More;
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
use SSAuthenticator::OpeningHours;


my $updateCacheTriggered = 0; #Keep track if the cache was actually updated. Occasionally return values can be the same as cached values even if no cache was updated, leading to a lot of confusion.
my $ssAuthenticatorApiMockModule;
my $ssAuthenticatorKeyPadMockModule;

=head2 10-permissions.b.t

Behavioural test case where Haisuli gets different kinds of errors while he tries to fix problems with his user account

=cut


# This is a test suite used without the PIN-code
subtest "Scenario: Haisuli tries to access a self-service resource, but has accumulated almost all possible penalties. Now he is trying to redeem himself.", \&haisuliRedemption;
sub haisuliRedemption {
    plan tests => 13;

    t::Examples::createCacheDB();
    my $defaultConfTempFile = t::Examples::writeConf('RequirePIN 0');
    SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

    SSAuthenticator::I18n::changeLanguage('en_GB', 'UTF-8');
    $SSAuthenticator::keyPad = SSAuthenticator::Device::KeyPad::init(SSAuthenticator::config());
    SSAuthenticator::Device::RGBLed::init(SSAuthenticator::config());

    $ssAuthenticatorApiMockModule = Test::MockModule->new('SSAuthenticator::API');
    $ssAuthenticatorApiMockModule->mock('_do_api_request', \&t::Mocks::_do_api_request_check_against_list);

    # Configure cached opening hours to be always open. The cached opening hours are only used in the offline-mode.
    # Otherwise we always check the newest opening information from Koha.
    my $ohs = t::Mocks::OpeningHours::createAlwaysOpen();
    ok(SSAuthenticator::OpeningHours::_persistOpeningHoursToDB($ohs), "Given the OpeningHours: Always open");

    scenario({
        name => "Haisuli tries to authenticate, but the server is misconfigured. Since Haisuli is not cached, do not cache strange errors.",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_SERVER,
        assert_cardCached => undef,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => 0,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg => 'denied.+Server error'],
        ],
        httpTransactions => [
            {   request => {},
                response => t::Mocks::api_response_feature_unavailable(),
            },
        ],
    });

    scenario({
        name => "Haisuli tries to authenticate, but he is using a wrong card. We shouldn't cache bad cards.",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_BADCARD,
        assert_cardCached => undef,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => undef,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg => 'denied.+Card not recognized'],
        ],
        httpTransactions => [
            {   request => {},
                response => t::Mocks::api_response_card_not_found(),
            },
        ],
    });

    scenario({
        name => "Haisuli tries again, but he's borrower category is HAISULI, not a regular user. User error is cached.",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_BBC,
        assert_cardCached => 1,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => undef,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg => 'denied.+Wrong.+borrower.+category'],
        ],
        httpTransactions => [
            {   request => {},
                response => t::Mocks::api_response_card_bad_borrower_category(),
            },
        ],
    });

    scenario({
        name => "Haisuli tries again after changing his borrower category, but network is down again and the authentication status is returned from the cache :( poor Haisuli.",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_BBC,
        assert_cardCached => undef,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => 1,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg => 'denied.+Wrong.+borrower.+category.+I [Rr]emembered you!'],
        ],
        httpTransactions => [
            {   request => {},
                response => t::Mocks::api_response_server_error(),
            },
        ],
    });

    scenario({
        name => "Haisuli tries again, but he has too many fines or something. User error is cached.",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_NAUGHTY,
        assert_cardCached => 1,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => undef,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg => 'denied.+Circulation.+rules.+not'],
        ],
        httpTransactions => [
            {   request => {},
                response => t::Mocks::api_response_card_authz_bad(),
            },
        ],
    });

    scenario({
        name => "Haisuli tries again, but the library is closed. User error is NOT cached.",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_CLOSED,
        assert_cardCached => undef,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => undef,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg => 'denied.+Open at 12:00-23:00'],
        ],
        httpTransactions => [
            {   request => {},
                response => t::Mocks::api_response_card_library_closed(),
            },
        ],
    });

    scenario({
        name => "Having paid his dues, Haisuli tries again and succeeds. He is so happy! This is cached too.",
        assert_authStatus => 1,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => 1,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => undef,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg => 'Access granted'],
        ],
        httpTransactions => [
            {   request => {},
                response => t::Mocks::api_response_card_authz_ok(),
            },
        ],
    });

    $ohs = t::Mocks::OpeningHours::createAlwaysClosed();
    ok(SSAuthenticator::OpeningHours::_persistOpeningHoursToDB($ohs), "Given the OpeningHours: Always closed");

    scenario({
        name => "Haisuli frequents the self-service resource again, but a lighting bolt had fried the main router in the building. Haisuli is fortunately cached, but the cached OpeningHours show the library is closed.",
        assert_authStatus => 0,
        assert_cardAuthStatus => $SSAuthenticator::ERR_CLOSED,
        assert_cardCached => undef,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => 1,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
        ],
        httpTransactions => [
            {   request => {},
                response => t::Mocks::api_response_server_error(),
            },
        ],
    });

    $ohs = t::Mocks::OpeningHours::createAlwaysOpen();
    ok(SSAuthenticator::OpeningHours::_persistOpeningHoursToDB($ohs), "Given the OpeningHours: Always open");

    scenario({
        name => "Haisuli waits behind the door for the library to open. Toveri is still in offline-mode. Haisuli is fortunately cached and we can let him in.",
        assert_authStatus => 1,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => undef,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => 1,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg => 'Access granted.+I [Rr]emembered you!'],
        ],
        httpTransactions => [
            {   request => {},
                response => t::Mocks::api_response_server_error(),
            },
        ],
    });

    scenario({
        name => "Haisuli tries to access the Library, but the Librarians haven't enabled 'koha-plugin-self-service'.",
        assert_authStatus => 1,
        assert_cardAuthStatus => $SSAuthenticator::OK,
        assert_cardCached => undef,
        assert_cardCacheFlushed => undef,
        assert_cardCacheUsed => 1,
        assert_oledMsgs => [
            [showBarcodePostReadMsg => 'Please wait'],
            [showAccessMsg => 'Access granted.+I [Rr]emembered you!'],
        ],
        httpTransactions => [
            {   request => {},
                response => HTTP::Response->parse(t::Mocks::HTTPResponses::PageNotFound()),
            },
        ],
    });

    t::Examples::rmConfig();
    t::Examples::rmCacheDB();
}




done_testing();
