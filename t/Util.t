#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of Authenticator.
#
# Authenticator is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Authenticator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Authenticator.  If not, see <http://www.gnu.org/licenses/>.

use Test::More tests => 1;
use Test::MockModule;

use Authenticator;

subtest "Right timeout value is returned", \&testTimeoutValues;
sub testTimeoutValues {
    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getConfig', \&getConfig);

    open(my $fh, ">", "daemon.conf");
    say $fh "ApiUserName testUser";
    close $fh;

    is(Authenticator::getTimeout(), 3,
       "default value when no explicit value in configuration file");
    rmConfig();

    open(my $fh, ">", "daemon.conf");
    say $fh "ConnectionTimeout 2404";
    close $fh;
    
    is(Authenticator::getTimeout(), 2.404,
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
