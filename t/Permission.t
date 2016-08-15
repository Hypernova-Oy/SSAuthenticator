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

use Test::More tests => 4;
use Test::MockModule;

use Authenticator;
use JSON;

my %users = (morko => {access => 'false', barcode => '1A00MÖRKÖ'},
	     myy => {access => 'false', barcode => '1A00PIKKU'},
	     haisuli => {access => 'false', barcode => '1A00HAISU'},
	     niisku => {access => 'true', barcode => '1A00NIISKU'}
    );


sub createConfig {
    open(my $fh, ">", "daemon.conf");
    say $fh "ApiBaseUrl http://localhost-api/api/v1";
    say $fh "LibraryName MyTestLibrary";
    say $fh "ConnectionTimeout 3";
    say $fh "ApiKey testAPikey";
    say $fh "ApiUserName testUser";
    close $fh;
}

sub createCacheDB {
    open(my $fh, ">", "patron.db");
    print $fh "";
    close $fh;
}

sub rmCacheDB {
    unlink "patron.db";
}

sub rmConfig {
    unlink "daemon.conf";
}

subtest "Can use library", \&testLibraryUsagePermission;
sub testLibraryUsagePermission {
    createCacheDB();
    createConfig();

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getConfig', \&getConfig);

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getDB', \&getDB);

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getApiResponseValues', \&getApiResponseValuesMock);

    foreach $user (keys %users) {
	my $access = $users{$user}{access} eq "true" ? 1 : 0;
	is(Authenticator::canUseLibrary($users{$user}{barcode}), $access,
	   "$user permission to use library");
    }

    rmConfig();
    rmCacheDB();
}

subtest "Authorized to access the build now", \&testApiAccess;
sub testApiAccess {
    createCacheDB();
    createConfig();

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getConfig', \&getConfig);

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getDB', \&getDB);

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getApiResponseValues', \&getApiResponseValuesMock);

    foreach $user (keys %users) {
	my $access = $users{$user}{access} eq "true" ? 1 : 0;
	is(Authenticator::isAuthorized($users{$user}{barcode}), $access,
	   "$user can enter the building");
    }

    rmConfig();
    rmCacheDB();
}


subtest "Cache access authorization", \&testCacheAccess;
sub testCacheAccess {
    createCacheDB();
    createConfig();

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getConfig', \&getConfig);

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getDB', \&getDB);
    
    Authenticator::updateCache("1A00TEST", 1);

    ok(Authenticator::isAuthorizedCache("1A00TEST"),
       "Authorized from cache");

    # Clean before testing
    Authenticator::getDB()->delete("1A00TEST");
    Authenticator::updateCache("1A00TEST", 0);

    ok(!Authenticator::isAuthorizedCache("1A00TEST"),
       "Not authorized from cache");

    rmCacheDB();
    rmConfig();
}

# Test cache primitive operations.
subtest "Cache updating", \&testCacheUpdating;
sub testCacheUpdating {
    createConfig();
    createCacheDB(); 

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getConfig', \&getConfig);
    
    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getDB', \&getDB);
       
    my $module = Test::MockModule->new('Authenticator');
    $module->mock('isAuthorized', sub {
	return 1;
		  });

    Authenticator::controlAccess("1A00TEST");
    my $entry = Authenticator::getDB()->get("1A00TEST");
    ok($$entry{access},
       "Put to cache when permission and access granted");

    $module->mock('isAuthorized', sub {
	return 0;
		  });

    Authenticator::controlAccess("1A00TEST");

    my $entry = Authenticator::getDB()->get("1A00TEST");

    ok(!$$entry{access},
       "Updated cache value to denied");

    rmConfig();
    rmCacheDB();
}

sub getDB {
    my $CARDNUMBER_FILE = "patron.db";
    my $CARDNUMBER_DB = DBM::Deep->new($CARDNUMBER_FILE);
    return $CARDNUMBER_DB;
}

sub getConfig {
    my $configFile = "daemon.conf";
    my $config = new Config::Simple($configFile)
	|| die Config::Simple->error(), ".\n",
	"Please check the syntax in daemon.conf.";
    return $config;
}


sub getApiResponseValuesMock {
    my ($cardNumber) = @_;

    my $permitted = 0;
    foreach $user (keys %users) {
	if ($users{$user}{barcode} eq $cardNumber) {
	    $permitted = $users{$user}{access} eq "true" ? 1 : 0;
	}
    }

    my %responseContent = ();
    
    if ($permitted) {
	$responseContent{permission} = "true";
    } else {
	$responseContent{permission} = "false";
    }

    return \%responseContent;
}
