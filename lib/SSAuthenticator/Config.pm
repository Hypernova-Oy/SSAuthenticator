# Copyright (C) 2016-2017 Koha-Suomi
#
# This file is part of SSAuthenticator.


package SSAuthenticator::Config;

use Modern::Perl;

use Config::Simple;
use Data::Dumper;
use Log::Log4perl;


=head1 SSAuthenticator::Config

Manage configuration for this daemon

=cut

my $l; #Package logger

my $config;
my $configFile = "/etc/ssauthenticator/daemon.conf";
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
        $config = new Config::Simple($configFile)
            || die Config::Simple->error(), ".\n",
            "Please check the syntax in /etc/ssauthenticator/daemon.conf.";
        _isConfigValid($config);
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

sub initLogger {
    my ($log4perlConfig, $verbose) = @_;
    Log::Log4perl->init_and_watch($log4perlConfig, 10);

    $verbose = $ENV{SSA_LOG_LEVEL} if (defined($ENV{SSA_LOG_LEVEL}));
    Log::Log4perl->appender_thresholds_adjust($verbose);

    $l = Log::Log4perl->get_logger() unless $l;
}

sub _isConfigValid() {
    my ($c) = @_;
    my $returnValue = 1;

    my @pwuid = getpwuid($<);

    ##Log4perlConfig first so we can instantiate it
    my $log4perlConfig = $c->param('Log4perlConfig');
    if (not($log4perlConfig)) {
        die "Log4perlConfig is undefined!";
    }
    elsif (! -e $log4perlConfig) {
        die "Log4perlConfig '$log4perlConfig' doesn't exist";
        $returnValue = 0;
    }
    elsif (! -r $log4perlConfig) {
        die "Log4perlConfig '$log4perlConfig' is not readable by ".($pwuid[0] || $pwuid[1]);
        $returnValue = 0;
    }
    initLogger($log4perlConfig, $c->param('Verbose') || 0);

    ##All mandatory params
    my @params = ('ApiBaseUrl', 'LibraryName', 'ApiUserName', 'ApiKey',
                  'RedLEDPin', 'BlueLEDPin', 'GreenLEDPin', 'DoorPin',
                  'RTTTL-PlayerPin', 'Verbose', 'RandomGreetingChance',
                  'DefaultLanguage', 'MailboxDir', 'Log4perlConfig',
                  'ConnectionTimeout');
    foreach my $param (@params) {
        if (not(defined($c->param($param)))) {
            $l->error("$param not defined in daemon.conf") if $l->is_error();
            $returnValue = 0;
        }
    }

    ##ConnectionTimeout
    my $timeout = $c->param("ConnectionTimeout") || '';
    if (not($timeout) || not($timeout =~ /\d+/)) {
        my $reason = "ConnectionTimeout '$timeout' is invalid. " .
            "Valid value is an integer.";
        $l->error($reason) if $l->is_error;
        $returnValue = 0;
    } elsif ($timeout > 30000) {
        my $reason = "ConnectionTimeout '$timeout' is too big. Max 30000 ms";
        $l->error($reason) if $l->is_error;
        $returnValue = 0;
    }

    ##MailboxDir
    my $mailboxDir = $c->param('MailboxDir');
    if    (! -e $mailboxDir) {
        if (! mkdir($mailboxDir)) {
            $l->error("Directory 'MailboxDir' '$mailboxDir' doesn't exist and cannot be created '$!'") if $l->is_error;
            $returnValue = 0;
        }
        else {
            $l->info("Directory 'MailboxDir' '$mailboxDir' created for your convenience") if $l->is_info;
        }
    }
    if (! -d $mailboxDir) {
        $l->error("Directory 'MailboxDir' '$mailboxDir' is not a directory") if $l->is_error;
        $returnValue = 0;
    }
    elsif (! -w $mailboxDir) {
        $l->error("Directory 'MailboxDir' '$mailboxDir' is not writable by ".($pwuid[0] || $pwuid[1])) if $l->is_error;
        $returnValue = 0;
    }
    elsif (! -r $mailboxDir) {
        $l->error("Directory 'MailboxDir' '$mailboxDir' is not readable by ".($pwuid[0] || $pwuid[1])) if $l->is_error;
        $returnValue = 0;
    }
    elsif (! -x $mailboxDir) {
        $l->error("Directory 'MailboxDir' '$mailboxDir' is not executable by ".($pwuid[0] || $pwuid[1])) if $l->is_error;
        $returnValue = 0;
    }

    return $returnValue;
}

1;
