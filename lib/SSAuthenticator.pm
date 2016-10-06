#!/usr/bin/perl
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator;

our $VERSION = "0.12";

=encoding utf8

=head1 NAME

    SSAuthenticator - library access control system

=head1 DESCRIPTION

    SSAuthenticator is program that controls access to a library
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
use OLED::Client;

use POSIX;
use Locale::TextDomain qw (SSAuthenticator ./ /usr/share/locale); #Look from cwd or system defaults. This is needed for tests to pass during build
POSIX::setlocale (LC_ALL, ""); #Set the environment locale

use GPIO;
use API;
use AutoConfigurer;

sub getDB {
    my $CARDNUMBER_FILE = "/var/cache/ssauthenticator/patron.db";
    my $CARDNUMBER_DB = DBM::Deep->new($CARDNUMBER_FILE);
    return $CARDNUMBER_DB;
}

my $config;
my $configFile = "/etc/ssauthenticator/daemon.conf";
sub setConfigFile {
    my ($overloadedConfigFile) = @_;
    $configFile = $overloadedConfigFile;
}
sub getConfig {
    $config = new Config::Simple($configFile)
	|| die Config::Simple->error(), ".\n",
	"Please check the syntax in /etc/ssauthenticator/daemon.conf."
        unless $config;
    return $config;
}
sub unloadConfig {
    $config = undef;
}

my $leds = {};
sub initLeds {
    $leds->{red}   = GPIO->new(getConfig()->param('RedLEDPin'));
    $leds->{green} = GPIO->new(getConfig()->param('GreenLEDPin'));
    $leds->{blue}  = GPIO->new(getConfig()->param('BlueLEDPin'));
}
sub ledOn {
    my ($colour) = @_;
    initLeds() unless $leds->{$colour};
    $leds->{$colour}->turnOn();
    return 1;
}
sub ledOff {
    my ($colour) = @_;
    initLeds() unless $leds->{$colour};
    $leds->{$colour}->turnOff();
    return 1;
}

my $doorRelay;
sub initDoor {
    $doorRelay = GPIO->new(getConfig()->param('DoorPin'));
}
sub doorOn {
    initDoor() unless $doorRelay;
    $doorRelay->turnOn();
    return 1;
}
sub doorOff {
    initDoor() unless $doorRelay;
    $doorRelay->turnOff();
    return 1;
}

my $display = OLED::Client->new();
sub showOLEDMsg {
    my ($msg) = @_;
    $display->printRow(0, $msg);
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

    doorOn();
    ledOn('green');

    showOLEDMsg(__"Access granted");
    playAccessBuzz();

    ledOff('green');
    doorOff();
}

sub playAccessBuzz {
    playRTTTL('toveri_access_granted');
}
sub playDenyAccessBuzz {
    playRTTTL('toveri_access_denied');
}
sub playRTTTL {
    my ($song) = @_;
    system('rtttl-player','-p',getConfig()->param('RTTTL-PlayerPin'),'-o',"song-$song");
    if ($? == -1) {
        warn "failed to execute: $!\n";
    }
    elsif ($? & 127) {
        warn sprintf "rtttl-player died with signal %d, %s coredump\n",
        ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    else {
        warn sprintf "rtttl-player exited with value %d\n", $? >> 8;
    };
}

sub denyAccess {
    ledOn('red');
    showOLEDMsg(__"Access denied");
    playDenyAccessBuzz();
    ledOff('red');
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

    my @params = ('ApiBaseUrl', 'LibraryName', 'ApiUserName', 'ApiKey', 'RedLEDPin', 'BlueLEDPin', 'GreenLEDPin', 'DoorPin', 'RTTTL-PlayerPin');
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
    # TODO: Check if param exists before comparing.
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
	exitWithReason("/etc/ssauthenticator/daemon.conf is invalid");
    }

    configureBarcodeScanner();

    local $/ = getBarcodeSeparator();

    while (1) {
	notify(WATCHDOG => 1);
        my $device;
        for (my $tries=0 ; $tries < 10 ; $tries++) {
            open($device, "<", "/dev/barcodescanner");
            last if $device;
            sleep 1;
        }
        exitWithReason("No barcode reader attached") unless $device;
	my $cardNumber = "";
	if (timeout_call(
		30,
		sub {$cardNumber = <$device>})) {
	    next;
	}
        if ($cardNumber) {
	    chomp($cardNumber);

	    controlAccess($cardNumber);
        }
	close $device; # Clears buffer
    }

}


__PACKAGE__->main() unless caller;

1;
