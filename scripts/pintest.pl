#!/usr/bin/env perl

use Modern::Perl;

use Getopt::Long qw(:config no_ignore_case);

use SSAuthenticator;
use SSAuthenticator::Device::KeyPad;
use SSAuthenticator::Config;

my $help;
my $barcode = "1234";
my $show = 'last';

GetOptions(
    'h|help'                      => \$help,
    'b|barcode:s'                 => \$barcode,
    's|show:s'                    => \$show,
);

my $usage = <<USAGE;

  -h --help  HELP!
  -b         Barcode to use with the PIN code entry authentication step.
  -s --show  [hide,show,last] How to show the PIN character on the OLED? Defaults to 'last'.

USAGE

if ($help) {
  print $usage;
  exit 0;
}

SSAuthenticator::Config::getConfig()->param('PINDisplayStyle', 'last');

my $trans = SSAuthenticator::Transaction->new();
$SSAuthenticator::keyPad = SSAuthenticator::Device::KeyPad::init(
  SSAuthenticator::Config::getConfig()
);

eval {
  SSAuthenticator::checkPIN(
    $trans,
    $barcode,
  );
};
if ($@) {
  print $@."\n";
}

$SSAuthenticator::keyPad->turnOff();

print "PIN code transaction's OLED messages:\n".Data::Dumper::Dumper($trans->oledMessages);
