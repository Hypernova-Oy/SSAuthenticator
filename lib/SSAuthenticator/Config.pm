# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.


package SSAuthenticator::Config;

use Modern::Perl;

use Config::Simple;
use Data::Dumper;
use Log::Log4perl qw(:easy);


=head1 SSAuthenticator::Config

Manage configuration for this daemon

=cut

Log::Log4perl->easy_init($ERROR);

my $config;
my $configFile = "/etc/ssauthenticator/daemon.conf";
sub setConfigFile {
    my ($overloadedConfigFile) = @_;
    my $oldConfigFile = $configFile;
    $configFile = $overloadedConfigFile;
    return $oldConfigFile;
}

=head2 getConfig

Rereads the config file and

@Returns Config::Simple
@Throws die if Config::Simple has issues

=cut

sub getConfig {
    $config = new Config::Simple($configFile)
    || die Config::Simple->error(), ".\n",
    "Please check the syntax in /etc/ssauthenticator/daemon.conf."
        unless $config;
    return $config;
}

sub getConfigFile {
    return $configFile;
}

sub unloadConfig {
    $config = undef;
}


sub isConfigValid() {
    my $returnValue = 1;

    my @pwuid = getpwuid($<);

    my @params = ('ApiBaseUrl', 'LibraryName', 'ApiUserName', 'ApiKey', 'RedLEDPin', 'BlueLEDPin', 'GreenLEDPin', 'DoorPin', 'RTTTL-PlayerPin', 'Verbose', 'RandomGreetingChance', 'DefaultLanguage', 'MailboxDir');
    my $c = getConfig();
    foreach my $param (@params) {
        if (not(defined($c->param($param)))) {
            ERROR "$param not defined in daemon.conf";
            $returnValue = 0;
        }
    }

    my $timeout = $c->param("ConnectionTimeout");
    if (!$timeout) {
        return $returnValue;
    } elsif (!($timeout =~ /\d+/)) {
        my $reason = "ConnectionTimeout value is invalid. " .
            "Valid value is an integer.";
        ERROR $reason;
        $returnValue = 0;
    } elsif ($timeout > 30000) {
        my $reason = "ConnectionTimeout value is too big. Max 30000 ms";
        ERROR $reason;
        $returnValue = 0;
    }

    my $mailboxDir = $c->param('MailboxDir');
    if    (! -e $mailboxDir) {
        ERROR "Directory 'MailboxDir' '$mailboxDir' doesn't exist";
        $returnValue = 0;
    }
    elsif (! -d $mailboxDir) {
        ERROR "Directory 'MailboxDir' '$mailboxDir' is not a directory";
        $returnValue = 0;
    }
    elsif (! -w $mailboxDir) {
        ERROR "Directory 'MailboxDir' '$mailboxDir' is not writable by ".($pwuid[0] || $pwuid[1]);
        $returnValue = 0;
    }
    elsif (! -r $mailboxDir) {
        ERROR "Directory 'MailboxDir' '$mailboxDir' is not readable by ".($pwuid[0] || $pwuid[1]);
        $returnValue = 0;
    }
    elsif (! -x $mailboxDir) {
        ERROR "Directory 'MailboxDir' '$mailboxDir' is not executable by ".($pwuid[0] || $pwuid[1]);
        $returnValue = 0;
    }

    return $returnValue;
}

1;
