#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of Authenticator.

use Test::More;
use Test::MockModule;

use t::Examples;

use SSAuthenticator;
my $defaultConfTempFile = t::Examples::writeDefaultConf();
SSAuthenticator::setConfigFile($defaultConfTempFile->filename());

subtest "Translations fi_FI", \&translationsFi_FI;
sub translationsFi_FI {
    #Set the locale to fi_FI to test the expected Finnish language translations
    SSAuthenticator::changeLanguage('fi_FI', 'UTF-8');
    my $arr;

    $arr = SSAuthenticator::_getOLEDMsg( SSAuthenticator::OK, 0 );
    is($arr->[0],
       'Paasy sallittu');

    $arr = SSAuthenticator::_getOLEDMsg( SSAuthenticator::ERR_REVOKED, 0 );
    is($arr->[0],
       'Paasy evatty');
}

subtest "Translations en_GB", \&translationsEn_GB;
sub translationsEn_GB {
    #Set the locale to english
    SSAuthenticator::changeLanguage('en_GB', 'UTF-8');
    my $arr;

    $arr = SSAuthenticator::_getOLEDMsg( SSAuthenticator::OK, 0 );
    is($arr->[0],
       'Access granted');

    $arr = SSAuthenticator::_getOLEDMsg( SSAuthenticator::ERR_REVOKED, 0 );
    is($arr->[0],
       'Access denied');
}

t::Examples::rmConfig();

done_testing();
