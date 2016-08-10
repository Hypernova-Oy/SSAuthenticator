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
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package Authenticator;

our $VERSION = "0.10";

=encoding utf8

=head1 NAME

    Authenticator - library access control system

=head1 DESCRIPTION

    Authenticator is program that controls access to a library
    using Koha instance's REST API and its local cache.

=cut
    
use Modern::Perl;
use Config::Simple;
use DBM::Deep;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;
use Sys::SigAction qw( timeout_call );
use Time::HiRes;

use GPIO;

use constant {
    GREEN => 18,
    BLUE => 15,
    RED => 14,
    DOOR => 23,
    BUZZER => 24,
};

my $CARDNUMBER_FILE = "/var/cache/authenticator/patron.db";
my $CARDNUMBER_DB = DBM::Deep->new($CARDNUMBER_FILE);
my $CONFIG_FILE = "/etc/authenticator/daemon.conf";
my $CONFIG = new Config::Simple($CONFIG_FILE)
    || die Config::Simple->error();

sub getDB {
    return $CARDNUMBER_DB;
}

sub isAuthorized {
    my ($cardNumber) = @_;
    return isLibraryOpen() && canUseLibrary($cardNumber);
}

sub canUseLibrary {
    my ($cardNumber) = @_;

    my $authorized = 0;
    
    timeout_call(
	    getTimeout(),
	sub {$authorized = isAuthorizedApi($cardNumber)});

    # Check if we got response from REST API
    if (defined $authorized) {
	return $authorized;
    } else {
	$authorized = isAuthorizedCache($cardNumber);
    }

    return $authorized;
}

sub isAuthorizedApi {
    my ($cardNumber) = @_;

    my %responseValues = getApiResponseValues($cardNumber);

    if (exists $responseValues{permission}) {
	return $responseValues{permission} eq 'true' ? 1 : 0;
    } else {
	return undef;
    }
}

sub getApiResponseValues {
    my ($cardNumber) = @_;

    my $response = getApiResponse($cardNumber);
    my $responseContent = $response->decoded_content;

    if ($responseContent) {
	return decode_json $response->decoded_content;
    } else {
	return ();
    }
}

sub getApiResponse {
    my ($cardNumber) = @_;

    # TODO: when API is ready include $cardNumber to URL
    my $requestUrl = $CONFIG->param('ApiBaseUrl') . "/borrowers/status";
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request(GET $requestUrl);
    
    return $response;
}

sub isLibraryOpen {
    my $libraryName = $CONFIG->param('LibraryName');
    # TODO:
    # Request data from API and fallback to cache if not possible
    return 1;
}

sub isAuthorizedCache {
    my ($cardNumber) = @_;
    if ($CARDNUMBER_DB->exists($cardNumber)) {
	my $patronInfo = $CARDNUMBER_DB->get($cardNumber);
	return $$patronInfo{access};
    } else {
	return 0;
    }
}

sub grantAccess {
    my $door = GPIO->new(DOOR);
    $door->turnOn();

    my $led = GPIO->new(GREEN);
    $led->turnOn();

    my $buzzer = GPIO->new(BUZZER);
    buzz($buzzer);

    sleep 1;
    $led->turnOff();
    $door->turnOff();
    $buzzer->turnOff();

    return 1;
}

sub buzz {
    my ($buzzer) = @_;
    
    my $sleepTime = 0.020;
    for (my $i = 0; $i <= 500; $i++) {
	$buzzer->turnOn();
	Time::HiRes::usleep($sleepTime);
	$buzzer->turnOff();
	Time::HiRes::usleep($sleepTime);
    }
}

sub denyAccess {
    my $led = GPIO->new(RED);
    $led->turnOn();
    sleep 1;
    $led->turnOff();
    return 0;
}

sub getTimeout() {
    my $defaultTimeout = 3;

    if ($CONFIG->param('ConnectionTimeout')) {
	return $CONFIG->param('ConnectionTimeout');
    } else {
	return $defaultTimeout;
    }
}

sub isConfigValid() {
    if (!$CONFIG->param("ApiBaseUrl")) {
	print "ApiUrl not defined in daemon.conf";
	return 0;
    }

    if (!$CONFIG->param("LibraryName")) {
	say "Libary name not defined in daemon.conf";
	return 0;
    }

    my $timeout = $CONFIG->param("ConnectionTimeout");
    if (!$timeout) {
	return 1;
    } elsif (!($timeout =~ /\d+/)) {
	say "Timeout value is invalid. Valid value is a integer.";
	return 0;
    }

    return 1;
}

sub updateCache {
    my ($cardNumber, $access) = @_;
    $CARDNUMBER_DB->put($cardNumber, {time => "2015",
				      access => $access});
}

sub removeFromCache {
    my ($cardNumber) = @_;
    $CARDNUMBER_DB->delete($cardNumber);
}

sub freeSpaceInCache {
    
}

sub controlAccess {
    my ($cardNumber) = @_;
    if (isAuthorized($cardNumber)) {
	grantAccess();
        updateCache($cardNumber, 1);
    } else {
	denyAccess();
        updateCache($cardNumber, 0);
    }
}


sub main {
    if (!isConfigValid()) {
	exit 1;
    }

    my $PORT = "/dev/barcodescanner";

    #local $/ = "\r";
    open(DEVICE, "<", $PORT);
    while ($_ = <DEVICE>) {
	my $cardNumber = $_;
	#my $cardNumber = substr($_, 0, length($_) -1);
	controlAccess($cardNumber);

	# Empty buffer
	close DEVICE;
	open(DEVICE, "<", $PORT);
    }

}

__PACKAGE__->main() unless caller;

1;
