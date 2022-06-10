#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

use Modern::Perl;

use Test::More tests => 3;
use Test::MockModule;
use SSAuthenticator;
use SSAuthenticator::API;

use t::Mocks;
use t::Mocks::HTTPResponses;

use Storable;

subtest "Make signature", \&testSignatureMaking;
sub testSignatureMaking {
    my $method = "get";
    my $userid = "testId";
    my $headerXKohaDate = DateTime->new(
	year       => 2015,
	month      => 4,
	day        => 15,
	hour       => 4,
	minute     => 20,
	second     => 13,
	);
    my $apiKey = "F12312mp3K123kljkar";
    is(SSAuthenticator::API::_makeSignature($method, $userid, $headerXKohaDate, $apiKey),
       "f74a83dad4233747b29ec575482f8e8921dcfc0b4e0891c5792d4a78078ccf8d",
       "signature making");
}

subtest "Make authentication headers", \&testprepareAuthenticationHeaders;
sub testprepareAuthenticationHeaders {
    my $conf = SSAuthenticator::Config::getConfig();
    my $method = "get";
    my $userid = "testId";
    my $apiKey = "F12312mp3K123kljkar";
    my $headerXKohaDate = DateTime->new(
        year       => 2015,
        month      => 4,
        day        => 15,
        hour       => 4,
        minute     => 20,
        second     => 13,
    );

    $conf->param("ApiUserName", $userid);
    $conf->param("ApiKey", $apiKey);

    my $authHeaders = SSAuthenticator::API::_prepareAuthenticationHeaders(
        $headerXKohaDate,
        $method,
    );

    is($authHeaders->[0], 'X-Koha-Date',   "date header present");
    is($authHeaders->[1], DateTime::Format::HTTP->format_datetime($headerXKohaDate), "date header well formed");
    is($authHeaders->[2], 'Authorization', "authorization header present");
    is($authHeaders->[3], "Koha " . $userid . ":" . "d8d2002376cf7ba80d3c694a348f3fa0d91a592c502a70227c7aa90f7c558ad4", "authorization header well formed");
}

subtest "API Response Handling", \&testAPIResponseHandling;
sub testAPIResponseHandling {
    my $cardNumber = '167A006007';
    my $ssAuthenticatorApiMockModule = Test::MockModule->new('SSAuthenticator::API');
    $ssAuthenticatorApiMockModule->mock('_do_api_request', \&t::Mocks::_do_api_request_check_against_list);

    subtest "SSStatus 400", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::SSStatus400)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getApiResponse($cardNumber);
        is($body->{errors}->[0]->{path}, '/password',   'Body ok');
        is($status,       400,           'Status 400');
        is($permission,   0,             'Permission denied');
        is(SSAuthenticator::isAuthorizedApi($cardNumber), $SSAuthenticator::ERR_SERVER);
    };
    subtest "SSStatus 401 unauthenticated", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::SSStatus401Unauthenticated)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getApiResponse($cardNumber);
        like($body->{error}, qr/Cannot find/, 'Body ok');
        is($status,       401,           'Status 401');
        is($permission,   0,             'Permission denied');
        is(SSAuthenticator::isAuthorizedApi($cardNumber), $SSAuthenticator::ERR_API_AUTH);
    };
    subtest "SSStatus 401 unauthenticated", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::SSStatus404PageNotFound)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getApiResponse($cardNumber);
        like($response->content, qr/title/, 'Body ok');
        is($status,       404,           'Status 404');
        is($permission,   0,             'Permission denied');
        is(SSAuthenticator::isAuthorizedApi($cardNumber), $SSAuthenticator::ERR_SERVER);
    };
    subtest "SSStatus 200 OK", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::SSStatus200True)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getApiResponse($cardNumber);
        is($body->{permission}, 1,       'Body ok');
        is($status,       200,           'Status 200');
        is($permission,   1,             'Permission granted');
        is(SSAuthenticator::isAuthorizedApi($cardNumber), $SSAuthenticator::OK);
    };
    subtest "SSStatus 200 False", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::SSStatus200False)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getApiResponse($cardNumber);
        is($body->{permission}, 0,       'Body ok');
        is($status,       200,           'Status 200');
        is($permission,   0,             'Permission denied');
        is(SSAuthenticator::isAuthorizedApi($cardNumber), $SSAuthenticator::ERR_NAUGHTY);
    };
    subtest "PIN auth 201", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::AuthPin201OK)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getPINResponse($cardNumber, '1234');
        is($body->{sessionid}, '5880',   'Body ok');
        is($status,       201,           'Status 200');
        is($permission,   1,             'Permission granted');
        is(SSAuthenticator::isAuthorizedApiPIN($cardNumber, '1234'), $SSAuthenticator::OK);
    };
    subtest "PIN auth 401", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::AuthPin201Wrong)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getPINResponse($cardNumber, '1234');
        is($body->{error}, 'Login failed.', 'Body ok');
        is($status,       401,           'Status 200');
        is($permission,   0,             'Permission denied');
        is(SSAuthenticator::isAuthorizedApiPIN($cardNumber, '1234'), $SSAuthenticator::ERR_PINBAD);
    };
    subtest "ClientWarningConnectionRefused card endpoint", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::ClientWarningConnectionRefused)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getApiResponse($cardNumber);
        like($body, qr/Connection refused/, 'Body ok');
        is($status,       510,           'Status 510');
        is($permission,   0,             'Permission denied');
        is(SSAuthenticator::isAuthorizedApi($cardNumber), $SSAuthenticator::ERR_SERVERCONN);
    };
    subtest "ClientWarningConnectionTimeout card endpoint", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::ClientWarningConnectionTimeout)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getApiResponse($cardNumber);
        like($body, qr/Connection timed out/, 'Body ok');
        is($status,       510,           'Status 510');
        is($permission,   0,             'Permission denied');
        is(SSAuthenticator::isAuthorizedApi($cardNumber), $SSAuthenticator::ERR_SERVERCONN);
    };
    subtest "ClientWarningConnectionRefused PIN endpoint", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::ClientWarningConnectionRefused)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getPINResponse($cardNumber, '1234');
        like($body, qr/Connection refused/, 'Body ok');
        is($status,       510,           'Status 510');
        is($permission,   0,             'Permission denied');
        is(SSAuthenticator::isAuthorizedApiPIN($cardNumber, '1234'), $SSAuthenticator::ERR_SERVERCONN);
    };
    subtest "ClientWarningConnectionTimeout PIN endpoint", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::ClientWarningConnectionTimeout)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getPINResponse($cardNumber, '1234');
        like($body, qr/Connection timed out/, 'Body ok');
        is($status,       510,           'Status 510');
        is($permission,   0,             'Permission denied');
        is(SSAuthenticator::isAuthorizedApiPIN($cardNumber, '1234'), $SSAuthenticator::ERR_SERVERCONN);
    };
    subtest "PageNotFound card endpoint", sub {
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::PageNotFound)});
        my ($response, $body, $err, $permission, $status) = SSAuthenticator::API::getApiResponse($cardNumber);
        is($body,         '',                    'Body empty');
        is($status,       404,                   'Status 404');
        is($permission,   0,                     'Permission denied');
        is(SSAuthenticator::isAuthorizedApi($cardNumber), $SSAuthenticator::ERR_SERVER);
    };
}

sub _d {
    my $b = Storable::dclone($_[0]);
    return [$_[0], $b];
}