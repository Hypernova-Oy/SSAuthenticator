#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of Authenticator.

use Test::More;
use Test::MockModule;

use SSAuthenticator;

use t::Examples;

#Set the locale to fi_FI to test the expected Finnish language translations
use POSIX;
POSIX::setlocale (LC_ALL, "fi_FI.UTF-8");

my $defaultConfTempFile = t::Examples::writeDefaultConf();
SSAuthenticator::setConfigFile($defaultConfTempFile->filename());

subtest "Translations work", \&translationsWork;
sub translationsWork {

    my $agentText;

    my $module = Test::MockModule->new('SSAuthenticator');
    $module->mock('showOLEDMsg', sub {
        $agentText = shift; #Leak the translated message
    });

    SSAuthenticator::grantAccess();
    is($agentText, 'Paasy sallittu');

    SSAuthenticator::denyAccess();
    is($agentText, 'Paasy evatty');

}

t::Examples::rmConfig();

done_testing();
