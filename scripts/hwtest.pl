#!/bin/perl

use Modern::Perl;

use JSON::XS;
use Data::Printer;
use HiPi qw( :rpi );
use HiPi::Device::GPIO;
use Time::HiRes;

my $ssauthc = JSON::XS::decode_json(`/home/toveri/SSAuthenticator/scripts/ssauthenticator --get-config`);
my $heaterc = JSON::XS::decode_json(`/home/toveri/emb-heater/scripts/heater --get-config`);
my $tamperc = JSON::XS::decode_json(`/home/toveri/emb-tamper/scripts/tamper --get-config`);

Data::Printer::p($ssauthc);
Data::Printer::p($heaterc);
Data::Printer::p($tamperc);

my $gpio =  HiPi::Device::GPIO->new;


my @gpioTogglePinOrder = (
  $ssauthc,'DoorPin',
  $ssauthc,'DoorOffPin',
  $ssauthc,'RedLEDPin',
  $ssauthc,'GreenLEDPin',
  $ssauthc,'BlueLEDPin',
  $ssauthc,'PINOnPin',
  $ssauthc,'PINOffPin',
  $heaterc,'SwitchOnRelayBCMPin',
  $heaterc,'SwitchOffRelayBCMPin',
);
loopTuples(\@gpioTogglePinOrder, sub {
  my ($conf, $key, $i) = @_;
  $gpio->export_pin($conf->{$key});
  $gpio->set_pin_mode($conf->{$key}, RPI_MODE_OUTPUT);
});


my @gpioPinReadOrder = (
  $tamperc,'DoorPin',
);
loopTuples(\@gpioPinReadOrder, sub {
  my ($conf, $key, $i) = @_;
  $gpio->export_pin($conf->{$key});
  $gpio->set_pin_mode($conf->{$key}, RPI_MODE_INPUT);
});







my $pollIndex = 0;

sub printPins {
  my $output = readPins(\@gpioPinReadOrder);
  print(join(" ",@$output)."\n");
  $output = readPins(\@gpioTogglePinOrder);
  print(join(" ",@$output)."\n");
}

sub readPins {
  my ($gpioPinsConfs) = @_;
  my @output;
  loopTuples($gpioPinsConfs, sub {
    my ($conf, $key, $i) = @_;
    push(@output, $key);
    my $l = $gpio->get_pin_level($conf->{$key});
    push(@output, ($l) ? "<$l>".(' 'x(length($key)-3)) : $l.(' 'x(length($key)-1)))
  });
  return \@output;
}

sub pollPins {
  my ($gpioTogglePinOrder) = @_;
  loopTuples($gpioTogglePinOrder, sub {
    my ($conf, $key, $i) = @_;
    $gpio->set_pin_level($conf->{$key}, 1);
    printPins();
    Time::HiRes::sleep(0.5);
    $gpio->set_pin_level($conf->{$key}, 0);
    printPins();
    Time::HiRes::sleep(0.5);
  });
}

sub loopTuples {
  my ($ary, $callback) = @_;
  for (my $i=0 ; $i<@$ary ; $i=$i+2) {
    $callback->($ary->[$i], $ary->[$i+1], $i);
  }
}

pollPins(\@gpioTogglePinOrder);

