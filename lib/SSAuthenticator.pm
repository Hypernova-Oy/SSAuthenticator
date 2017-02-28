#!/usr/bin/perl
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator;

our $VERSION = "0.12";

#Self-service authorization statuses
#Statuses > 0 are success statuses
#Statuses between -1 and -99 are user failure statuses
#statuses <= -100 are software issues
use constant {
    OK                => 1,
    ERR_UNDERAGE      => -1, #if below the allowed age for the given branch
    ERR_SSTAC         => -2, #if Self-service terms and conditions are not accepted
    ERR_BBC           => -3, #if BorrowerCategory is not accepted;
    ERR_REVOKED       => -4, #if self-service permission has been revoked for this user
    ERR_NAUGHTY       => -5, #if the authorizing user has fines or debarments
    ERR_CLOSED        => -6, #if the library's self-service time is over for the day
    ERR_BADCARD       => -7, #if user's cardnumber is not know
    ERR_NOTCACHED     => -8, #
    ERR_ERR           => -100, #Server error
};


=encoding utf8

=head1 NAME

    SSAuthenticator - library access control system

=head1 DESCRIPTION

    SSAuthenticator is program that controls access to a library
    using Koha instance's REST API and its local cache.

=cut

use Modern::Perl;

use Scalar::Util qw(blessed);
use POSIX qw(LC_MESSAGES LC_ALL);
use Config::Simple;
use JSON;
use Data::Dumper;
use Sys::SigAction qw( timeout_call );
use Time::HiRes;
use Log::Log4perl qw(:easy);
use OLED::Client;

use Locale::TextDomain qw (SSAuthenticator); #Look from cwd or system defaults. This is needed for tests to pass during build

use GPIO;
use SSAuthenticator::API;
use SSAuthenticator::Config;
use SSAuthenticator::AutoConfigurer;
use SSAuthenticator::DB;
use SSAuthenticator::Greetings;

my %messages = (
                            #-----+++++-----+++++\n-----+++++-----+++++\n-----+++++-----+++++\n-----+++++-----+++++
    ##ACCESS MESSAGES
    OK                 , N__"   Access granted   ", # '=>' quotes the key automatically, use ',' to not quote the constants to strings
    'ACCESS_DENIED'   => N__"   Access denied    ",
    ERR_UNDERAGE       , N__"     Age limit      ",
    ERR_SSTAC          , N__" Terms & Conditions \\n    not accepted    ",
    ERR_BBC            , N__"   Wrong borrower   \\n      category      ",
    ERR_REVOKED        , N__" Self-service usage \\n permission revoked ",
    ERR_NAUGHTY        , N__" Circulation rules  \\n    not followed    ",
    ERR_CLOSED         , N__"   Library closed   ",
    ERR_BADCARD        , N__"Card not recognized ",
    ERR_NOTCACHED      , N__"   Network error    ",
    ERR_ERR            , N__"  Unexpected error  ",
    'CACHE_USED'      => N__" I Remembered you!  ",
    'CONTACT_LIBRARY' => N__"Contact your library",
    'OPEN_AT'         => N__"Open at",

    ##INITIALIZATION MESSAGES
    'INITING_STARTING'  => N__"  I am waking up.   \\nPlease wait a moment\\nWhile I check I have\\n everything I need. ",
    'INITING_ERROR'     => N__" I have failed you  \\n  I am not working  \\nPlease contact your \\n      library       ",
    'INITING_FINISHED'  => N__"   I am complete    \\n   Please use me.   ",
);

#Certain $authorization-statuses have extra parameters that need to be displayed. Use this package variable
#as a hack to deliver parameters through the authorization-stack without needing to refactor everything.
my %packageHack;

sub db {
    return SSAuthenticator::DB::getDB();
}

my $leds = {};
sub initLeds {
    $leds->{red}   = GPIO->new(config()->param('RedLEDPin'));
    $leds->{green} = GPIO->new(config()->param('GreenLEDPin'));
    $leds->{blue}  = GPIO->new(config()->param('BlueLEDPin'));
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
    $doorRelay = GPIO->new(config()->param('DoorPin'));
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

sub showAccessMsg {
    my ($authorization, $cacheUsed) = @_;
    return 0 unless(defined($authorization));

    return showOLEDMsg(  _getAccessMsg($authorization, $cacheUsed)  );
}

sub showInitializingMsg {
    my ($type) = @_;
    return showOLEDMsg(  [split(/\\n/, __($messages{"INITING_$type"}))]  );
}

=head2 showOLEDMsg

@PARAM1 ARRAYRef of String, 20-character-long messages.

=cut

my $display = OLED::Client->new();
sub showOLEDMsg {
    my ($msgs) = @_;

    my $err;
    #Prevent printing more than the screen can handle
    my $rows = scalar(@$msgs);
    $rows = 4 if $rows > 4;

    for (my $i=0 ; $i<$rows ; $i++) {
        my $rv = $display->printRow($i, $msgs->[$i]);
        $err = 1 unless ($rv =~ /^200/);
    }
    $display->endTransaction();

    return $err ? 0 : 1;
}

sub _getAccessMsg {
    my ($authorization, $cacheUsed) = @_;

    my @msg;
    push(@msg, split(/\\n/, __($messages{'ACCESS_DENIED'}))) if $authorization < 0;
    push(@msg, split(/\\n/, __($messages{$authorization})));
    push(@msg, split(/\\n/, __($messages{'OPEN_AT'}).' '.$packageHack{openingTime}.'-'.$packageHack{closingTime})) if $authorization == ERR_CLOSED;
    push(@msg, split(/\\n/, __($messages{'CONTACT_LIBRARY'}))) if $authorization < 0;
    push(@msg, split(/\\n/, __($messages{'CACHE_USED'}))) if $cacheUsed;

    if ($authorization > 0) { #Only print a happy-happy-joy-joy message on success ;)
        my $happyHappyJoyJoy = SSAuthenticator::Greetings::random();
        push(@msg, split(/\\n/, __($happyHappyJoyJoy))) if $happyHappyJoyJoy;
    }

    return \@msg;
}

=HEAD2 isAuthorized

@RETURNS List of [0] Integer constant, authorization status
                 [1] Boolean, true if cache was used

=cut

sub isAuthorized {
    my ($cardNumber) = @_;
    my ($authorization, $cacheUsed) = canUseLibrary($cardNumber);
    INFO "canUseLibrary() returns \$authorization=".($authorization || '').", \$cacheUsed=".($cacheUsed || '');

    my $open = isLibraryOpen();
    INFO "isLibraryOpen() returns \$open=".($open || '');
    if ($authorization > 0 && not($open)) {
        $authorization = $open;
    }

    #Don't extend cache duration if there is a cache hit. Original date of checking is important
    updateCache($cardNumber, $authorization)
        if (not($cacheUsed) && $authorization != ERR_BADCARD && $authorization != ERR_ERR
                            && $authorization != ERR_NOTCACHED && $authorization != ERR_CLOSED
        );

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
    my $cacheUsed;

    timeout_call(
        getTimeout(),
        sub {$authorized = isAuthorizedApi($cardNumber)}
    );
    INFO "isAuthorizedApi() returns ".($authorized || '');

    # Check if we got response from REST API
    if (defined $authorized) {
        return ($authorized, $cacheUsed);
    } else {
        $authorized = isAuthorizedCache($cardNumber);
        INFO "isAuthorizedCache() returns ".($authorized || '');

        if ($authorized && $authorized != ERR_NOTCACHED) {
            $cacheUsed = 1;
        }
    }

    return ($authorized, $cacheUsed);
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

    my $httpResponse = SSAuthenticator::API::getApiResponse($cardNumber);
    my $body = $httpResponse ? decodeContent($httpResponse) : {};
    my $err = $body->{error} || '';
    my $permission = $body->{permission} || '';
    my $status = $httpResponse ? $httpResponse->code() : '';

    if ($httpResponse && blessed($httpResponse) && $httpResponse->isa('HTTP::Response')) {
        INFO "getApiResponse() returns a ".ref($httpResponse)." with \$status=$status, \$permission=$permission, \$err=$err";
    }
    else {
        ERROR "getApiResponse() returns '".($httpResponse || '')."' instead of a HTTP:Response-object!!";
    }

    if ($status eq 404) {
        return ERR_BADCARD;
    }
    elsif ($status eq 200 && $err) {
        return ERR_UNDERAGE if $err eq 'Koha::Exception::SelfService::Underage';
        return ERR_SSTAC    if $err eq 'Koha::Exception::SelfService::TACNotAccepted';
        return ERR_BBC      if $err eq 'Koha::Exception::SelfService::BlockedBorrowerCategory';
        return ERR_REVOKED  if $err eq 'Koha::Exception::SelfService::PermissionRevoked';
        if ($err eq 'Koha::Exception::SelfService::OpeningHours') {
            $packageHack{openingTime} = $body->{startTime};
            $packageHack{closingTime} = $body->{endTime};
            return ERR_CLOSED;
        }
        return ERR_NAUGHTY  if $err eq 'Koha::Exception::SelfService';
        return ERR_ERR;
    }
    elsif ($status eq 200 && $permission) {
        return $permission ? OK : ERR_ERR;
    }

    ERROR "isAuthorizedApi() REST API is not working as expected. Got this HTTP response:\n".Data::Dumper::Dumper($httpResponse)."\nEO HTTP Response";
    return undef; #For some reason server doesn't respond. Fall back to using cache.
}

sub decodeContent {
    my ($response) = @_;

    my $responseContent = $response->decoded_content;
    INFO "decodeContent() \$responseContent=$responseContent";

    if ($responseContent) {
        return JSON::decode_json $responseContent;
    } else {
        return ();
    }
}

sub isLibraryOpen {
    my $libraryName = config()->param('LibraryName');
    # TODO:
    # Request data from API and fallback to cache if not possible
    return 1 if 1;
    return ERR_CLOSED;
}

sub isAuthorizedCache {
    my ($cardNumber) = @_;
    if (db()->exists($cardNumber)) {
        my $patronInfo = db()->get($cardNumber);
        DEBUG "isAuthorizedCache() \$cardNumber=$cardNumber exists and has \$status=".$$patronInfo{access};
        return $$patronInfo{access};
    } else {
        DEBUG "isAuthorizedCache() \$cardNumber=$cardNumber not cached";
        return ERR_NOTCACHED;
    }
}

sub grantAccess {
    my ($authorization, $cacheUsed) = @_;

    doorOn();
    ledOn('green');

    showAccessMsg($authorization, $cacheUsed);
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
    system('rtttl-player','-p',config()->param('RTTTL-PlayerPin'),'-o',"song-$song");
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
    showAccessMsg($authorization, $cacheUsed);
    playDenyAccessBuzz();
    ledOff('red');
}

my $defaultTimeout = 3000;
sub getTimeout() {
    if (config()->param('ConnectionTimeout')) {
        return millisecs2secs(config()->param('ConnectionTimeout'));
    } else {
        return millisecs2secs($defaultTimeout);
    }
}

sub millisecs2secs {
    my ($milliseconds) = @_;
    return $milliseconds / 1000;
}

sub updateCache {
    my ($cardNumber, $authStatus) = @_;
    DEBUG "updateCache() $cardNumber cached using \$authStatus=$authStatus";
    db()->put($cardNumber, {time => localtime,
                        access => $authStatus});
}

sub removeFromCache {
    my ($cardNumber) = @_;
    db()->delete($cardNumber);
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

sub getBarcodeSeparator {
    # TODO: Check if param exists before comparing.
    my $conf = config();
    if ($conf->param('CarriageReturnAsSeparator') && $conf->param('CarriageReturnAsSeparator') eq "true") {
        INFO "using \\r as barcode separator";
        return "\r";
    } else {
        INFO "using \\n as barcode separator";
        return "\n";
    }
}

sub configureBarcodeScanner {
    my $configurer = SSAuthenticator::AutoConfigurer->new;
    $configurer->configure();
    INFO "Barcode scanner configured";
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

sub config {
    return SSAuthenticator::Config::getConfig();
}

sub openLogger {
    my ($verbose) = @_;
    Log::Log4perl->easy_init($ERROR) && return if not($verbose);
    Log::Log4perl->easy_init($FATAL) && return if $verbose == -1;
    Log::Log4perl->easy_init($INFO) && return if $verbose == 1;
    Log::Log4perl->easy_init($DEBUG) && return if $verbose == 2;
}

sub setDefaultLanguage {
    changeLanguage(
        config()->param('DefaultLanguage'),
        'UTF-8',
    );
    INFO "setDefaultLanguage() ".config()->param('DefaultLanguage');
}

sub main {
    openLogger( config()->param('Verbose') );

    local $/ = getBarcodeSeparator();

    showInitializingMsg('STARTING'); sleep 2;
    eval {
        if (!SSAuthenticator::Config::isConfigValid()) {
            die("Config file ".SSAuthenticator::Config::getConfigFile()." is invalid");
        }

        setDefaultLanguage();
        configureBarcodeScanner();
    };
    if ($@) {
        FATAL "$@";
        showInitializingMsg('ERROR');
        exit(1);
    }

    INFO "main() Entering main loop";
    showInitializingMsg('FINISHED');
    while (1) {
        my $device;
        ##Sometimes the barcode scanner can disappear and reappear during/after configuration. Try to find a barcode scanner handle
        for (my $tries=0 ; $tries < 10 ; $tries++) {
            open($device, "<", "/dev/barcodescanner");
            last if $device;
            sleep 1;
        }
        ERROR "main() No barcode reader attached" && exit(1) unless $device;
        my $cardNumber = "";
        if (timeout_call(
            30,
            sub {$cardNumber = <$device>})
        ) {
            next;
        }
        if ($cardNumber) {
            chomp($cardNumber);
            INFO "main() Read barcode '$cardNumber'";

            eval {
                controlAccess($cardNumber);
            };
            if ($@) {
                FATAL "controlAccess($cardNumber) $@";
            }
        }
        close $device; # Clears buffer
    }

    closelog();
}


__PACKAGE__->main() unless caller;

1;
