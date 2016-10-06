#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

use Test::More tests => 1;
use Test::MockModule;

use SSAuthenticator;

subtest "Right timeout value is returned", \&testTimeoutValues;
sub testTimeoutValues {
    my $module = Test::MockModule->new('SSAuthenticator');
    $module->mock('getConfig', \&getConfig);

    open(my $fh, ">", "daemon.conf");
    say $fh "ApiUserName testUser";
    close $fh;

    is(SSAuthenticator::getTimeout(), 3,
       "default value when no explicit value in configuration file");
    rmConfig();

    open(my $fh, ">", "daemon.conf");
    say $fh "ConnectionTimeout 2404";
    close $fh;
    
    is(SSAuthenticator::getTimeout(), 2.404,
       "floats work & reading from config file");
    rmConfig();
}

sub getConfig {
    my $configFile = "daemon.conf";
    my $config = new Config::Simple($configFile)
	|| die Config::Simple->error(), ".\n",
	"Please check the syntax in daemon.conf.";
    return $config;
}

sub rmConfig {
    unlink "daemon.conf";
}
