#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator::AutoConfigurer;

use Modern::Perl;
use Log::Log4perl qw(:easy);
use Device::SerialPort qw( :PARAM :STAT 0.07 );

Log::Log4perl->easy_init($ENV{SSA_LOG_LEVEL} || $DEBUG);

sub new {
    my ($class) = @_;
    my $self = {};

    $self->{scanner} = new Device::SerialPort ("/dev/barcodescanner", 1)
	|| die("No barcodescanner detected");
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
	|| die("closing barcode scanner failed");
}

sub setDeviceToServiceMode {
    my ($self) = @_;
    INFO "Setting scanner to service mode";
    sendServiceModeSignal($self);

    INFO "Setting baudrate for service mode";
    $self->{scanner}->baudrate(115200);
}

sub sendServiceModeSignal {
    my ($self) = @_;
    writeCmd($self, "\$S\r");
    sleep 3;
}

sub saveAndExitServiceMode {
    my ($self) = @_;
    INFO "Saving scanner's settings to RAM and entering normal mode";
    my $scanner = $self->{scanner};

    #writeCmd($self, "\$Ar\r"); #Saves to permanent memory
    writeCmd($self, "\$r01\r"); #Saves to RAM, which taxes the flash-memory's write-cycles less

    sleep 3; # exiting service mode takes some time

    $scanner->baudrate(9600);
}

sub configureSettings {
    my ($self) = @_;
    INFO "Configuring scanner's settings";
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
    die "write failed" unless $bytesWritten;
    die "write incomplete $bytesWritten/".length($sentData) unless $bytesWritten == length($sentData);
}

=head2 isDataRead

@THROWS die if read 'failed' or was 'incomplete'

=cut

sub isDataRead {
    my ($bytesRead, $bytesRequested) = @_;
    die "read failed" unless $bytesRead;
    die "read incomplete $bytesRead/$bytesRequested" unless $bytesRead == $bytesRequested;
}

=head2 setGlobalSuffixToLF

Adds \n after each barcode read

=cut

sub setGlobalSuffixToLF {
    my ($self) = @_;
    INFO "Setting Global suffix to \\n";
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
    INFO "Setting scanner's aiming coordinates to '$coordinates'";
    writeCmd($self, "\$FA$coordinates\r");
    writeCmd($self, "\$Fa\r");                #Request the coordinates from the reader
    my $savedCoordinates = readMsg($self, 8); #Receive bytes
    INFO "  Saved '$savedCoordinates'";
}

=head2 aimingAutoCalibration

Gryphon 4400 manual, page 287

Fx - Aiming Auto Calibration. The reader will switch on the laser aimer, determine the
coordinates of the center cross, and store into the factory non-volatile memory area (Aimer
Calibration).

=cut

sub aimingAutoCalibration {
    my ($self) = @_;
    INFO "Auto calibrating scanner";
    writeCmd($self, "\$Fx\r");
    writeCmd($self, "\$Fa\r");             #Request the coordinates from the reader
    my $coordinates = readMsg($self, 8);   #Receive bytes
    INFO "  Coordinates '$coordinates'";
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
    INFO "Setting 'automatic' operating mode";
    writeCmd($self, "\$CSNRM02\r");
}

sub writeCmd {
    my ($self, $cmd) = @_;
    eval {
        isDataWritten($self->{scanner}->write($cmd), $cmd);
    };
    die("writeCmd($cmd):> $@") if $@;
    sleep 1;
}

=head2 setAllowedSymbologies

Gryphon 4400 manual page 93

Disables all symbologies and allows Code39 without checknum

=cut

sub setAllowedSymbologies {
    my ($self) = @_;
    INFO "Setting allowed symbologies";
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
    INFO "Allowing beep on ASCII BEL";
    writeCmd($self, "\$CR2BB01\r");
}

sub readMsg {
    my ($self, $bytes) = @_;
    my ($byteCount_in, $string_in) = $self->{scanner}->read($bytes);
    eval {
        isDataRead($byteCount_in, $bytes);
    };
    die("readMsg($bytes):> $@") if $@;
    return $string_in;
}

sub main {
    my $configurer = AutoConfigurer->new;
    $configurer->configure();
    INFO "Device configured succesfully!";
}

__PACKAGE__->main() unless caller;

1;
