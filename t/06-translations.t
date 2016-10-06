#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of Authenticator.

use Test::More;
use Test::MockModule;

use SSAuthenticator;
use Locale::TextDomain qw (SSAuthenticator ./ /usr/share/locale /usr/local/share/locale); #Look from cwd or system defaults. This is needed for tests to pass during build
use Locale::Messages qw (LC_MESSAGES);
use POSIX;
POSIX::setlocale (LC_MESSAGES, "fi_FI.utf-8");

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

done_testing();
