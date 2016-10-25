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


sub isConfigValid() {
    my $returnValue = 1;

    my @params = ('ApiBaseUrl', 'LibraryName', 'ApiUserName', 'ApiKey', 'RedLEDPin', 'BlueLEDPin', 'GreenLEDPin', 'DoorPin', 'RTTTL-PlayerPin', 'Verbose');
    foreach my $param (@params) {
        if (not(defined(getConfig()->param($param)))) {
            ERROR "$param not defined in daemon.conf";
            $returnValue = 0;
        }
    }

    my $timeout = getConfig()->param("ConnectionTimeout");
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

    return $returnValue;
}

1;
