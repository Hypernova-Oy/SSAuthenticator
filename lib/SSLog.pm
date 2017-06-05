# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SSAuthenticator.

package SSLog;

use Modern::Perl;
use Carp qw(longmess);
use Scalar::Util qw(blessed);
use Data::Alias;

use Log::Log4perl;
our @ISA = qw(Log::Log4perl);
Log::Log4perl->wrapper_register(__PACKAGE__);

#use SSAuthenticator::Config;

sub AUTOLOAD {
    my $l = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*://;
    unless (blessed($l)) {
         longmess "SSLog invoked with an unblessed reference??";
    }
    unless ($l->{_log}) {
        my $log = get_logger($l);
        $l->{_log} = $log;
    }
    return $l->{_log}->$method(@_);
}

sub get_logger {
#    warn "get_logger\n";
    my $l = shift;
    initLogger() unless Log::Log4perl->initialized();
    return Log::Log4perl->get_logger();
}

sub initLogger {
    my $config = SSAuthenticator::Config::getConfig();
    my $l4pf = $config->param('Log4perlConfig');

    #Incredible! The config file cannot be properly read unless it is somehow fiddled with from the operating system side.
    #Mainly fixes t/10-permissions.b.t
    #Where the written temp log4perl-config file cannot be read by Log::Log4perl
    `/usr/bin/touch $l4pf` if -e $l4pf;

#print Data::Dumper::Dumper($config);
#use File::Slurp;
#warn File::Slurp::read_file($config->param('Log4perlConfig'));
#$DB::single=1;
#sleep 1;

    Log::Log4perl->init_and_watch($l4pf, 10);
    my $verbose = $ENV{SSA_LOG_LEVEL} || $config->param('Verbose');
    Log::Log4perl->appender_thresholds_adjust($verbose);
}

1;
