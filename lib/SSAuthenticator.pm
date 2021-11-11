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
    ERR_PINTIMEOUT    => -9,   #User took too long to enter the PIN code
    ERR_PINBAD        => -10,  #User entered a wrong PIN number
    ERR_SERVER        => -100, #Server error, probably API Broken or misconfigured from the server side
    ERR_API_AUTH      => -101, #API auth error
    ERR_SERVERCONN    => -102, #Server has connection issues
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
use POSIX qw(floor ceil);
use Data::Dumper;
use Time::HiRes;

use Locale::TextDomain qw (SSAuthenticator); #Look from cwd or system defaults. This is needed for tests to pass during build

use GPIO;
use SSAuthenticator::API;
use SSAuthenticator::BarcodeReader;
use SSAuthenticator::Config;
use SSAuthenticator::AutoConfigurer;
use SSAuthenticator::DB;
use SSAuthenticator::Device::KeyPad;
use SSAuthenticator::Device::RGBLed;
use SSAuthenticator::I18n qw($i18nMsg);
use SSAuthenticator::Lock;
use SSAuthenticator::Mailbox;
use SSAuthenticator::OLED;
use SSAuthenticator::Password;
use SSAuthenticator::RTTTL;
use SSAuthenticator::SharedState;
use SSAuthenticator::Transaction;
use SSLog;

my $l = bless({}, 'SSLog');

my SSAuthenticator::Lock $lockControl;
our SSAuthenticator::Device::KeyPad $keyPad;

sub db {
    return SSAuthenticator::DB::getDB();
}

sub lockControl {
    $lockControl = SSAuthenticator::Lock->new() unless $lockControl;
    return $lockControl;
}

=HEAD2 isAuthorized

@RETURNS List of [0] Integer constant, authorization status
                 [1] Boolean, true if cache was used

=cut

sub isAuthorized {
    my ($trans, $cardnumber) = @_;
    checkCardPermission($trans, $cardnumber);
    $l->info("checkCardPermission() returns \$authorization=".($trans->cardAuthz || '').", \$cacheUsed=".($trans->cardAuthzCacheUsed || '')) if $l->is_info;


    if ($trans->cardAuthz > 0 && config()->param('RequirePIN')) {
        try {
            checkPIN($trans, $cardnumber);
        } catch {
            if (blessed($_) && $_->isa('SSAuthenticator::Exception::KeyPad::WaitTimeout')) {
                $trans->pinAuthn(ERR_PINTIMEOUT);
                $keyPad->turnOff();
            }
            elsif (blessed($_)) { $_->rethrow(); }
            else { die $_; }
        };
    }

    if (config()->param('RequirePIN') && $trans->cardAuthz > 0 && $trans->pinAuthn > 0) {
        $trans->auth(1);
    }
    elsif (not(config()->param('RequirePIN')) && $trans->cardAuthz > 0) {
        $trans->auth(1)
    }
    else {
        $trans->auth(0);
    }
    $trans->cacheUsed($trans->pinAuthnCacheUsed || $trans->cardAuthzCacheUsed);

#    Time::HiRes::sleep(1);
#    SSAuthenticator::Device::RGBLed::ledShow();
#    SSAuthenticator::RTTTL::playZelda();
#    SSAuthenticator::OLED::allYourBaseAreBelongToUs();

    return $trans;
}

=head2 checkCardPermission

Checks if the given borrower represented by the given cardnumber can access the
self-service resource.
First we try to connect to the REST API, but wait for the response only for a short time.
Second alternative is to use the existing cache to see if the user is remembered and well behaving.

@RETURNS List of [0], Integer constant, the status of the authorization request.
                 [1], Boolean, was cache used because the REST API call timeoutted?

=cut

sub checkCardPermission {
    my ($trans, $cardnumber) = @_;

    try {
        $trans->cardAuthz(isAuthorizedApi($cardnumber));
    } catch {
        $l->fatal("isAuthorizedApi() died with error:\n".$l->flatten($_));
        $trans->cardAuthz(ERR_SERVER);
    };
    $l->info("isAuthorizedApi() returns ".($trans->cardAuthz || ''));

    # Check if we got response from REST API
    if ($trans->cardAuthz != ERR_SERVER && $trans->cardAuthz != ERR_SERVERCONN && $trans->cardAuthz != ERR_API_AUTH) {
        #Don't extend cache duration if there is a cache hit. Original date of checking is important
        if (not($trans->cardAuthzCacheUsed) &&
            $trans->cardAuthz != ERR_BADCARD &&
            $trans->cardAuthz != ERR_SERVER &&
            $trans->cardAuthz != ERR_SERVERCONN &&
            $trans->cardAuthz != ERR_API_AUTH &&
            $trans->cardAuthz != ERR_CLOSED) {
            updateCache($trans, $cardnumber, $trans->cardAuthz);
        }
        return $trans;
    } else {
        checkCard_tryCache($trans, $cardnumber);
    }
    return $trans;
}

=head2 isAuthorizedApi

Connects to the Koha REST API to see if the cardnumber belongs to a well-behaving library patron

@PARAM1 String, cardnumber to check status for
@RETURNS Integer, OK, if authorized
                  ERR_* if not
                  undef, if authorization via the REST API failed for some strange reason

=cut

sub isAuthorizedApi {
    my ($cardnumber) = @_;
    SSAuthenticator::API::isMalfunctioning(0);

    my ($httpResponse, $body, $err, $permission, $status) = SSAuthenticator::API::getApiResponse($cardnumber);

    if ($status eq 401 || $status eq 403) {
        SSAuthenticator::API::isMalfunctioning(ERR_API_AUTH);
        return ERR_API_AUTH;
    }
    elsif ($status eq 404 && $httpResponse->header('Content-Type') =~ /text.html/) {
        SSAuthenticator::API::isMalfunctioning(ERR_SERVER);
        return ERR_SERVER;
    }
    elsif ($status eq 404) {
        return ERR_BADCARD;
    }
    elsif ($status =~ /^510/) { #Statuses starting with 510, LWP::UserAgent connectivity issues
        $l->error("isAuthorizedApi($cardnumber) REST API cannot connect to server. Error:\n".$httpResponse->as_string) if $l->is_error;
        SSAuthenticator::API::isMalfunctioning(ERR_SERVERCONN);
        return ERR_SERVERCONN;
    }
    elsif ($status =~ /^5\d\d/) { #Statuses starting with 5, aka. Server errors.
        $l->error("isAuthorizedApi($cardnumber) REST API returns server error:\n".$httpResponse->as_string) if $l->is_error;
        SSAuthenticator::API::isMalfunctioning(ERR_SERVER);
        return ERR_SERVER;
    }
    elsif ($status eq 200 && $err) {
        return ERR_UNDERAGE if $err eq 'Koha::Exception::SelfService::Underage';
        return ERR_SSTAC    if $err eq 'Koha::Exception::SelfService::TACNotAccepted';
        return ERR_BBC      if $err eq 'Koha::Exception::SelfService::BlockedBorrowerCategory';
        return ERR_REVOKED  if $err eq 'Koha::Exception::SelfService::PermissionRevoked';
        if ($err eq 'Koha::Exception::SelfService::OpeningHours') {
            SSAuthenticator::SharedState::set('openingTime', $body->{startTime});
            SSAuthenticator::SharedState::set('closingTime', $body->{endTime});
            return ERR_CLOSED;
        }
        return ERR_NAUGHTY  if $err eq 'Koha::Exception::SelfService';
        return ERR_SERVER;
    }
    elsif ($status eq 200 && $permission) {
        return $permission ? OK : ERR_SERVER;
    }

    $l->error("isAuthorizedApi() REST API is not working as expected. Got this HTTP response:\n".Data::Dumper::Dumper($httpResponse)."\nEO HTTP Response") if $l->is_error;
    SSAuthenticator::API::isMalfunctioning(ERR_SERVER);
    return ERR_SERVER; #For some reason server doesn't respond. Fall back to using cache.
}

# returns 1 on cache hit
sub checkCard_tryCache {
    my ($trans, $cardnumber) = @_;
    if (my $cache = db()->{$cardnumber}) {
        if ($cache->{access}) {
            $trans->cardAuthz($cache->{access});
            $trans->cardAuthzCacheUsed(1);
            $l->info("checkCard_tryCache($cardnumber) cache hit auth='".($trans->cardAuthz || '')."'");
            return 1;
        }
    }
    $trans->cardAuthzCacheUsed(0);
    return 0;
}

sub checkPIN {
    my ($trans, $cardnumber) = @_;
    $keyPad->_transaction_new();
    SSAuthenticator::OLED::showEnterPINMsg($trans);
    $keyPad->turnOn();
    while(defined($keyPad->wait_for_key())) {
        $trans->pinLatestKeyStatus($keyPad->maybe_transaction_complete());
        if    ($trans->pinLatestKeyStatus == $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_UNDERFLOW) {
            SSAuthenticator::OLED::showPINProgress($trans, $keyPad->{keys_read_idx}+1, $keyPad->{pin_progress_template});
        }
        elsif ($trans->pinLatestKeyStatus == $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_OVERFLOW) {
            SSAuthenticator::OLED::showPINProgress($trans, $keyPad->{keys_read_idx}+1, $keyPad->{pin_progress_template});
            SSAuthenticator::OLED::showPINStatusOverflow($trans);
            $trans->pinCode($keyPad->{key_buffer});
            $keyPad->turnOff();
            return $trans;
        }
        elsif ($trans->pinLatestKeyStatus == $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_MAYBE_DONE) {
            SSAuthenticator::OLED::showPINProgress($trans, $keyPad->{keys_read_idx}+1, $keyPad->{pin_progress_template});
            checkPIN_tryPIN($trans, $cardnumber, $keyPad->{key_buffer});
            if ($trans->pinAuthn > 0) {
                $trans->pinCode($keyPad->{key_buffer});
                SSAuthenticator::OLED::showPINStatusOKPIN($trans);
                $keyPad->turnOff();
                return $trans;
            }
        }
        elsif ($trans->pinLatestKeyStatus == $SSAuthenticator::Device::KeyPad::KEYPAD_TRANSACTION_DONE) {
            SSAuthenticator::OLED::showPINProgress($trans, $keyPad->{keys_read_idx}+1, $keyPad->{pin_progress_template});
            checkPIN_tryPIN($trans, $cardnumber, $keyPad->{key_buffer});
            if ($trans->pinAuthn > 0) {
                $trans->pinCode($keyPad->{key_buffer});
                SSAuthenticator::OLED::showPINStatusOKPIN($trans);
                $keyPad->turnOff();
                return $trans;
            }
            else {
                $trans->pinCode($keyPad->{key_buffer});
                SSAuthenticator::OLED::showPINStatusWrongPIN($trans);
                $keyPad->turnOff();
                return $trans;
            }
        }
    }
}

=head checkPIN_tryPIN

The cached PIN code is invalidated when it is inputted wrongly.

=cut

sub checkPIN_tryPIN {
    my ($trans, $cardnumber, $pin) = @_;
    $trans->pinAuthnCacheUsed(0);

    if (SSAuthenticator::API::isMalfunctioning()) { # Getting the card permissions from the API might have failed, then fall back to cache.
        checkPIN_tryCache($trans, $cardnumber, $pin);
        return;
    }
    try {
        $trans->pinAuthn(isAuthorizedApiPIN($cardnumber, $pin));
    } catch {
        $l->fatal("isAuthorizedApiPIN() died with error:\n".$l->flatten($_));
        $trans->pinAuthn(ERR_SERVER);
    };
    $l->info("isAuthorizedApiPIN() returns ".($trans->pinAuthn || ''));

    # Check if we got response from REST API
    if ($trans->pinAuthn == OK) {
        updateCache($trans, $cardnumber, undef, $pin);
        return;
    }
    elsif ($trans->pinAuthn == ERR_PINBAD || $trans->pinAuthn == ERR_PINTIMEOUT) {
        return;
    }
    else {
        checkPIN_tryCache($trans, $cardnumber, $pin);
        return;
    }
}

# returns 1 on cache hit
sub checkPIN_tryCache {
    my ($trans, $cardnumber, $pin) = @_;
    if (my $cache = db()->{$cardnumber}) {
        if ($cache->{pin}) {
            $trans->pinAuthn((SSAuthenticator::Password::check_password($cardnumber, $pin, $cache->{pin})) ? OK : ERR_PINBAD);
            $trans->pinAuthnCacheUsed(1);
            $l->info("checkPIN_tryCache($cardnumber) cache hit auth='".($trans->pinAuthn || '')."'");
            return 1;
        }
    }
    $trans->pinAuthnCacheUsed(0);
    return 0;
}

=head2 isAuthorizedApi

Connects to the Koha REST API to see if the cardnumber + PIN-code match

@PARAM1 String, cardnumber
@PARAM1 String, PIN
@RETURNS Integer, OK, if authorized
                  ERR_* if not

=cut

sub isAuthorizedApiPIN {
    my ($cardnumber, $pin) = @_;
    SSAuthenticator::API::isMalfunctioning(0);

    my ($httpResponse, $body, $err, $permission, $status) = SSAuthenticator::API::getPINResponse($cardnumber, $pin);

    if ($status eq 403) {
        SSAuthenticator::API::isMalfunctioning(ERR_API_AUTH);
        return ERR_API_AUTH;
    }
    elsif ($status eq 404) {
        return ERR_BADCARD;
    }
    elsif ($status =~ /^510/) { #Statuses starting with 510, LWP::UserAgent connectivity issues
        $l->error("isAuthorizedApiPIN($cardnumber) REST API cannot connect to server. Error:\n".$httpResponse->as_string) if $l->is_error;
        SSAuthenticator::API::isMalfunctioning(ERR_SERVERCONN);
        return ERR_SERVERCONN;
    }
    elsif ($status =~ /^5\d\d/) { #Statuses starting with 5, aka. Server errors.
        $l->error("isAuthorizedApiPIN($cardnumber) REST API returns server error:\n".$httpResponse->as_string) if $l->is_error;
        SSAuthenticator::API::isMalfunctioning(ERR_SERVER);
        return ERR_SERVER;
    }
    elsif ($status =~ /^2\d\d$/) {
        return $permission ? OK : ERR_PINBAD;
    }
    if ($status eq 401) {
        return ERR_PINBAD;
    }

    $l->error("isAuthorizedApiPIN() REST API is not working as expected. Got this HTTP response:\n".Data::Dumper::Dumper($httpResponse)."\nEO HTTP Response") if $l->is_error;
    SSAuthenticator::API::isMalfunctioning(ERR_SERVER);
    return ERR_SERVER; #For some reason server doesn't respond. Fall back to using cache.
}

sub grantAccess {
    my ($trans) = @_;
    my $doorOpenDuration = SSAuthenticator::Config::getDoorOpenDuration() / 1000; #Turn ms to seconds

    lockControl()->on();
    SSAuthenticator::Device::RGBLed::ledOn('green');

    SSAuthenticator::OLED::showAccessMsg($trans);
    SSAuthenticator::RTTTL::playAccessBuzz();

    #Wait for the specified amount of time to keep the door relay closed.
    #This can be used to keep the doors open longer, or to prolong the opening signal to a building automation system.
    Time::HiRes::sleep($doorOpenDuration) if ($doorOpenDuration > 0);
    lockControl()->off();

    my $signalingTimeLeft = 2 - $doorOpenDuration; # Make the RGB LED displays for atleast one second.
    Time::HiRes::sleep($signalingTimeLeft) if ($signalingTimeLeft > 0);
    SSAuthenticator::Device::RGBLed::ledOff('green');

    SSAuthenticator::RTTTL::maybePlayMelody();
}

sub denyAccess {
    my ($trans) = @_;

    SSAuthenticator::Device::RGBLed::ledOn('red');
    SSAuthenticator::OLED::showAccessMsg($trans);
    SSAuthenticator::RTTTL::playDenyAccessBuzz();

    # Make the LED display for atleast one second.
    Time::HiRes::sleep(2);

    SSAuthenticator::Device::RGBLed::ledOff('red');
}

sub updateCache {
    my ($trans, $cardnumber, $authStatus, $pin) = @_;
    $l->debug("updateCache() $cardnumber cached using".($authStatus ? " \$authStatus=$authStatus" : "").($pin ? " \$pin=*" : "")) if $l->is_debug;
    my $db = db();
    $db->{$cardnumber} = {} unless $db->{$cardnumber};
    $db->{$cardnumber}->{time} = localtime;
    if (defined($authStatus)) {
        $db->{$cardnumber}->{access} = $authStatus;
        $trans->cardCached(1);
    }
    if (defined($pin)) {
        $db->{$cardnumber}->{pin} = SSAuthenticator::Password::hash_password($pin, $cardnumber);
        $trans->pinCached(1);
    }
}

sub removeFromCache {
    my ($trans, $cardnumber, $authStatus, $pin) = @_;

    if (not($authStatus || $pin) || ($authStatus && $pin)) {
        $trans->cacheFlushed(1);
        $trans->cardCacheFlushed(1);
        $trans->pinCacheFlushed(1);
        return db()->delete($cardnumber);
    }
    if ($authStatus) {
        $trans->cardCacheFlushed(1);
        return db()->{$cardnumber}->delete('access');
    }
    if ($pin) {
        $trans->pinCacheFlushed(1);
        return db()->{$cardnumber}->delete('pin');
    }
}

sub controlAccess {
    my ($cardnumber, $trans) = @_;

    $l->info("main() Read barcode '$cardnumber'") if $l->is_info;
    SSAuthenticator::OLED::showBarcodePostReadMsg($trans, $cardnumber) if config()->param('OLED_ShowCardNumberWhenRead');
    #sleep 1; #DEBUG: Sleep a bit to make more sense out of the barcode on the OLED-display.

    isAuthorized($trans, $cardnumber);

    $l->info("controlAccess($cardnumber):> Access controls checked and auth=".$trans->auth) if $l->is_info;
    $l->debug("controlAccess($cardnumber):> Transaction=".$trans->statusesToString) if $l->is_debug;
    if ($trans->auth > 0) {
        grantAccess($trans);
    } else {
        denyAccess($trans);
    }
}

sub config {
    return SSAuthenticator::Config::getConfig();
}

sub main {
    local $/ = SSAuthenticator::BarcodeReader::getBarcodeSeparator();

    SSAuthenticator::I18n::setDefaultLanguage();
    SSAuthenticator::OLED::showInitializingMsg('STARTING');
    eval {
        SSAuthenticator::BarcodeReader::configureBarcodeScanner();
        SSAuthenticator::Device::RGBLed::init(config());
        $keyPad = SSAuthenticator::Device::KeyPad::init(config()) if (config()->param('RequirePIN'));
    };
    if ($@) {
        $l->fatal("$@");
        SSAuthenticator::OLED::showInitializingMsg('ERROR');
        exit(1);
    }

    $l->info("main() Entering main loop");
    SSAuthenticator::OLED::showInitializingMsg('FINISHED');
    while (1) {
        SSAuthenticator::Mailbox::checkMailbox();

        my $device = SSAuthenticator::BarcodeReader::GetReader();
        $l->error("main() No barcode reader attached") && exit(1) unless $device;

        $keyPad->flush_buffer() if $keyPad;

        my $cardnumber = SSAuthenticator::BarcodeReader::ReadBarcode($device, 30);
        if ($cardnumber) {
            chomp($cardnumber);
            eval {
                controlAccess($cardnumber, SSAuthenticator::Transaction->new());
            };
            if ($@) {
                $l->fatal("controlAccess($cardnumber) $@");
            }
        }
        SSAuthenticator::BarcodeReader::FlushBarcodeBuffers($device);
    }
}

1;
