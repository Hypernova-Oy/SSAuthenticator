#!/usr/bin/perl
# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator::Lock;

=encoding utf8

=head1 NAME

    SSAuthenticator::Lock - Lock to control

=head1 DESCRIPTION

    Controls the interface to the lock this Toveri manages access for.
    Supports both single-latch and dual-latch relays.

=cut

use Modern::Perl;

use Scalar::Util qw(blessed);
use Try::Tiny;
use Data::Printer;
use Time::HiRes;

use GPIO::Relay;
use GPIO::Relay::DoubleLatch;
use GPIO::Relay::SingleLatch;

use SSAuthenticator::Config;
use SSLog;

my $l = bless({}, 'SSLog');

sub new {
    my ($class, $onPin, $offPin) = @_;
    my $c = SSAuthenticator::Config::getConfig();
    $onPin  = $c->param('DoorPin')    unless (defined($onPin));
    $offPin = $c->param('DoorOffPin') unless (defined($offPin));

    my $self = bless({}, $class);
    if (defined($onPin) && defined($offPin)) { # Dual-latch relay requested
        $self->{relay} = GPIO::Relay::DoubleLatch->new($onPin, $offPin);
    }
    else { # Single-latch relay requested
        $self->{relay} = GPIO::Relay::SingleLatch->new($onPin);
    }

    return $self;
}

sub relay {
  return $_[0]->{relay};
}

sub on {
  my ($self) = @_;
  $self->{relay}->switchOn();
  return 1;
}

sub off {
  my ($self) = @_;
  $self->{relay}->switchOff();
  return 1;
}

1;
