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

#use File::Slurp;
#warn $config->param('Log4perlConfig');
#warn File::Slurp::read_file($config->param('Log4perlConfig'));
#$DB::single=1;
#sleep 1;
    Log::Log4perl->init_and_watch($config->param('Log4perlConfig'), 10);
    my $verbose = $ENV{SSA_LOG_LEVEL} || $config->param('Verbose');
    Log::Log4perl->appender_thresholds_adjust($verbose);
}

1;
