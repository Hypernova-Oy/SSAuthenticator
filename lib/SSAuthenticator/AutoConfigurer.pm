#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator::AutoConfigurer;

use Modern::Perl;
use Device::SerialPort qw( :PARAM :STAT 0.07 );

use SSLog;
my $l = SSLog->get_logger(); #Package logger

sub new {
    my ($class) = @_;
    my $self = {};

    $self->{scanner} = new Device::SerialPort ("/dev/barcodescanner", 1)
	|| $l->logdie("No barcodescanner detected");
    $self->{scanner}->baudrate(9600);
    $self->{scanner}->parity("none");
    $self->{scanner}->databits(8);
    $self->{scanner}->stopbits(1);
    $self->{scanner}->handshake('rts');

    return bless($self, $class);
}

sub configure {
    my ($self) = @_;
    setDeviceToServiceMode($self);
    configureSettings($self);
    saveAndExitServiceMode($self);
    $self->{scanner}->close()
	|| $l->logdie("closing barcode scanner failed");
}

sub setDeviceToServiceMode {
    my ($self) = @_;
    $l->info("Setting scanner to service mode");
    sendServiceModeSignal($self);

    $l->info("Setting baudrate for service mode");
    $self->{scanner}->baudrate(115200);
}

sub sendServiceModeSignal {
    my ($self) = @_;
    writeCmd($self, "\$S\r");
    sleep 3;
}

sub saveAndExitServiceMode {
    my ($self) = @_;
    $l->info("Saving scanner's settings to RAM and entering normal mode");
    my $scanner = $self->{scanner};

    #writeCmd($self, "\$Ar\r"); #Saves to permanent memory
    writeCmd($self, "\$r01\r"); #Saves to RAM, which taxes the flash-memory's write-cycles less

    sleep 3; # exiting service mode takes some time

    $scanner->baudrate(9600);
}

sub configureSettings {
    my ($self) = @_;
    $l->info("Configuring scanner's settings");
    $self->setGlobalSuffixToLF();
#    $self->setAimingCoordinates();
    $self->aimingAutoCalibration();
    $self->setAutomaticOperatingMode();
    $self->setAllowedSymbologies();
    $self->setBeepOnASCII_BEL(1);
}

=head2 isDataWritten

@THROWS die if write 'failed' or was 'incomplete'

=cut

sub isDataWritten {
    my ($bytesWritten, $sentData) = @_;
    $l->logdie("write failed")unless $bytesWritten;
    $l->logdie("write incomplete $bytesWritten/".length($sentData)) unless $bytesWritten == length($sentData);
}

=head2 isDataRead

@THROWS die if read 'failed' or was 'incomplete'

=cut

sub isDataRead {
    my ($bytesRead, $bytesRequested) = @_;
    $l->logdie("read failed") unless $bytesRead;
    $l->logdie("read incomplete $bytesRead/$bytesRequested") unless $bytesRead == $bytesRequested;
}

=head2 setGlobalSuffixToLF

Adds \n after each barcode read

=cut

sub setGlobalSuffixToLF {
    my ($self) = @_;
    $l->info("Setting Global suffix to \\n");
    writeCmd($self, "\$CLFSU0A00000000000000000000000000000000000000\r");
}

=head2 setAimingCoordinates
@DEPRECATED

It is preferred to let the reader autodetect the center coordinates using the laser aimer.
This is done in aimingAutoCalibration()

Gryphon 4400 manual, page 287

FA - Aiming Write Coordinates. Writes specified coordinates into the factory non-volatile
memory area. Use this command if you wish to override any other previously written;
factory, user or custom calibration or setting.

=cut

sub setAimingCoordinates {
    my ($self) = @_;
    my $coordinates = '03760240';
    $l->info("Setting scanner's aiming coordinates to '$coordinates'");
    writeCmd($self, "\$FA$coordinates\r");
    writeCmd($self, "\$Fa\r");                #Request the coordinates from the reader
    my $savedCoordinates = readMsg($self, 8); #Receive bytes
    $l->info("  Saved '$savedCoordinates'");
}

=head2 aimingAutoCalibration

Gryphon 4400 manual, page 287

Fx - Aiming Auto Calibration. The reader will switch on the laser aimer, determine the
coordinates of the center cross, and store into the factory non-volatile memory area (Aimer
Calibration).

=cut

sub aimingAutoCalibration {
    my ($self) = @_;
    $l->info("Auto calibrating scanner");
    writeCmd($self, "\$Fx\r");
    writeCmd($self, "\$Fa\r");             #Request the coordinates from the reader
    my $coordinates = readMsg($self, 8);   #Receive bytes
    $l->info("  Coordinates '$coordinates'");
}

=head2 setAutomaticOperatingMode

Gryphon 4400 manual page 270

Automatic Mode
In Automatic mode, the scanner is continuously scanning. When a label enters the reading
zone and is decoded, no more decodes and reading phases are allowed until the label has left
the reading area. In order to guarantee identification of the code in the reading zone, a
threshold specifies the number of scans after the successful decode that the scanner will wait
before rearming the reading phase. The transmission of the decoded label depends on the
configuration of the Transmission Mode parameter.

=cut

sub setAutomaticOperatingMode {
    my ($self) = @_;
    $l->info("Setting 'automatic' operating mode");
    writeCmd($self, "\$CSNRM02\r");
}

sub writeCmd {
    my ($self, $cmd) = @_;
    eval {
        isDataWritten($self->{scanner}->write($cmd), $cmd);
    };
    $l->logdie("writeCmd($cmd):> $@") if $@;
    sleep 1;
}

=head2 setAllowedSymbologies

Gryphon 4400 manual page 93

Disables all symbologies and allows Code39 without checknum

=cut

sub setAllowedSymbologies {
    my ($self) = @_;
    $l->info("Setting allowed symbologies");
    writeCmd($self, "\$AD\r");     #Disable all symbologies
    writeCmd($self, "\$CC3EN01\r"); #Allow Code 39
    writeCmd($self, "\$CC3CC00\r"); #Check Calculation disabled
    writeCmd($self, "\$CC3MR02\r"); #Must read successfully consecutively two times
}

=head2 setBeepOnASCII_BEL

When sending ASCII BEL 0x07 to the barcode reader, it beeps :)

=cut

sub setBeepOnASCII_BEL {
    my ($self) = @_;
    $l->info("Allowing beep on ASCII BEL");
    writeCmd($self, "\$CR2BB01\r");
}

sub readMsg {
    my ($self, $bytes) = @_;
    my ($byteCount_in, $string_in) = $self->{scanner}->read($bytes);
    eval {
        isDataRead($byteCount_in, $bytes);
    };
    $l->logdie("readMsg($bytes):> $@") if $@;
    return $string_in;
}

sub main {
    my $configurer = AutoConfigurer->new;
    $configurer->configure();
    $l->info("Device configured succesfully!");
}

__PACKAGE__->main() unless caller;

1;
