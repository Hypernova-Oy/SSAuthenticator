#!/usr/bin/perl
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator;

our $VERSION = "0.12";

#Self-service authorization statuses
use constant {
    OK                => 1,
    ERR_UNDERAGE      => -1, #if below the allowed age for the given branch
    ERR_SSTAC         => -2, #if Self-service terms and conditions are not accepted
    ERR_BBC           => -3, #if BorrowerCategory is not accepted;
    ERR_REVOKED       => -4, #if self-service permission has been revoked for this user
    ERR_NAUGHTY       => -5, #if the authorizing user has fines or debarments
    ERR_CLOSED        => -6, #if the library's self-service time is over for the day
    ERR_BADCARD       => -7, #if user's cardnumber is not know
    ERR_NOTCACHED     => -8,
    ERR_ERR           => -100, #Server error
};


=encoding utf8

=head1 NAME

    SSAuthenticator - library access control system

=head1 DESCRIPTION

    SSAuthenticator is program that controls access to a library
    using Koha instance's REST API and its local cache.

=cut

use POSIX qw(LC_MESSAGES LC_ALL);
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

use Locale::TextDomain qw (SSAuthenticator); #Look from cwd or system defaults. This is needed for tests to pass during build

use GPIO;
use API;
use AutoConfigurer;

my %accessMsgs = (
                            #-----+++++-----+++++\n-----+++++-----+++++
    OK                 , N__"   Access granted   ", # '=>' quotes the key automatically, use ',' to not quote the constants to strings
    'ACCESS_DENIED'   => N__"   Access denied    ",
    ERR_UNDERAGE       , N__"     Age limit      ",
    ERR_SSTAC          , N__" Terms & Conditions \n    not accepted    ",
    ERR_BBC            , N__"   Wrong borrower   \n      category      ",
    ERR_REVOKED        , N__" Self-service usage \n permission revoked ",
    ERR_NAUGHTY        , N__" Circulation rules  \n    not followed    ",
    ERR_CLOSED         , N__"   Library closed   ",
    ERR_BADCARD        , N__"Card not recognized ",
    ERR_NOTCACHED      , N__"   Network error    ",
    ERR_ERR            , N__"   Strange error    ",
    'CACHE_USED'      => N__" I Remembered you!  ",
    'CONTACT_LIBRARY' => N__"Contact your library",
);


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
    my ($authorization, $cacheUsed) = @_;
    return 0 unless(defined($authorization));

    my $err;
    my $msg = _getOLEDMsg($authorization, $cacheUsed);
    for (my $i=0 ; $i<scalar(@$msg) ; $i++) {
        my $rv = $display->printRow($i, $msg->[$i]);
        $err = 1 unless ($rv =~ /^200/);
    }
    $display->endTransaction();

    return $err ? 0 : 1;
}
sub _getOLEDMsg {
    my ($authorization, $cacheUsed) = @_;

    my @msg;
    push(@msg, split("\n", __($accessMsgs{'ACCESS_DENIED'}))) if $authorization < 0;
    push(@msg, split("\n", __($accessMsgs{$authorization})));
    push(@msg, split("\n", __($accessMsgs{'CONTACT_LIBRARY'}))) if $authorization < 0;
    push(@msg, split("\n", __($accessMsgs{'CACHE_USED'}))) if $cacheUsed;
    return \@msg;
}

=HEAD2 isAuthorized

@RETURNS List of [0] Integer constant, authorization status
                 [1] Boolean, true if cache was used

=cut

sub isAuthorized {
    my ($cardNumber) = @_;
    my ($authorization, $cacheUsed) = canUseLibrary($cardNumber);

    my $open = isLibraryOpen();
    if ($authorization > 0 && not($open)) {
        $authorization = $open;
    }

    updateCache($cardNumber, $authorization) unless ($cacheUsed); #Don't extend cache duration if there is a cache hit. Original date of checking is important

    return ($authorization, $cacheUsed);
}

=head2 canUseLibrary

Checks if the given borrower represented by the given cardnumber can access the
self-service resource.
First we try to connect to the REST API, but wait for the response only for a short time.
Second alternative is to use the existing cache to see if the user is remembered and well behaving.

@RETURNS List of [0], Integer constant, the status of the authorization request.
                 [1], Boolean, was cache used because the REST API call timeoutted?

=cut

sub canUseLibrary {
    my ($cardNumber) = @_;

    my $authorized;
    my $cached;

    timeout_call(
        getTimeout(),
        sub {$authorized = isAuthorizedApi($cardNumber)}
    );

    # Check if we got response from REST API
    if (defined $authorized) {
        return ($authorized, $cached);
    } else {
        $authorized = isAuthorizedCache($cardNumber);

        if ($authorized && $authorized != ERR_NOTCACHED) {
            $cached = 1;
        }
    }

    return ($authorized, $cached);
}

=head2 isAuthorizedApi

Connects to the Koha REST API to see if the cardnumber belongs to a well-behaving library patron

@PARAM1 String, cardnumber to check status for
@RETURNS Integer, OK, if authorized
                  ERR_* if not
                  undef, if authorization via the REST API failed for some strange reason

=cut

sub isAuthorizedApi {
    my ($cardNumber) = @_;

    my $httpResponse = getApiResponse($cardNumber);
    my $body = decodeContent($httpResponse);
    my $status = $httpResponse->code() || '';

    if ($status eq '404') {
        return ERR_BADCARD;
    }
    elsif (exists $body->{error}) {
        my $err = $body->{error};
        return ERR_UNDERAGE if $err eq 'Koha::Exception::SelfService::Underage';
        return ERR_SSTAC    if $err eq 'Koha::Exception::SelfService::TACNotAccepted';
        return ERR_BBC      if $err eq 'Koha::Exception::SelfService::BlockedBorrowerCategory';
        return ERR_REVOKED  if $err eq 'Koha::Exception::SelfService::PermissionRevoked';
        return ERR_NAUGHTY  if $err eq 'Koha::Exception::SelfService';
        return ERR_ERR;
    }
    elsif (exists $body->{permission}) {
        return $body->{permission} eq 'true' ? OK : ERR_ERR;
    } else {
        syslog(LOG_ERR, "REST API is not working as expected. ".
                        "Maybe it is misconfigured?");
        return undef; #For some reason server doesn't respond. Fall back to using cache.
    }
}

sub decodeContent {
    my ($response) = @_;

    my $responseContent = $response->decoded_content;

    if ($responseContent) {
        return JSON::decode_json $responseContent;
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
    return 1 if 1;
    return ERR_CLOSED;
}

sub isAuthorizedCache {
    my ($cardNumber) = @_;
    if (getDB()->exists($cardNumber)) {
        my $patronInfo = getDB()->get($cardNumber);
        return $$patronInfo{access};
    } else {
        return ERR_NOTCACHED;
    }
}

sub grantAccess {
    my ($authorization, $cacheUsed) = @_;

    doorOn();
    ledOn('green');

    showOLEDMsg($authorization, $cacheUsed);
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
    my ($authorization, $cacheUsed) = @_;

    ledOn('red');
    showOLEDMsg($authorization, $cacheUsed);
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
    my ($cardNumber, $authStatus) = @_;
    getDB()->put($cardNumber, {time => localtime,
                        access => $authStatus});
}

sub removeFromCache {
    my ($cardNumber) = @_;
    getDB()->delete($cardNumber);
}

sub controlAccess {
    my ($cardNumber) = @_;
    my ($authorizationStatus, $cacheUsed) = isAuthorized($cardNumber);

    if ($authorizationStatus > 0) {
        grantAccess($authorizationStatus, $cacheUsed);
    } else {
        denyAccess($authorizationStatus, $cacheUsed);
    }
}

sub exitWithReason {
    my ($reason) = @_;
    notifyAboutError($reason);
    exit(1);
}

sub getBarcodeSeparator {
    # TODO: Check if param exists before comparing.
    my $conf = getConfig();
    if ($conf->param('CarriageReturnAsSeparator') && $conf->param('CarriageReturnAsSeparator') eq "true") {
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

=head2 changeLanguage

    SSAuthenticator::changeLanguage('fi_FI', 'UTF-8');

Changes the language of the running process

=cut

sub changeLanguage {
    my ($lang, $encoding) = @_;
    $ENV{LANGUAGE} = $lang;
    POSIX::setlocale(LC_ALL, "$lang.$encoding");
}

sub main {
    if (!isConfigValid()) {
        exitWithReason("/etc/ssauthenticator/daemon.conf is invalid");
    }

    configureBarcodeScanner();

    local $/ = getBarcodeSeparator();

    syslog(LOG_INFO, "Entering main loop");
    say "Entering main loop";
    while (1) {
        notify(WATCHDOG => 1);
        my $device;
        ##Sometimes the barcode scanner can disappear and reappear during/after configuration. Try to find a barcode scanner handle
        for (my $tries=0 ; $tries < 10 ; $tries++) {
            open($device, "<", "/dev/barcodescanner");
            last if $device;
            sleep 1;
        }
        exitWithReason("No barcode reader attached") unless $device;
        my $cardNumber = "";
        if (timeout_call(
            30,
            sub {$cardNumber = <$device>})
        ) {
            next;
        }
        if ($cardNumber) {
            chomp($cardNumber);
            syslog(LOG_INFO, "Read barcode '$cardNumber'");
            say "Read barcode '$cardNumber'";

            controlAccess($cardNumber);
        }
        close $device; # Clears buffer
    }
}


__PACKAGE__->main() unless caller;

1;
