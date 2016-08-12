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
use API;

use constant {
    GREEN => 18,
    BLUE => 15,
    RED => 14,
    DOOR => 23,
    BUZZER => 24,
};

sub getDB {
    my $CARDNUMBER_FILE = "/var/cache/authenticator/patron.db";
    my $CARDNUMBER_DB = DBM::Deep->new($CARDNUMBER_FILE);
    return $CARDNUMBER_DB;
}

sub getConfig {
    my $configFile = "/etc/authenticator/daemon.conf";
    my $config = new Config::Simple($configFile)
	|| die Config::Simple->error(), ".\n",
	"Please check the syntax in /etc/authenticator/daemon.conf.";
    return $config;
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

    my $responseValues = getApiResponseValues($cardNumber);

    if (exists $responseValues->{permission}) {
    	return $responseValues->{permission} eq 'true' ? 1 : 0;
    } else {
    	return undef;
    }
}

sub getApiResponseValues {
    my ($cardNumber) = @_;

    my $response = getApiResponse($cardNumber);

    if ($response->is_success) {
	return decodeContent($response);
    } else {
	if ($response->code eq '404') {
	    return {permission => 'false'};
	} else {
	    return ();
	}
    }
}

sub decodeContent {
    my ($response) = @_;
    
    my $responseContent = $response->decoded_content;

    if ($responseContent) {
	return decode_json $responseContent;
    } else {
	return ();
    }
}

sub getApiResponse {
    my ($cardNumber) = @_;

    my $requestUrl = getConfig()->param('ApiBaseUrl') . "/borrowers/ssstatus";

    my $ua = LWP::UserAgent->new;
    my $userId = getConfig()->param("ApiUserName");
    my $apiKey = getConfig()->param("ApiKey");
    my $authHeaders = API::prepareAuthenticationHeaders($userId,
							undef,
							"GET",
							$apiKey);

    my $date = $authHeaders->{'X-Koha-Date'};
    my $authorization = $authHeaders->{'Authorization'};

    my $request = HTTP::Request->new(GET => $requestUrl);
    $request->header('X-Koha-Date' => $date);
    $request->header('Authorization' => $authorization);
    $request->header('Content-Type' => 'application/x-www-form-urlencoded');
    $request->header('Content-Length' => length('cardnumber='.$cardNumber));
    $request->content('cardnumber='.$cardNumber);

    my $response = $ua->request($request);

    return $response;
}

sub isLibraryOpen {
    my $libraryName = getConfig()->param('LibraryName');
    # TODO:
    # Request data from API and fallback to cache if not possible
    return 1;
}

sub isAuthorizedCache {
    my ($cardNumber) = @_;
    if (getDB()->exists($cardNumber)) {
	my $patronInfo = getDB()->get($cardNumber);
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

    if (getConfig()->param('ConnectionTimeout')) {
	return getConfig()->param('ConnectionTimeout');
    } else {
	return $defaultTimeout;
    }
}

sub isConfigValid() {
    if (!getConfig()->param("ApiBaseUrl")) {
	print "ApiUrl not defined in daemon.conf";
	return 0;
    }

    if (!getConfig()->param("LibraryName")) {
	say "Libary name not defined in daemon.conf";
	return 0;
    }

    my $timeout = getConfig()->param("ConnectionTimeout");
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
    getDB()->put($cardNumber, {time => "2015",
				      access => $access});
}

sub removeFromCache {
    my ($cardNumber) = @_;
    getDB()->delete($cardNumber);
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
	controlAccess($cardNumber);

	# Empty buffer
	close DEVICE;
	open(DEVICE, "<", $PORT);
    }

}

__PACKAGE__->main() unless caller;

1;
