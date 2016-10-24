#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

use Modern::Perl;

use Test::More;
use Test::MockModule;

use HTTP::Response;

use t::Examples;
use SSAuthenticator;
use JSON;

my %users = (
    '1A00MÖRKÖ'       => {permission => 'false', error => 'Koha::Exception::UnknownObject', httpCode => 404, authStatus => SSAuthenticator::ERR_BADCARD},
    '1A00PIKKUMYY'    => {permission => 'false', error => 'Koha::Exception::SelfService::PermissionRevoked', httpCode => 200, authStatus => SSAuthenticator::ERR_REVOKED},
    '1A00HAISULI'     => {permission => 'false', error => 'Koha::Exception::FeatureUnavailable', httpCode => 501, authStatus => SSAuthenticator::ERR_ERR},
);

sub createCacheDB {
    open(my $fh, ">", "patron.db");
    print $fh "";
    close $fh;
}

sub rmCacheDB {
    unlink "patron.db";
}

subtest "Can use library", \&testLibraryUsagePermission;
sub testLibraryUsagePermission {
    my ($module);

    createCacheDB();
    t::Examples::writeDefaultConf();

    $module = Test::MockModule->new('SSAuthenticator');
    $module->mock('getDB', \&getDB);

    $module = Test::MockModule->new('SSAuthenticator');
    $module->mock('getApiResponse', \&getApiResponseMock);

    foreach my $barcode (keys %users) {
        my ($authStatus, $cacheUsed) = SSAuthenticator::isAuthorized($barcode);
        is($authStatus, $users{$barcode}->{authStatus},
           "$barcode permission to use library");

        is(SSAuthenticator::isAuthorizedCache($barcode), $users{$barcode}->{authStatus},
           "$barcode auth status cached");

        is($cacheUsed, 0,
           "Cache not used");
    }

    t::Examples::rmConfig();
    rmCacheDB();
}


subtest "Cache access authorization", \&testCacheAccess;
sub testCacheAccess {
    createCacheDB();
    t::Examples::writeDefaultConf();

    my $module = Test::MockModule->new('SSAuthenticator');
    $module->mock('getDB', \&getDB);
    
    SSAuthenticator::updateCache("1A00TEST", SSAuthenticator::OK);

    is(SSAuthenticator::isAuthorizedCache("1A00TEST"), SSAuthenticator::OK,
       "Authorized from cache");

    # Clean before testing
    SSAuthenticator::getDB()->delete("1A00TEST");
    SSAuthenticator::updateCache("1A00TEST", SSAuthenticator::ERR_ERR);

    is(SSAuthenticator::isAuthorizedCache("1A00TEST"), SSAuthenticator::ERR_ERR,
       "Not authorized from cache");

    rmCacheDB();
    t::Examples::rmConfig();
}



done_testing();



sub getDB {
    my $CARDNUMBER_FILE = "patron.db";
    my $CARDNUMBER_DB = DBM::Deep->new($CARDNUMBER_FILE);
    return $CARDNUMBER_DB;
}

sub getApiResponseMock {
    my ($cardNumber) = @_;

    my $jsonBody = JSON::encode_json({
        error => $users{$cardNumber}->{error},
        permission => $users{$cardNumber}->{permission},
    });

    my $response = HTTP::Response->new(
        $users{$cardNumber}->{httpCode},
        undef,
        undef,
        $jsonBody,
    );

    return $response;
}
