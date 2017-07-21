#!/usr/bin/perl

# Copyright 2017 Koha-Suomi
# Copyright 2016 Vaara-kirjastot
#

use Modern::Perl;
use Carp;
use Getopt::Long qw(:config no_ignore_case);

my ($help, $verbose);
my ($device);
my @steps;

GetOptions(
    'h|help'                      => \$help,
    'v|verbose=i'                 => \$verbose,
    'd|device:s'                  => \$device,
    's|step:s'                    => \@steps,
);

$ENV{SSA_LOG_LEVEL} = $verbose if $verbose;

my $usage = <<USAGE;

SSAuthenticator barcode reader autoconfigurer

Instead of starting SSAuthenticator, simply do the barcode reader configuration.
This defaults to the /dev/barcodereader -device configured via udev-rules.

-v --verbose                 Integer, level of verbosity, how many levels to increase granularity from error?
                             4 is maximum log verbosity logging even trace-events
-h --help                    This nice help
-d --device                  Optionally one can give the barcode reader device directly,
                             eg. "/dev/ttyACM0"

Single configuration steps:

-s --step     Repeatable step to execute. Executed in the order given. Useful to test single
              configuration steps without running the whole configuration suite. Or to recover
              from a crashed configuration.
              Allowed steps are all the subroutine names inside SSAuthenticator::AutoConfigurer
              eg. --step setDeviceToServiceMode --step aimingAutoCalibration --step saveAndExitServiceMode

EXAMPLES

    barcodeReaderAutoConfigurer.pl --device /dev/ttyACM0 -v 3

    barcodeReaderAutoConfigurer.pl --device /dev/ttyACM1 -v 3 --step reload

USAGE

if ($help) {
  print $usage;
  exit 0;
}

require SSAuthenticator::AutoConfigurer;
my $ac = SSAuthenticator::AutoConfigurer->new($device);


if (scalar(@steps)) {
  eval {
    foreach my $step (@steps) {
      $ac->execStep($step);
    }
  };
  if ($@) {
    warn $@;
    $ac->exitServiceMode();
  }
}
else {
  $ac->configure();
}


