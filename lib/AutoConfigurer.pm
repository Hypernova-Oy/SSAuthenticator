#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of Authenticator.
#
# Authenticator is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Authenticator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Authenticator.  If not, see <http://www.gnu.org/licenses/>.

package AutoConfigurer;

use Modern::Perl;
use Sys::Syslog qw(:standard :macros);

sub new {
    my ($class) = @_;
    my $self = {};

    $self->{scannerPath} = "/dev/barcodescanner";
    open(my $scanner, ">", $self->{scannerPath});
    $self->{scanner} = $scanner;

    return bless($self, $class);
}

sub configure {
    my ($self) = @_;
    setDeviceToServiceMode($self);
    configureSettings($self);
    saveAndExitServiceMode($self);
}

sub configureSettings {
    my ($self) = @_;
    setTerminatorToLF($self);
    setCrossHair($self);
}
sub saveAndExitServiceMode {
    my ($self) = @_;
    my $scanner = $self->{scanner};
    print $scanner '\$Ar\r';
    sleep 1;
    setDeviceToNormalMode($self);
}

sub setTerminatorToLF {
    my ($self) = @_;
    my $scanner = $self->{scanner};
    print $scanner '\$CLFSU0D00000000000000000000000000000000000000\r';
    sleep 3;
}

sub setCrossHair {
    my ($self) = @_;
    my $scanner = $self->{scanner};
    print $scanner '\$FA03760240\r';
    sleep 3;
}

sub setDeviceToNormalMode {
    my ($self) = @_;
    my $path = $self->{scannerPath};
    system("stty -F $self->{scannerPath} 9600")
	|| exitWithReason("Couldn't set scanner's baudrate to 9600");
}

sub setDeviceToServiceMode {
    my ($self) = @_;
    sendServiceModeSignal($self);
    setServiceModeBaudRate($self);
}

sub sendServiceModeSignal {
    my ($self) = @_;
    my $scanner = $self->{scanner};
    print $scanner '\$S\r';
    sleep 1;
}

sub setServiceModeBaudRate {
    my ($self) = @_;
    system("stty -F $self->{scannerPath} 115200") == 0
	|| exitWithReason("Couldn't set scanner's baudrate to 115200");
    sleep 1;
}

sub notifyAboutError {
    my ($reason) = @_;
    say $reason;
    syslog(LOG_ERR, $reason);
}

sub exitWithReason {
    my ($reason) = @_;
    notifyAboutError($reason);
    exit(1);
}


sub main {
    my $configurer = AutoConfigurer->new;
    $configurer->configure();
    say "Device configured succesfully!";
}

__PACKAGE__->main() unless caller;

1;
