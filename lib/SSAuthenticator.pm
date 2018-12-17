#!/usr/bin/perl
# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator;

our $VERSION = "0.13";

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
use Try::Tiny;
use POSIX qw(LC_MESSAGES LC_ALL floor ceil);
use Config::Simple;
use JSON::XS;
use Data::Dumper;
use Sys::SigAction qw( timeout_call );
use Time::HiRes;
use OLED::Client;

use Locale::TextDomain qw (SSAuthenticator); #Look from cwd or system defaults. This is needed for tests to pass during build

use GPIO;
use SSAuthenticator::API;
use SSAuthenticator::Config;
use SSAuthenticator::AutoConfigurer;
use SSAuthenticator::DB;
use SSAuthenticator::Greetings;
use SSAuthenticator::Lock;
use SSAuthenticator::Mailbox;
use SSLog;

my $l = bless({}, 'SSLog');

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
    'BARCODE_READ'    => N__"    Barcode read    ",
    'PLEASE_WAIT'     => N__"    Please wait     ",
    'BLANK_ROW'       => N__"                    ",

    ##INITIALIZATION MESSAGES
    'INITING_STARTING'  => N__"  I am waking up.   \\nPlease wait a moment\\nWhile I check I have\\n everything I need. ",
    'INITING_ERROR'     => N__" I have failed you  \\n  I am not working  \\nPlease contact your \\n      library       ",
    'INITING_FINISHED'  => N__"   I am complete    \\n   Please use me.   \\n                    \\n                    ",
);

#Certain $authorization-statuses have extra parameters that need to be displayed. Use this package variable
#as a hack to deliver parameters through the authorization-stack without needing to refactor everything.
my %packageHack;

my SSAuthenticator::Lock $lockControl;
my $leds = {};

sub db {
    return SSAuthenticator::DB::getDB();
}

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

sub lockControl {
    $lockControl = SSAuthenticator::Lock->new() unless $lockControl;
    return $lockControl;
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

sub getBarcodeReadMsg {
    my ($barcode) = @_;
    my @rows;
    $rows[0] = __($messages{'BARCODE_READ'});
    $rows[1] = __($messages{'PLEASE_WAIT'});
    $rows[2] = __($messages{'BLANK_ROW'});
    $rows[3] = centerRow($barcode);
    return \@rows;
}

=head2 showOLEDMsg

@PARAM1 ARRAYRef of String, 20-character-long messages.

=cut

my $display = OLED::Client->new();
sub showOLEDMsg {
    my ($msgs) = @_;

    my $err;
    eval {
        #Prevent printing more than the screen can handle
        my $rows = scalar(@$msgs);
        $rows = 4 if $rows > 4;

        for (my $i=0 ; $i<$rows ; $i++) {
            $l->info("showOLEDMsg():> $i: ".$msgs->[$i]) if $l->is_info;
            my $rv = $display->printRow($i, $msgs->[$i]);
            $err = 1 unless ($rv =~ /^200/);
        }
        $display->endTransaction();
    };
    $l->error("showOLEDMsg() $@") if $@;

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

    #"please wait" might be already written on the screen.
    #Make sure it is overwritten when auth status is known.
    #So user doesnt see,
    #  "Auth succeess"
    #  "Please wait"
    if (scalar(@msg) < 2) { #If there is only one row to be printed
        #Append two blank rows
        push(@msg, '                    ');
        push(@msg, '                    ');
    }

    return \@msg;
}

=head3 centerRow

Centers the given row to fit the 20-character wide OLED-display

=cut

sub centerRow {
    my $le = length($_[0]);
    return substr($_[0], 0, 20) if $le >= 20;
    my $padding = (20 - $le) / 2;
    my $pLeft = floor($padding);
    my $pRight = ceil($padding);
    return sprintf("\%${pLeft}s\%s\%${pRight}s", "", $_[0], "");
}

=HEAD2 isAuthorized

@RETURNS List of [0] Integer constant, authorization status
                 [1] Boolean, true if cache was used

=cut

sub isAuthorized {
    my ($cardNumber) = @_;
    my ($authorization, $cacheUsed) = canUseLibrary($cardNumber);
    $l->info("canUseLibrary() returns \$authorization=".($authorization || '').", \$cacheUsed=".($cacheUsed || '')) if $l->is_info;

    my $open = isLibraryOpen();
    $l->info("isLibraryOpen() returns \$open=".($open || '')) if $l->is_info;
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
    my $timedOut;

    try {

        if ($ENV{SSA_TEST_MODE}) { #Is this anymore necessary?
            my $start = time;
            $authorized = isAuthorizedApi($cardNumber);
            my $duration = time - $start;
            $timedOut = ($duration >= SSAuthenticator::Config::getTimeoutInSeconds()) ? 1 : 0;
        }
        else {
            $authorized = isAuthorizedApi($cardNumber);
        }

    } catch {
        if (blessed($_) && $_->isa('SSAuthenticator::Exception::HTTPTimeout')) {
            $timedOut = 1;
        }
        elsif (blessed($_)) { $_->rethrow(); }
        else { die $_; }
    };

    $l->warn("isAuthorizedApi() timed out") if $timedOut;
    $l->info("isAuthorizedApi() returns ".($authorized || '')) if $l->is_info;

    # Check if we got response from REST API
    if (defined $authorized) {
        return ($authorized, $cacheUsed);
    } else {
        $authorized = isAuthorizedCache($cardNumber);
        $l->info("isAuthorizedCache() returns ".($authorized || '')) if $l->is_info;

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
        $l->info("getApiResponse() returns a ".ref($httpResponse)." with \$status=$status, \$permission=$permission, \$err=$err") if $l->is_info;
    }
    else {
        $l->error("getApiResponse() returns '".($httpResponse || '')."' instead of a HTTP:Response-object!!") if $l->is_error;
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
    elsif ($status =~ /^5\d\d/) { #Statuses starting with 5, aka. Server errors.
        $l->error("isAuthorizedApi($cardNumber) REST API returns server error:\n".$httpResponse->as_string) if $l->is_error;
        return undef;
    }

    $l->error("isAuthorizedApi() REST API is not working as expected. Got this HTTP response:\n".Data::Dumper::Dumper($httpResponse)."\nEO HTTP Response") if $l->is_error;
    return undef; #For some reason server doesn't respond. Fall back to using cache.
}

=head2 decodeContent

Extracts the body parameters from the given HTTP::Response-object

@RETURNS HASHRef of body parameters decoded or an empty HASHRef is errors happened.
@DIE     if HTTP::Response content is not valid JSON or if content doesn't exist

=cut

my $jsonParser = JSON::XS->new();
sub decodeContent {
    my ($response) = @_;

    my $responseContent = $response->decoded_content(default_charset => 'utf8');
    $l->trace("\$responseContent: ".Data::Dumper::Dumper($responseContent)) if $l->is_trace;
    unless ($responseContent) {
        $responseContent = $response->{_content};
        $l->info("Couldn't decode \$responseContent, working with raw content: ".Data::Dumper::Dumper($responseContent)) if $l->is_info;
    }

    my $body;
    eval {
        die "\$responseContent is not defined!" unless $responseContent;
        $l->info("decodeContent() \$responseContent=$responseContent") if $l->is_info;
        $body = $jsonParser->decode($responseContent);
    };
    #In some strange cases the $responseContent is already a HASHRef of decoded JSON parameters.
    #There is a ghost in the shell making HTTP::Response return HASHRefs on one request, and then again
    #decoded strings of HTTP Request body on some other requests.
    if ($@) {
        $l->error("Cannot decode HTTP::Response:\n".$response->as_string()."\nCONTENT: ".Data::Dumper::Dumper($responseContent)."\nJSON::decode_json ERROR: ".Data::Dumper::Dumper($@)) if $l->is_error();

        if (ref($responseContent) eq 'HASH') {
            $body = $responseContent;
            $l->error("Looks like \$responseContent is already a HASHRef. Trying to make it work.") if $l->is_error();
        }
    }

    return $body;
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
        $l->debug("isAuthorizedCache() \$cardNumber=$cardNumber exists and has \$status=".$$patronInfo{access}) if $l->is_debug;
        return $$patronInfo{access};
    } else {
        $l->debug("isAuthorizedCache() \$cardNumber=$cardNumber not cached") if $l->is_debug;
        return ERR_NOTCACHED;
    }
}

sub grantAccess {
    my ($authorization, $cacheUsed) = @_;
    my $doorOpenDuration = SSAuthenticator::Config::getDoorOpenDuration() / 1000; #Turn ms to seconds

    lockControl()->on();
    my $doorOpenStartTime = Time::HiRes::time();
    ledOn('green');

    showAccessMsg($authorization, $cacheUsed);
    playAccessBuzz();

    #Wait for the specified amount of time to keep the door relay closed.
    #This can be used to keep the doors open longer, or to prolong the opening signal to a building automation system.
    my $doorOpenTimeLeft = $doorOpenDuration - (Time::HiRes::time() - $doorOpenStartTime);
    Time::HiRes::sleep($doorOpenTimeLeft);

    ledOff('green');
    lockControl()->off();
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
        $l->warn("failed to execute: $!\n") if $l->is_warn;
    }
    elsif ($? & 127) {
        $l->warn(sprintf "rtttl-player died with signal %d, %s coredump\n",
        ($? & 127),  ($? & 128) ? 'with' : 'without') if $l->is_warn;
    }
    else {
        $l->warn(sprintf "rtttl-player exited with value %d\n", $? >> 8) if $l->is_warn;
    };
}

sub denyAccess {
    my ($authorization, $cacheUsed) = @_;

    ledOn('red');
    showAccessMsg($authorization, $cacheUsed);
    playDenyAccessBuzz();
    ledOff('red');
}

sub updateCache {
    my ($cardNumber, $authStatus) = @_;
    $l->debug("updateCache() $cardNumber cached using \$authStatus=$authStatus") if $l->is_debug;
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
        $l->info("controlAccess($cardNumber):> Granting access with \$authorizationStatus=$authorizationStatus, \$cacheUsed=".($cacheUsed || 'undef')) if $l->is_info;
        grantAccess($authorizationStatus, $cacheUsed);
    } else {
        $l->info("controlAccess($cardNumber):> Denying access with \$authorizationStatus=$authorizationStatus, \$cacheUsed=".($cacheUsed || 'undef')) if $l->is_info;
        denyAccess($authorizationStatus, $cacheUsed);
    }
}

sub getBarcodeSeparator {
    # TODO: Check if param exists before comparing.
    my $conf = config();
    if ($conf->param('CarriageReturnAsSeparator') && $conf->param('CarriageReturnAsSeparator') eq "true") {
        $l->info("using \\r as barcode separator") if $l->is_info;
        return "\r";
    } else {
        $l->info("using \\n as barcode separator") if $l->is_info;
        return "\n";
    }
}

sub configureBarcodeScanner {
    my $configurer = SSAuthenticator::AutoConfigurer->new;
    $configurer->configure();
    $l->info("Barcode scanner configured") if $l->is_info;
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

sub setDefaultLanguage {
    changeLanguage(
        config()->param('DefaultLanguage'),
        'UTF-8',
    );
    $l->info("setDefaultLanguage() ".config()->param('DefaultLanguage')) if $l->is_info;
}

sub main {
    local $/ = getBarcodeSeparator();

    showInitializingMsg('STARTING'); sleep 2;
    eval {
        setDefaultLanguage();
        configureBarcodeScanner();
    };
    if ($@) {
        $l->fatal("$@");
        showInitializingMsg('ERROR');
        exit(1);
    }

    $l->info("main() Entering main loop");
    showInitializingMsg('FINISHED');
    while (1) {
        SSAuthenticator::Mailbox::checkMailbox();
        my $device;
        ##Sometimes the barcode scanner can disappear and reappear during/after configuration. Try to find a barcode scanner handle
        for (my $tries=0 ; $tries < 10 ; $tries++) {
            open($device, "<", "/dev/barcodescanner");
            last if $device;
            sleep 1;
        }
        $l->error("main() No barcode reader attached") && exit(1) unless $device;
        my $cardNumber = "";
        if (timeout_call(
            30,
            sub {$cardNumber = <$device>})
        ) {
            next;
        }
        if ($cardNumber) {
            chomp($cardNumber);
            $l->info("main() Read barcode '$cardNumber'") if $l->is_info;
            showOLEDMsg(getBarcodeReadMsg($cardNumber)) if config()->param('OLED_ShowCardNumberWhenRead');
            #sleep 1; #DEBUG: Sleep a bit to make more sense out of the barcode on the OLED-display.

            eval {
                controlAccess($cardNumber);
            };
            if ($@) {
                $l->fatal("controlAccess($cardNumber) $@");
            }
        }
        close $device; # Clears buffer
    }
}

1;
