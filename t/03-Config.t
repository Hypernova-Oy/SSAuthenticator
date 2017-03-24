#!/usr/bin/perl
#
# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;

use SSAuthenticator;
use SSAuthenticator::Config;



subtest "Default config passes", \&defaultConfig;
sub defaultConfig {

    my $confFile = newConfig();
    ok(SSAuthenticator::Config::getConfig(), "Default config validates");

}

subtest "Config errors", \&configErrors;
sub configErrors {

    newConfig("ConnectionTimeout no-string-allowed");
    eval {SSAuthenticator::Config::getConfig()};
    ok($@, "not string as timeout value");

    newConfig("MailboxDir /awneofnsldfkwainvelni23pnrfw9n/not-a-good-path-to-existing-dir");
    eval {SSAuthenticator::Config::getConfig()};
    ok($@, "MailboxDir is not ok");
}


done_testing;


##Important to keep references to $confTempFile or it will be garbage collected.
my $confTempFile;
sub newConfig {
    my (@overloads) = @_;

    if ($confTempFile) {
        $confTempFile->DESTROY();
        SSAuthenticator::Config::unloadConfig();
    }

    $confTempFile = t::Examples::writeConf(@overloads);
    SSAuthenticator::Config::setConfigFile($confTempFile->filename());
}
