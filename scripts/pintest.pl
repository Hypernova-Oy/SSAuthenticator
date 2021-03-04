#!/usr/bin/env perl

use Modern::Perl;

use Getopt::Long qw(:config no_ignore_case);

use SSAuthenticator;
use SSAuthenticator::Device::KeyPad;
use SSAuthenticator::Config;

my $help;
my $barcode = "1234";

GetOptions(
    'h|help'                      => \$help,
    'b|barcode:s'                 => \$barcode,
);

my $usage = <<USAGE;

  -h --help  HELP!
  -b         Barcode to use with the PIN code entry authentication step.

USAGE

if ($help) {
  print $usage;
  exit 0;
}


$SSAuthenticator::keyPad = SSAuthenticator::Device::KeyPad::init(
  SSAuthenticator::Config::getConfig()
);

SSAuthenticator::checkPIN(
  SSAuthenticator::Transaction->new(),
  $barcode,
);

$SSAuthenticator::keyPad->turnOff();

