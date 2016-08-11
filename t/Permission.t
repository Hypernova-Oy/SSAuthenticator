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

subtest "Can use library", \&testLibraryUsagePermission;
sub testLibraryUsagePermission {

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getApiResponseValues', \&getApiResponseValuesMock);

    foreach $user (keys %users) {
	my $access = $users{$user}{access} eq "true" ? 1 : 0;
	is(Authenticator::canUseLibrary($users{$user}{barcode}), $access,
	   "$user permission to use library");
    }
    
}

subtest "Authorized to access the build now", \&testApiAccess;
sub testApiAccess {

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getApiResponseValues', \&getApiResponseValuesMock);

    foreach $user (keys %users) {
	my $access = $users{$user}{access} eq "true" ? 1 : 0;
	is(Authenticator::isAuthorized($users{$user}{barcode}), $access,
	   "$user can enter the building");
    }
}


subtest "Cache access authorization", \&testCacheAccess;
sub testCacheAccess {
    # Clean before testing
    Authenticator::getDB()->delete("1A00TEST");
    Authenticator::updateCache("1A00TEST", 1);

    ok(Authenticator::isAuthorizedCache("1A00TEST"),
       "Authorized from cache");

    # Clean before testing
    Authenticator::getDB()->delete("1A00TEST");
    Authenticator::updateCache("1A00TEST", 0);

    ok(!Authenticator::isAuthorizedCache("1A00TEST"),
       "Not authorized from cache");
}

# Test cache primitive operations.
subtest "Cache updating", \&testCacheUpdating;
sub testCacheUpdating {
    # Clean before testing
    Authenticator::getDB()->delete("1A00TEST");
    
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
