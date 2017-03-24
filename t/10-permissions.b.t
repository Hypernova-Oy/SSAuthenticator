#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

use Modern::Perl;

use Test::More;
use Test::MockModule;

use HTTP::Response;
use JSON;

use t::Examples;
use t::Mocks;
use SSAuthenticator;

SSAuthenticator::openLogger(-1); #Show only fatal errors. If you have problems with these tests. Give parameter 2 for debug logging.

my $respTest = {}; #package variable describing the next scenario
my $updateCacheTriggered = 0; #Keep track if the cache was actually updated. Occasionally return values can be the same as cached values even if no cache was updated, leading to a lot of confusion.
my $ssAuthenticatorApiMockModule;
my $ssAuthenticatorMockModule;

=head2 10-permissions.b.t

Behavioural test case where Haisuli gets different kinds of errors while he tries to fix problems with his user account

=cut



subtest "Scenario: Haisuli tries to access a self-service resource, but has accumulated almost all possible penalties. Now he is trying to redeem himself.", \&haisuliRedemption;
sub haisuliRedemption {
    my ($module, $moduleApi);

    SSAuthenticator::changeLanguage('en_GB', 'UTF-8');

    t::Examples::createCacheDB();
    my $defaultConfTempFile = t::Examples::writeDefaultConf();
    SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

    $ssAuthenticatorApiMockModule = Test::MockModule->new('SSAuthenticator::API');
    $ssAuthenticatorApiMockModule->mock('getApiResponse', \&t::Mocks::getApiResponse);
    $ssAuthenticatorMockModule = Test::MockModule->new('SSAuthenticator');
    $ssAuthenticatorMockModule->mock('updateCache', \&updateCacheMock);

    readBarcode({
        testScenarioName => "Haisuli tries to authenticate, but the server is misconfigured. Since Haisuli is not cached, do not cache strange errors.",
        assert_authStatus      => SSAuthenticator::ERR_NOTCACHED,
        assert_cached          => 0,
        assert_cacheUsed       => 0,
        assert_oledMsgContains => 'network.*error',
        }, {
        httpCode   => 501,
        error      => 'Koha::Exception::FeatureUnavailable',
    });

    readBarcode({
        testScenarioName => "Haisuli tries to authenticate, but he is using a wrong card. We shouldn't cache bad cards.",
        assert_authStatus      => SSAuthenticator::ERR_BADCARD,
        assert_cached          => 0,
        assert_cacheUsed       => 0,
        assert_oledMsgContains => 'not.*recognized',
        }, {
        httpCode   => 404,
        error      => 'Koha::Exception::UnknownObject',
    });

    readBarcode({
        testScenarioName => "Haisuli tries again, but he's borrower category is HAISULI, not a regular user. User error is cached.",
        assert_authStatus      => SSAuthenticator::ERR_BBC,
        assert_cached          => 1,
        assert_cacheUsed       => 0,
        assert_oledMsgContains => 'borrower.*category',
        }, {
        httpCode   => 200,
        error      => 'Koha::Exception::SelfService::BlockedBorrowerCategory',
        permission => 'false',
    });

    readBarcode({
        testScenarioName => "Haisuli tries again after changing his borrower category, but network is down again and the authentication status is returned from the cache :( poor Haisuli.",
        assert_authStatus      => SSAuthenticator::ERR_BBC,
        assert_cached          => 0,
        assert_cacheUsed       => 1,
        assert_oledMsgContains => 'borrower.*category',
        }, {
        httpCode   => 500,
        error      => 'Koha::Exception::StrangeNetworkError',
    });

    readBarcode({
        testScenarioName => "Haisuli tries again, but he has too many fines or something. User error is cached.",
        assert_authStatus      => SSAuthenticator::ERR_NAUGHTY,
        assert_cached          => 1,
        assert_cacheUsed       => 0,
        assert_oledMsgContains => 'circulation.*rules',
        }, {
        httpCode   => 200,
        error      => 'Koha::Exception::SelfService',
        permission => 'false',
    });

    readBarcode({
        testScenarioName => "Haisuli tries again, but the library is closed. User error is NOT cached.",
        assert_authStatus      => SSAuthenticator::ERR_CLOSED,
        assert_cached          => 0,
        assert_cacheUsed       => 0,
        assert_oledMsgContains => 'open at \d\d:\d\d-\d\d:\d\d',
        }, {
        httpCode   => 200,
        error      => 'Koha::Exception::SelfService::OpeningHours',
        permission => 'false',
        startTime  => '09:00',
        endTime    => '21:00',
    });

    readBarcode({
        testScenarioName => "Having paid his dues, Haisuli tries again and succeeds. He is so happy! This is cached too.",
        assert_authStatus      => SSAuthenticator::OK,
        assert_cached          => 1,
        assert_cacheUsed       => 0,
        assert_oledMsgContains => 'access.*granted',
        }, {
        httpCode   => 200,
        permission => 'true',
    });

    readBarcode({
        testScenarioName => "Haisuli frequents the self-service resource again, but a lighting bolt had fried the main router in the building. Haisuli is fortunately cached and we can let him in.",
        assert_authStatus      => SSAuthenticator::OK,
        assert_cached          => 0,
        assert_cacheUsed       => 1,
        assert_oledMsgContains => 'access.*granted',
        }, {
        httpCode   => 500,
        error      => 'Koha::Exception::StrangeNetworkError',
    });


    t::Examples::rmConfig();
    t::Examples::rmCacheDB();
}




done_testing();


sub readBarcode {
    $respTest = shift;
    $t::Mocks::getApiResponse_mockResponse = shift;
    $updateCacheTriggered = 0; #Reset counter for cache updates

    subtest $respTest->{testScenarioName}, sub {
        my ($authStatus, $cacheUsed) = SSAuthenticator::isAuthorized('mockedAndIrrelevant');
        is($authStatus, $respTest->{assert_authStatus},
           "Auth status $authStatus");

        my $msg = SSAuthenticator::_getAccessMsg($authStatus, $cacheUsed);
        $msg = join("\n", @$msg);
        ok($msg =~ /$respTest->{assert_oledMsgContains}/gsmi,
           "Got the expected OLED-message");

        if ($respTest->{assert_cached}) {
            is(SSAuthenticator::isAuthorizedCache('mockedAndIrrelevant'), $respTest->{assert_authStatus},
               "Auth status cached - correct status");
            is($updateCacheTriggered, 1,
               "Mocked subroutine agent confirmed updateCache() triggered");
        }
        else {
            is($updateCacheTriggered, 0,
               "Mocked subroutine agent confirmed updateCache() was not triggered");
        }

        $respTest->{assert_cacheUsed} = undef unless $respTest->{assert_cacheUsed};
        is($cacheUsed, $respTest->{assert_cacheUsed},
           "Cache ".($respTest->{assert_cacheUsed} ? 'used' : 'not used'));
    }
}

sub updateCacheMock {
    my ($cardNumber, $authStatus) = @_;

    $updateCacheTriggered++;
    my $subroutine = $ssAuthenticatorMockModule->original('updateCache');
    return &$subroutine($cardNumber, $authStatus);
}
