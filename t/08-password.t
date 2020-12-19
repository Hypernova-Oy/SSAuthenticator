#!/usr/bin/perl
#
# Copyright (C) 2020 Hypernova Oy
#
# This file is part of SSAuthenticator.
#

use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;

use SSAuthenticator;
use SSAuthenticator::Password;
use SSAuthenticator::Transaction;

subtest "Password hashing", \&PasswordHashing;
sub PasswordHashing {
    my $hash = SSAuthenticator::Password::hash_password('1234', 'cardnumber-is-salt');
    ok(length($hash) > 16, 'Password hashed');
    my $hash2 = SSAuthenticator::Password::hash_password('1234', 'cardnumber-is-salt');
    ok(length($hash2) > 16, 'Password hashed again');
    is($hash, $hash2, 'Password hashes match');
}

subtest "PIN cache", \&PINCache;
sub PINCache {
    t::Examples::createCacheDB();
    my $cardnumber = '167A006007';
    my $pin = '1234';
    my $trans = SSAuthenticator::Transaction->new();

    SSAuthenticator::updateCache($trans, $cardnumber, undef, $pin);
    ok($trans->pinCached, 'PIN cached');

    SSAuthenticator::checkPIN_tryCache($trans, $cardnumber, $pin);
    ok($trans->pinAuthnCacheUsed, 'PIN cache used');
    is($trans->pinAuthn, SSAuthenticator::OK, 'PIN cache matches');

    ok(SSAuthenticator::removeFromCache($trans, $cardnumber, undef, 'pin'), 'PIN removed from cache');
    $trans->pinAuthn(0);

    SSAuthenticator::checkPIN_tryCache($trans, $cardnumber, $pin);
    ok(not($trans->pinAuthnCacheUsed), 'PIN cache miss');
    isnt($trans->pinAuthn, SSAuthenticator::OK, 'PIN cache matches');
}
