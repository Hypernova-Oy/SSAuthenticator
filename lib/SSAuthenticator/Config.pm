# Copyright (C) 2016-2017 Koha-Suomi
#
# This file is part of SSAuthenticator.


package SSAuthenticator::Config;

use Modern::Perl;

use Config::Simple;
use Data::Dumper;
use Try::Tiny;

use SSAuthenticator::Pragmas;

use SSAuthenticator::Exception::BadConfiguration;


our @supportedBarcodeReaderModels = qw(GFS4400 WGC300UsbAT);
my $config;
my $configFile = "/etc/ssauthenticator/daemon.conf";
my $l = bless({}, 'SSLog');



=head1 SSAuthenticator::Config

Manage configuration for this daemon

=cut

sub setConfigFile {
    my ($overloadedConfigFile) = @_;
    my $oldConfigFile = $configFile;
    $configFile = $overloadedConfigFile;
    return $oldConfigFile;
}

=head2 getConfig

Reads the config file and returns it.

@Returns Config::Simple
@Throws die if Config::Simple has issues

=cut

sub getConfig {
    unless ($config) {
        eval {
            $configFile = $ENV{SSAUTHENTICATOR_CONFIG} if $ENV{SSAUTHENTICATOR_CONFIG};
            $config = new Config::Simple($configFile);
        };
        if ($@ || Config::Simple->error()) {
            my @errs;
            push(@errs, $@) if $@;
            push(@errs, Config::Simple->error()) if Config::Simple->error();
            push(@errs, "\$configFile '$configFile' doesn't exists!") unless -e $configFile;
            push(@errs, "\$configFile '$configFile' is not readable!") unless -r $configFile;
            die "FATAL: getConfig() '".join("\n",@errs)."'\nPlease check the syntax in '$configFile'";
        }

        die "daemon.conf is invalid. See STDERR." unless(_isConfigValid($config));
    }
    return $config;
}

sub getConfigFile {
    return $configFile;
}

=head2 unloadConfig

Flushes the config so it must be reread.

=cut

sub unloadConfig {
    $config = undef;
}

sub _isConfigValid {
    my ($c) = @_;
    my $returnValue = 1;

    my @pwuid = getpwuid($<);

    ##All mandatory params
    my @params = ('ApiBaseUrl', 'ApiUserName',
                  'RedLEDPin', 'BlueLEDPin', 'GreenLEDPin', 'DoorPin', 'DoorOffPin',
                  'Verbose', 'RandomGreetingChance',
                  'DefaultLanguage', 'MailboxDir', 'Log4perlConfig',
                  'OpeningHoursDBFile',
                  'ConnectionTimeout', 'DoorOpenDuration',
                  'OLED_ShowCardNumberWhenRead', 'BarcodeReaderModel',
                  'DoubleReadTimeout', 'Code39DecodingLevel', 'RequirePIN', 'PINLength', 'PINLengthMin', 'PINTimeout', 'PINOnPin', 'PINOffPin',
                  'PINCodeEnterKey', 'PINCodeResetKey');
                  # Not mandatory anymore
                  # 'LibraryName',
    foreach my $param (@params) {
        if (not(defined($c->param($param)))) {
            warn "$param not defined in daemon.conf";
            $returnValue = 0;
        }
    }

    ##Log4perlConfig first so we can instantiate it
    my $log4perlConfig = $c->param('Log4perlConfig');
    if (not($log4perlConfig)) {
        warn "Log4perlConfig is undefined!";
    }
    elsif (! -e $log4perlConfig) {
        warn "Log4perlConfig '$log4perlConfig' doesn't exist";
        $returnValue = 0;
    }
    elsif (! -r $log4perlConfig) {
        warn "Log4perlConfig '$log4perlConfig' is not readable by ".($pwuid[0] || $pwuid[1]);
        $returnValue = 0;
    }

    ##ConnectionTimeout
    my $timeout = $c->param("ConnectionTimeout") || '';
    if (not($timeout) || not($timeout =~ /\d+/)) {
        my $reason = "ConnectionTimeout '$timeout' is invalid. " .
            "Valid value is an integer.";
        warn $reason;
        $returnValue = 0;
    } elsif ($timeout > 30000) {
        my $reason = "ConnectionTimeout '$timeout' is too big. Max 30000 ms";
        warn $reason;
        $returnValue = 0;
    }

    try {
        setDoorOpenDuration($c->param("DoorOpenDuration"));
    } catch {
        warn $_;
        $returnValue = 0;
    };

    ##MailboxDir
    my $mailboxDir = $c->param('MailboxDir');
    if    (! -e $mailboxDir) {
        if (! mkdir($mailboxDir)) {
            warn "Directory 'MailboxDir' '$mailboxDir' doesn't exist and cannot be created '$!'";
            $returnValue = 0;
        }
        else {
            warn "Directory 'MailboxDir' '$mailboxDir' created for your convenience";
        }
    }
    if (! -d $mailboxDir) {
        warn "Directory 'MailboxDir' '$mailboxDir' is not a directory";
        $returnValue = 0;
    }
    elsif (! -w $mailboxDir) {
        warn "Directory 'MailboxDir' '$mailboxDir' is not writable by ".($pwuid[0] || $pwuid[1]);
        $returnValue = 0;
    }
    elsif (! -r $mailboxDir) {
        warn "Directory 'MailboxDir' '$mailboxDir' is not readable by ".($pwuid[0] || $pwuid[1]);
        $returnValue = 0;
    }
    elsif (! -x $mailboxDir) {
        warn "Directory 'MailboxDir' '$mailboxDir' is not executable by ".($pwuid[0] || $pwuid[1]);
        $returnValue = 0;
    }

    ##BarcodeReaderModel
    my $brm = $c->param('BarcodeReaderModel');
    unless (grep {$brm eq $_} @supportedBarcodeReaderModels) {
        warn "BarcodeReaderModel '$brm' is not supported. Supported models: [@supportedBarcodeReaderModels]";
        $returnValue = 0;
    }

    #PINValidatorRegexp
    my $pvr = $c->param('PINValidatorRegexp');
    unless ($pvr) {
        $pvr = '^\d+$';
        print "Param 'PINValidatorRegexp' is not defined. Defaulting to '$pvr'.";
    }
    $c->{PINValidatorRegexp} = qr/$pvr/;

    #PINDisplayStyle
    $c->param('PINDisplayStyle', 'hide') unless ($c->param('PINDisplayStyle'));
    unless ($c->param('PINDisplayStyle') eq 'hide' || $c->param('PINDisplayStyle') eq 'show' || $c->param('PINDisplayStyle') eq 'last') {
        warn "Param 'PINDisplayStyle' value '".$c->param('PINDisplayStyle')."' is not one of [hide, show, last]. Defaulting to 'hide'.";
        $c->param('PINDisplayStyle', 'hide');
    }

    #OLED_ShowCardNumberWhenRead
    my $char = substr ($c->param('OLED_ShowCardNumberWhenRead'), 0, 1);
    if ($char eq 'b' || $char eq 'm' || $char eq 'h') {
        $c->param('OLED_ShowCardNumberWhenRead', $char);
    }
    else {
        warn "Param 'OLED_ShowCardNumberWhenRead'='".$c->param('OLED_ShowCardNumberWhenRead')."' is invalid. First character not one of [bmh]! Defaulting to 'h'.";
        $c->param('OLED_ShowCardNumberWhenRead', 'h');
    }

    return $returnValue;
}

sub logConfigFromSignal {
    my $d = Data::Dumper->new([getConfig()],[]);
    $d->Sortkeys(1);
    $l->info($d->Dump());
}


############################################################
#### #### ####        Config accessors        #### #### ####
############################################################

sub getTimeout() {
    return getConfig()->param('ConnectionTimeout');
}
sub getTimeoutInSeconds {
    return getTimeout() / 1000;
}
sub setDoorOpenDuration {
    my ($doorOpenDuration) = @_;
    if (not($doorOpenDuration) || not($doorOpenDuration =~ /\d+/)) {
        my $reason = "DoorOpenDuration '$doorOpenDuration' is invalid. " .
            "Valid value is an integer.";
        SSAuthenticator::Exception::BadConfiguration->throw(error => $reason);
    } elsif ($doorOpenDuration > 120000) {
        my $reason = "DoorOpenDuration '$doorOpenDuration' is too big. Max 120000 ms";
        SSAuthenticator::Exception::BadConfiguration->throw(error => $reason);
    } elsif ($doorOpenDuration < 500) {
        my $reason = "DoorOpenDuration '$doorOpenDuration' is too small. Min 500 ms";
        SSAuthenticator::Exception::BadConfiguration->throw(error => $reason);
    }
    getConfig()->param('DoorOpenDuration', $doorOpenDuration);
    return getConfig()->param('DoorOpenDuration');
}
sub getDoorOpenDuration {
    return getConfig()->param('DoorOpenDuration');
}
sub doRandomMelody {
    return 1 if (int(rand(100)) < (getConfig()->param('RandomMelodyChance') || 1));
    return 0;
}
sub getRandomMelodySelector {
    return getConfig()->param('RandomMelodySelector') || '^Abba';
}
sub oledShowCardNumberWhenRead {
    return getConfig()->param('OLED_ShowCardNumberWhenRead');
}
sub pinCodeEnterKey {
    return getConfig()->param('PINCodeEnterKey');
}
sub pinCodeResetKey {
    return getConfig()->param('PINCodeResetKey');
}
sub pinDisplayStyle {
    return getConfig()->param('PINDisplayStyle');
}
sub pinValidatorRegexp {
    return getConfig()->{'PINValidatorRegexp'};
}
sub pinShowExtraLight {
    return getConfig()->param('PINShowExtraLight');
}
1;
