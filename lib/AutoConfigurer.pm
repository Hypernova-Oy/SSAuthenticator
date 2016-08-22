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
use Device::SerialPort qw( :PARAM :STAT 0.07 );

sub new {
    my ($class) = @_;
    my $self = {};

    $self->{scanner} = new Device::SerialPort ("/dev/barcodescanner", 1)
	|| exitWithReason("No barcodescanner detected");
    $self->{scanner}->baudrate(9600);
    $self->{scanner}->parity("odd");
    $self->{scanner}->databits(8);
    $self->{scanner}->stopbits(1);

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
    logMessage("Configuring scanner's settings");
    setTerminatorToLF($self);
    setCrossHair($self);
    setAutomaticOperatingMode($self);
}
sub saveAndExitServiceMode {
    my ($self) = @_;
    logMessage("saving scanner's settings and entering normal mode");
    my $scanner = $self->{scanner};

    writeCmd($self, "\$Ar\r");

    sleep 3; # exiting service mode takes some time

    $scanner->baudrate(9600);
}

sub isDataWritten {
    my ($bytesWritten, $sentData) = @_;
    return $bytesWritten == length($sentData);
}

sub setTerminatorToLF {
    my ($self) = @_;
    logMessage("Setting scanner's LF character to \\n");
    writeCmd($self, "\$CLFSU0D00000000000000000000000000000000000000\r");
}

sub setCrossHair {
    my ($self) = @_;
    logMessage("Setting scanner's crosshair");
    writeCmd($self, "\$FA03760240\r");
}

sub setAutomaticOperatingMode {
    my ($self) = @_;
    logMessage("Setting 'automatic' operating mode");
    writeCmd($self, "\$CSNRM02\r");
}
sub writeCmd {
    my ($self, $cmd) = @_;
    if (!isDataWritten($self->{scanner}->write($cmd), $cmd)) {
        exitWithReason("Data not written");
    }
    sleep 1;
}

sub setDeviceToServiceMode {
    my ($self) = @_;
    logMessage("Setting scanner to service mode");
    sendServiceModeSignal($self);

    logMessage("Setting baudrate for service mode");
    $self->{scanner}->baudrate(115200);
}

sub sendServiceModeSignal {
    my ($self) = @_;
    writeCmd($self, "\$S\r");
    sleep 3;
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

sub logMessage {
    my ($message) = @_;
    say $message;
}

sub main {
    my $configurer = AutoConfigurer->new;
    $configurer->configure();
    $configurer->{scanner}->close() || exitWithReason("closing barcode scanner failed");
    logMessage("Device configured succesfully!");
}

__PACKAGE__->main() unless caller;

1;
