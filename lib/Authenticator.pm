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

our $VERSION = "0.11";

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
use Sys::Syslog qw(:standard :macros);
use Systemd::Daemon qw{ -soft notify };

use GPIO;
use API;
use AutoConfigurer;
use Buzzer;

use constant {
    GREEN => 22,
    BLUE => 27,
    RED => 17,
    DOOR => 23,
    BUZZER => 18,
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
	    syslog(LOG_ERR, "REST API is not working as expected. ".
		"Maybe it is misconfigured?");
	}

	return ();
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
    my $greenLed = GPIO->new(GREEN);

    $door->turnOn();
    $greenLed->turnOn();

    playAccessBuzz();

    $greenLed->turnOff();
    $door->turnOff();
}

sub playAccessBuzz {
    say "playng acces";
    my $buzzer = Buzzer->new(BUZZER);
    $buzzer->buzz(3050, 0.6);
}

sub playDenyAccessBuzz {
    say "playing deny";
    my $buzzer = Buzzer->new(BUZZER);
    $buzzer->beepWithPauses(3, 0.2, 0.2);
}

sub denyAccess {
    my $redLed = GPIO->new(RED);

    $redLed->turnOn();
    playDenyAccessBuzz();
    $redLed->turnOff();
}

sub getTimeout() {
    my $defaultTimeout = 3000;

    if (getConfig()->param('ConnectionTimeout')) {
	return millisecs2secs(getConfig()->param('ConnectionTimeout'));
    } else {
	return millisecs2secs($defaultTimeout);
    }
}

sub millisecs2secs {
    my ($milliseconds) = @_;
    return $milliseconds / 1000;
}

sub isConfigValid() {
    my $returnValue = 1;

    my @params = ('ApiBaseUrl', 'LibraryName', 'ApiUserName', 'ApiKey');
    foreach my $param (@params) {
	if (!getConfig()->param($param)) {
	    notifyAboutError("$param not defined in daemon.conf");
	    $returnValue = 0;
	}
    }

    my $timeout = getConfig()->param("ConnectionTimeout");
    if (!$timeout) {
	return $returnValue;
    } elsif (!($timeout =~ /\d+/)) {
	my $reason = "ConnectionTimeout value is invalid. " .
	    "Valid value is an integer.";
	notifyAboutError($reason);
	$returnValue = 0;
    } elsif ($timeout > 30000) {
	my $reason = "ConnectionTimeout value is too big. Max 30000 ms";
	notifyAboutError($reason);
	$returnValue = 0;
    }

    return $returnValue;
}

sub notifyAboutError {
    my ($reason) = @_;
    say $reason;
    syslog(LOG_ERR, $reason);
}

sub updateCache {
    my ($cardNumber, $access) = @_;
    getDB()->put($cardNumber, {time => localtime,
				      access => $access});
}

sub removeFromCache {
    my ($cardNumber) = @_;
    getDB()->delete($cardNumber);
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

sub exitWithReason {
    my ($reason) = @_;
    notifyAboutError($reason);
    exit(1);
}

sub getBarcodeSeparator {
    if (getConfig()->param('CarriageReturnAsSeparator') eq "true") {
	syslog(LOG_INFO, "using \\r as barcode separator");
	return "\r";
    } else {
	syslog(LOG_INFO, "using \\n as barcode separator");
	return "\n";
    }
}

sub configureBarcodeScanner {
    my $configurer = AutoConfigurer->new;
    $configurer->configure();
    syslog(LOG_INFO, "Barcode scanner configured");
    say "Barcode scanner configured";
}

sub main {
    if (!isConfigValid()) {
	exitWithReason("/etc/authenticator/daemon.conf is invalid");
    }

    configureBarcodeScanner();

    local $/ = getBarcodeSeparator();

    while (1) {
	notify(WATCHDOG => 1);
	open(my $device, "<", "/dev/barcodescanner")
	    || exitWithReason("No barcode reader attached");
	my $cardNumber = "";
	if (timeout_call(
		0.1,
		sub {$cardNumber = <$device>})) {
	    next;
	}
	chomp($cardNumber);

	controlAccess($cardNumber);

	close $device; # Clears buffer
    }

}


__PACKAGE__->main() unless caller;

1;
