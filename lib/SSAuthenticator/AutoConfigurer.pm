#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator::AutoConfigurer;

use Modern::Perl;
use Sys::Syslog qw(:standard :macros);
use Device::SerialPort qw( :PARAM :STAT 0.07 );

sub new {
    my ($class) = @_;
    my $self = {};

    $self->{scanner} = new Device::SerialPort ("/dev/barcodescanner", 1)
	|| die("No barcodescanner detected");
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
    $self->{scanner}->close()
	|| die("closing barcode scanner failed");
}

sub configureSettings {
    my ($self) = @_;
    syslog(LOG_INFO, "Configuring scanner's settings");
    setTerminatorToLF($self);
    setCrossHair($self);
    setAutomaticOperatingMode($self);
}
sub saveAndExitServiceMode {
    my ($self) = @_;
    syslog(LOG_INFO, "saving scanner's settings and entering normal mode");
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
    syslog(LOG_INFO, "Setting scanner's LF character to \\n");
    writeCmd($self, "\$CLFSU0A00000000000000000000000000000000000000\r");
}

sub setCrossHair {
    my ($self) = @_;
    syslog(LOG_INFO, "Setting scanner's crosshair");
    writeCmd($self, "\$FA03760240\r");
}

sub setAutomaticOperatingMode {
    my ($self) = @_;
    syslog(LOG_INFO, "Setting 'automatic' operating mode");
    writeCmd($self, "\$CSNRM02\r");
}
sub writeCmd {
    my ($self, $cmd) = @_;
    if (!isDataWritten($self->{scanner}->write($cmd), $cmd)) {
        die("Data '$cmd' not written");
    }
    sleep 1;
}

sub setDeviceToServiceMode {
    my ($self) = @_;
    syslog(LOG_INFO, "Setting scanner to service mode");
    sendServiceModeSignal($self);

    syslog(LOG_INFO, "Setting baudrate for service mode");
    $self->{scanner}->baudrate(115200);
}

sub sendServiceModeSignal {
    my ($self) = @_;
    writeCmd($self, "\$S\r");
    sleep 3;
}

sub main {
    my $configurer = AutoConfigurer->new;
    $configurer->configure();
    syslog(LOG_INFO, "Device configured succesfully!");
}

__PACKAGE__->main() unless caller;

1;
