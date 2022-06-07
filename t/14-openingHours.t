#!/usr/bin/perl

# Copyright (C) 2022 Hypernova Oy
#
# This file is part of SSAuthenticator.
#

use Modern::Perl;

use Test::More tests => 3;
use Test::MockModule;
use SSAuthenticator;
use SSAuthenticator::API;
use SSAuthenticator::OpeningHours;

use t::Mocks;
use t::Mocks::HTTPResponses;
use t::Mocks::OpeningHours;

use Storable;

subtest "OpeningHours API Response Handling", \&testAPIResponseHandling;
sub testAPIResponseHandling {
    my $ssAuthenticatorApiMockModule = Test::MockModule->new('SSAuthenticator::API');
    $ssAuthenticatorApiMockModule->mock('_do_api_request', \&t::Mocks::_do_api_request_check_against_list);

    subtest "SSStatus 200", sub {
        plan tests => 4;
        $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::OpeningHours200)});
        my ($response, $body, $err, $status) = SSAuthenticator::API::getOpeningHours();
        my $oh = SSAuthenticator::OpeningHours->new($body);
        is($oh->start(0), '06:47',   'Mon Start');
        is($oh->end(0),   '11:47',   'Mon End');
        is($status,       200,       'Status 200');
    };
}

subtest "OpeningHours persistence", \&testPersistence;
sub testPersistence {
    plan tests => 4;
    my $ssAuthenticatorApiMockModule = Test::MockModule->new('SSAuthenticator::API');
    $ssAuthenticatorApiMockModule->mock('_do_api_request', \&t::Mocks::_do_api_request_check_against_list);

    subtest "Given some OpeningHours in the DB", sub {
        plan tests => 3;

        my $ohs = t::Mocks::OpeningHours::createAlwaysOpen();
        ok(SSAuthenticator::OpeningHours::_persistOpeningHoursToDB($ohs), "_persistOpeningHoursToDB()");

        my $oh = SSAuthenticator::OpeningHours::loadOpeningHoursFromDB();
        is($oh->start(0), $ohs->[0]->[0],   'persistence actually worked - Mon Start');
        is($oh->end(0),   $ohs->[0]->[1],   'persistence actually worked - Mon End');
    };

    $t::Mocks::mock_httpTransactions_list = _d({response => HTTP::Response->parse(t::Mocks::HTTPResponses::OpeningHours200)});
    ok(SSAuthenticator::OpeningHours::synchronize(), "When OpeningHours have been synchronized");

    subtest "Then the persisted OpeningHours have changed", sub {
        plan tests => 3;

        ok(my $oh = SSAuthenticator::OpeningHours::loadOpeningHoursFromDB(), "Loaded persisted OpeningHours");
        is($oh->start(0), '06:47',   'Mon Start');
        is($oh->end(0),   '11:47',   'Mon End');
    };
}

subtest "OpeningHours isOpen", \&testOpeningHoursIsOpen;
sub testOpeningHoursIsOpen {
    plan tests => 4;
    my ($oh, $ohs);

    $ohs = t::Mocks::OpeningHours::createAlwaysOpen();
    ok(SSAuthenticator::OpeningHours::_persistOpeningHoursToDB($ohs), "Persist always open opening hours");

    $oh = SSAuthenticator::OpeningHours::loadOpeningHoursFromDB();
    ok($oh->isOpen(), "Library is open");

    $ohs = t::Mocks::OpeningHours::createAlwaysClosed();
    ok(SSAuthenticator::OpeningHours::_persistOpeningHoursToDB($ohs), "Persist always closed opening hours");

    $oh = SSAuthenticator::OpeningHours::loadOpeningHoursFromDB();
    ok(not($oh->isOpen()), "Library is NOT open");
}

sub _d {
    my $b = Storable::dclone($_[0]);
    return [$_[0], $b];
}
