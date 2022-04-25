#!/usr/bin/perl

# Copyright 2022 Hypernova Oy
#

use Modern::Perl;
use Carp;
use Data::Printer;
use Getopt::Long qw(:config no_ignore_case);

my ($help, $read, $write, $verbose);

GetOptions(
    'v|verbose=i'                 => \$verbose,
    'r|read'                      => \$read,
    'w|write'                     => \$write,
    'h|help'                      => \$help,
);

$ENV{SSA_LOG_LEVEL} = $verbose if $verbose;

my $usage = <<USAGE;

SSAuthenticator barcode reader test bench

  -h --help               HELP!
  -r --read               Read barcodes until SIGINT
  -w --write              Write command RV (check version) until SIGINT
  -v --verbose            Int, sets the verbosity level:
                            -1 less verbose
                            2  most verbose

EXAMPLES

    #Test error handling when writing to the device. Run this command and re-plug the device. Program should reconnect to the device after plugging it back.
    bctest.pl --write
    bctest.pl --read

USAGE

if ($help) {
  print $usage;
  exit 0;
}


require SSAuthenticator::Config;
require SSAuthenticator::Device::WGC300UsbAT;
my $r = $SSAuthenticator::Device::WGC300UsbAT::reader;
p($r);

while ($write) {
  eval {
    $r->autorecoverFromError() if $r->{_err};
    print("Getting device version:\n");
    p($r->sendCommand('RV'));
  };
  if ($@) {
    p($@);
  }
}

while ($read) {
  eval {
    $r->autorecoverFromError() if $r->{_err};
    print("Polling for barcode:\n");
    p($r->pollData(2));
  };
  if ($@) {
    p($@);
  }
}
