# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SSAuthenticator.

package SSLog;

use Modern::Perl;
use Scalar::Util qw(blessed);

use Log::Log4perl;
our @ISA = qw(Log::Log4perl);
Log::Log4perl->wrapper_register(__PACKAGE__);

use SSAuthenticator::Config;

sub AUTOLOAD {
    unless (blessed($_[0])) {
        
    }
}

sub get_logger {
    initLogger() unless Log::Log4perl->initialized();
    return shift->SUPER(@_);
}

sub initLogger {
    my $config = SSAuthenticator::Config::getConfig();
    my ($log4perlConfig, $verbose) = @_;
    Log::Log4perl->init_and_watch($config->param('Log4perlConfig'), 10);

    $verbose = $ENV{SSA_LOG_LEVEL} || $config->param('Verbose');
    Log::Log4perl->appender_thresholds_adjust($verbose);
}

1;
