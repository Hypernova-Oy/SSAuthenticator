#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator::AutoConfigurer;

use Modern::Perl;
use Device::SerialPort qw( :PARAM :STAT 0.07 );
use Try::Tiny;
use Scalar::Util qw(blessed weaken);

use SSAuthenticator::Config;

use SSAuthenticator::Exception::BarcodeReader::WriteFailed;
use SSAuthenticator::Exception::BarcodeReader::WriteIncomplete;
use SSAuthenticator::Exception::BarcodeReader::ReadFailed;
use SSAuthenticator::Exception::BarcodeReader::ReadIncomplete;
use SSAuthenticator::Exception::BarcodeReader::Configuration::Acknowledgement;
use SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored;


=head1 IN THIS FILE

This standalone static module autoconfigures the given barcode reader to be used with SSAuthenticator.

It is intended to be used when SSAuthenticator starts,
or when a barcode reader needs to be tested, but the complete SSAuthenticator dependency chain is not needed.

It runs a MD5 hash of itself (this PACKAGE) and stores it to the system configuration dir (/etc/ssauthenticator).
This is compared when SSAuthenticator starts to the fresh MD5 hash of itself, to see if the AutoConfigurer has
changed and changes need to be updated to the barcode reader.

If this is ran manually, the behaviour can be overridden and autoconfiguration forced.

=cut

#Try loading SSLog, but if it cannot be loaded, then simply log to STDOUT
use Log::Log4perl qw(:levels);
my $l;
eval {
    require SSAuthenticator::Config;
    require SSLog;
    $l = bless({}, 'SSLog');
};
if ($@) {
    Log::Log4perl->easy_init;
    $l = Log::Log4perl->get_logger($ERROR);
    $l->info("Loading SSLog failed, using Log::Log4perl->easy_init(). This is normal when autoconfiguring barcode reader from outside the SSAuthenticator-daemon.");
    Log::Log4perl->appender_thresholds_adjust(-1*$ENV{SSA_LOG_LEVEL});

    $l->trace("SSLog instantiation failed because of '$@'");
}



sub new {
    my ($class, $device) = @_;
    my $self = {};
    bless($self, $class);

    $device = "/dev/barcodescanner" unless $device;
    $self->{scanner} = Device::SerialPort->new($device, 1)
        || $l->logdie("No barcodescanner '$device' detected");
    $self->s->baudrate(9600);
    $self->s->parity("none");
    $self->s->databits(8);
    $self->s->stopbits(1);
    $self->s->handshake('rts');

    #Params for reading input
    $self->s->read_char_time(0);     # don't wait for each character
    $self->s->read_const_time(5000); # wait a maximum of this milliseconds before failing the read()-request

    #Activate and validate connection params
    $self->s->write_settings();

    #Where to save the configured changes?
    $self->{_persistence} = 'RAM' || 'Flash';
    #$self->{_persistence} = 'Flash';
    return $self;
}

sub s {
    return $_[0]->{scanner};
}

=head2 reload

Reloads the barcode reader, but setting it to service mode and exitting.

=cut

sub reload {
    my ($self) = @_;
    $self->setDeviceToServiceMode();
    $self->exitServiceMode();
}

=head2 configure

  $ac->configure();

Configures the given barcode reader.

@THROWS SSAuthenticator::Exception on failure

=cut

sub configure {
    my ($self) = @_;
    $l->info("GFS4400 version ".$self->readApplicationSoftwareRelease());
    $self->setDeviceToServiceMode();

    try {
        $self->configureSettings();
        $self->saveAndExitServiceMode();

    } catch {
        $self->exitServiceMode();
        die $_ unless blessed($_);
        $_->rethrow();

    } finally {
        $self->s->close()
            || $l->logdie("closing barcode scanner failed");
    };
}

sub setDeviceToServiceMode {
    my ($self) = @_;
    $l->info("Setting scanner to service mode");
    sendServiceModeSignal($self);

    $l->info("Setting baudrate for service mode");
    $self->s->baudrate(115200);
    $self->s->write_settings();
}

sub sendServiceModeSignal {
    my ($self) = @_;
    sendCmd($self, "\$S\r");
#    sleep 3;
}

sub exitServiceMode {
    my ($self) = @_;

    $l->info("Discarding changes and exiting service mode");
    sendCmd($self, "\$s\r");

    $self->_restoreNormalConnectionParams();
}

sub saveAndExitServiceMode {
    my ($self) = @_;

    if ($self->{_persistence} =~ /RAM/i) {
        $self->saveToRAMAndExitServiceMode();
    }
    elsif ($self->{_persistence} =~ /Flash/i) {
        $self->saveToFlashAndExitServiceMode();
    }
    else {
        die "Unknown value for \$persistence '$self->{_persistence}'. Don't know how to save changes.";
    }
}

sub saveToFlashAndExitServiceMode {
    my ($self) = @_;

    $l->info("Saving scanner's settings to Flash and entering normal mode");
    try {
        sendCmd($self, "\$Ar\r"); #Saves to permanent memory
    } catch {
        warn $_->error, "\n", $_->trace->as_string, "\n";
        die $_ unless blessed($_);
        if ($_->isa('SSAuthenticator::Exception::BarcodeReader::WriteFailed')) {
            #This might be ok, because saving on Flash boots the device?
        }
        $_->rethrow();
    };

    $self->_restoreNormalConnectionParams();
}

sub saveToRAMAndExitServiceMode {
    my ($self) = @_;

    $l->info("Saving scanner's settings to RAM and entering normal mode");
    sendCmd($self, "\$r01\r"); #Saves to RAM, which taxes the flash-memory's write-cycles less
    #sleep 3; # exiting service mode takes some time

    $self->_restoreNormalConnectionParams();
}

sub _restoreNormalConnectionParams {
    my ($self) = @_;
    $self->s->baudrate(9600);
    $self->s->write_settings();
}

sub readApplicationSoftwareRelease {
    my ($self) = @_;

    my $expectedBytes = 72; #The response sise might vary from reader to reader, maybe need to read as much as there is to read?
    return sendCmd($self, "\$+\$!\r", $expectedBytes);
}

sub configureSettings {
    my ($self) = @_;
    $l->info("Configuring scanner's settings");
    $self->setGlobalSuffixToLF();
    $self->setAimingCoordinates();
#    $self->aimingAutoCalibration();
    $self->setAutomaticOperatingMode();
    $self->setAllowedSymbologies();
    $self->setBeepOnASCII_BEL();
    $self->setCentralCodeOnly();
    $self->setMobilePhoneMode();
    $self->setDoubleReadTimeout();
    $self->setCode39QuietZones();
    $self->setCode39DecodingLevel();
}

=head2 setGlobalSuffixToLF

Adds \n after each barcode read

=cut

sub setGlobalSuffixToLF {
    my ($self) = @_;
    $l->info("Setting Global suffix to \\n");
    #my $suffixHexes = "2B2B0A0000000000000000000000000000000000"; #This suffixes with ++, you shouldn't need to do this. Used to test this configuration option.
    my $suffixHexes = "0A00000000000000000000000000000000000000"; #This disables suffix
    #Write to RAM
    my $response = sendCmd($self, "\$CLFSU$suffixHexes\r");
    #Check that RAM was actually written
    $response = sendCmd($self, "\$cLFSU\r", 43);
    $l->info("  Value '$response' was persisted.");

    unless ($response =~ /$suffixHexes$/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault($suffixHexes, $response);
    }
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
    sendCmd($self, "\$FA$coordinates\r");
    my $savedCoordinates = sendCmd($self, "\$Fa\r", 11);                #Request the coordinates from the reader
    $l->info("  Coordinates '$savedCoordinates'");

    unless ($savedCoordinates =~ /$coordinates$/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault($coordinates, $savedCoordinates);
    }
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
    sendCmd($self, "\$Fx\r");
    my $coordinates = sendCmd($self, "\$Fa\r", 11);             #Request the coordinates from the reader
    $l->info("  Coordinates '$coordinates'");

    unless ($coordinates) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault('coordinates', 'undef');
    }
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
    sendCmd($self, "\$CSNRM02\r");
    my $response = sendCmd($self, "\$cSNRM\r", 5);   ##Check if changes were applied to RAM
    $l->info("  Automatic Operating Mode '$response'");

    unless ($response =~ /02/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault('02', $response);
    }
}

=head2 setAllowedSymbologies

Gryphon 4400 manual page 93

Disables all symbologies and allows Code39 without checknum

=cut

sub setAllowedSymbologies {
    my ($self) = @_;
    $l->info("Setting allowed symbologies");
    sendCmd($self, "\$AD\r");     #Disable all symbologies
    sendCmd($self, "\$CC3EN01\r"); #Allow Code 39
    sendCmd($self, "\$CC3CC00\r"); #Check Calculation disabled
    sendCmd($self, "\$CC3MR02\r"); #Must read successfully consecutively two times
}

=head2 setBeepOnASCII_BEL

When sending ASCII BEL 0x07 to the barcode reader, it beeps :)

=cut

sub setBeepOnASCII_BEL {
    my ($self) = @_;
    $l->info("Allowing beep on ASCII BEL");
    sendCmd($self, "\$CR2BB01\r");
    my $response = sendCmd($self, "\$cR2BB\r", 5);   ##Check if changes were applied to RAM
    $l->info("  Allowing beep on ASCII BEL '$response'");

    unless ($response =~ /01/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault('01', $response);
    }
}

=head2 setCentralCodeOnly

GFS 4400 manual page 84

Specifies the ability of the reader to decode labels only when they are close to the center of
the aiming pattern. This allows the reader to accurately target labels when they are placed
close together, such as on a pick sheet.

Got email from Datalogic explaining the codes.
- Central Code only, page 84  à Pick mode (SNPM)

=cut


sub setCentralCodeOnly {
    my ($self) = @_;
    $l->info("Setting Central Code Only");

    sendCmd($self, "\$CSNPM01\r");
    my $response = sendCmd($self, "\$cSNPM\r", 5);   ##Check if changes were applied to RAM
    $l->info("  Reading Central Code Only (aka. Pick Mode) '$response'");

    unless ($response =~ /01/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault('01', $response);
    }
}

=head2 setMobilePhoneMode

GFS 4400 manual page 88

Got email from Datalogic explaining the codes.
- Mobile Phone Mode, page 88 à (SNPE)

=cut

sub setMobilePhoneMode {
    my ($self) = @_;
    $l->info("Setting Mobile Phone Mode off");

    sendCmd($self, "\$CSNPE00\r");
    my $response = sendCmd($self, "\$cSNPE\r", 5);   ##Check if changes were applied to RAM
    $l->info("  Disabling Mobile Phone Mode '$response'");

    unless ($response =~ /00/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault('00', $response);
    }
}

=head2 setDoubleReadTimeout

GFS 4400 manual page 268

Double Read Timeout prevents a double read of the same label by setting the minimum time
allowed between reads of labels of the same symbology and data. If the unit reads a label
and sees the same label again within the specified timeout, the second read is ignored.
Double Read Timeout does not apply to scan modes that require a trigger pull for each label
read.

=cut

sub setDoubleReadTimeout {
    my ($self) = @_;
    my $c = SSAuthenticator::Config::getConfig();
    my $hx = sprintf("%2x", int($c->param('DoubleReadTimeout') / 10)); #Hex value is how many 10ms chunks there are, starting from 20ms
    $l->info("Setting Double Read Timeout to '".$c->param('DoubleReadTimeout')."ms' or HEX '$hx'");

    sendCmd($self, "\$CSNDR$hx\r");
    my $response = sendCmd($self, "\$cSNDR\r", 5);   ##Check if changes were applied to RAM
    $l->info("  Double Read Timeout response '$response'");

    unless ($response =~ /$hx/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault($hx, $response);
    }
}

=head2 setCode39QuietZones

GFS 4400 manual page 268

Double Read Timeout prevents a double read of the same label by setting the minimum time
allowed between reads of labels of the same symbology and data. If the unit reads a label
and sees the same label again within the specified timeout, the second read is ignored.
Double Read Timeout does not apply to scan modes that require a trigger pull for each label
read.

=cut

sub setCode39QuietZones {
    my ($self) = @_;
    $l->info("Setting Code39 Quiet Zones to both sides");

    sendCmd($self, "\$CC3LO02\r");
    my $response = sendCmd($self, "\$cC3LO\r", 5);   ##Check if changes were applied to RAM
    $l->info("  Code39 Quiet Zones response '$response'");

    unless ($response =~ /02/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault('02', $response);
    }
}

=head2 setCode39DecodingLevel

https://www.manualslib.com/manual/702353/Datalogic-Quickscan-I.html?page=201

Code 128 Decoding Level

Decoding Levels are used to configure a barcode symbology decoder to be very aggressive
to very conservative depending on a particular customer's needs.

There are many factors that determine when to change the decoding level for a particular
symbology. These factors include spots, voids, non-uniform bar/space widths, damaged
labels, etc. that may be experienced in some barcode labels. If there are many hard to read
or damaged labels that cannot be decoded using a conservative setting, increase the de-
coding level to be more aggressive. If the majority of labels are very good quality labels,
or there is a need to decrease the possibility of a decoder error, lower the decoding level
to a more conservative level.

=cut

sub setCode39DecodingLevel {
    my ($self) = @_;
    my $c = SSAuthenticator::Config::getConfig();
    my $hx = sprintf("0%1d", int($c->param('Code39DecodingLevel'))); #Take only the first digit and append zero to it to make the valid HEX code
    $l->info("Setting Code39 Decoding Level to '".$c->param('Code39DecodingLevel')."' or as HEX '$hx'");

    sendCmd($self, "\$CC3DL$hx\r"); #01 is strictest, 05 is laxest
    my $response = sendCmd($self, "\$cC3DL\r", 3);   ##Check if changes were applied to RAM
    $l->info("  Code39 Decoding Level response '$response'");

    unless ($response =~ /\$\%/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throwDefault($hx, $response);
    }
}

=head2 _isDataWritten

@THROWS Exception if write 'failed' or was 'incomplete'

=cut

sub _isDataWritten {
    my ($bytesWritten, $sentData) = @_;
    SSAuthenticator::Exception::BarcodeReader::WriteFailed->throw(error => "Writing '"._normalizeScannerResponse($sentData)."' failed as \$bytesWritten is undefined")
            unless(defined($bytesWritten));
    SSAuthenticator::Exception::BarcodeReader::WriteIncomplete->throw(error => "Writing '"._normalizeScannerResponse($sentData)."' failed as delivery is incomplete. '$bytesWritten' bytes written out of '".length($sentData)."'")
            unless($bytesWritten == length($sentData));
}

=head2 _isDataRead

@THROWS Excpetion if read 'failed' or if a specific amount of bytes was requested and not received

=cut

sub _isDataRead {
    my ($stringIn, $bytesRead, $bytesRequested) = @_;
    SSAuthenticator::Exception::BarcodeReader::WriteFailed->throw(error =>
            "Reading data failed as \$bytesRead is undefined.".(defined($stringIn) ? " Managed to receive '$stringIn'" : ''))
            unless(defined($bytesRead));
    SSAuthenticator::Exception::BarcodeReader::WriteIncomplete->throw(error =>
            "Reading data failed as receival was incomplete. '$bytesRead' bytes received out of '".$bytesRequested."'.".(defined($stringIn) ? " Managed to receive '$stringIn'" : ''))
            if ($bytesRequested && ($bytesRead != $bytesRequested))
}

=head2 _isResponseOk

Gryphon 4400 manual page 292

Checks after sending a command, if the returning message is a GFS4400
  success        ($>)
  or a failure   ($@)

@RETURNS String, where the response status and ending carriage returns have been trimmed away. Leaving only the payload behind.

@THROWS SSAuthenticator::Exception::BarcodeReader::Configuration::Acknowledgement

=cut

sub _isResponseOk {
    my ($response) = @_;
    if ($response =~ /^\$>/) {
        $l->debug("Response '"._normalizeScannerResponse($response)."' ok");
    }
    elsif ($response =~ /^\$\@/) {
        SSAuthenticator::Exception::BarcodeReader::Configuration::Acknowledgement->throw(error => "Response '"._normalizeScannerResponse($response)."' marks a failure");
    }
    $response =~ s/\r$//;
    $response =~ s/^\$>//;
    return $response;
}

=head2 sendCmd

Sends a command to the barcode reader

@Throws SSAuthenticator::Exceptions

=cut

sub sendCmd {
    my ($self, $cmd, $expectedResponseSize) = @_;
    $expectedResponseSize = 3 unless $expectedResponseSize; #Default response is $>\r
    _isDataWritten( $self->s->write($cmd), $cmd );
    return _isResponseOk(readMsg($self, $expectedResponseSize));
}

=head2 readRow

Reads as much as it can

=cut

sub readRow {
    my ($self) = @_;
    my ($byteCount_in, $stringIn) = $self->s->read(255);
    _isDataRead($stringIn, $byteCount_in);
    return $stringIn;
}

=head2 readMsg

Reads only a predetermined amount of bytes.
Dies if unexpected amount of bytes is returned

=cut

sub readMsg {
    my ($self, $bytes) = @_;
    my ($byteCount_in, $stringIn) = $self->s->read($bytes);
    _isDataRead($stringIn, $byteCount_in, $bytes);
    return $stringIn;
}

=head2 _normalizeScannerResponse

Makes the scanner's response printable by escaping
carriage return

=cut

sub _normalizeScannerResponse {
    my ($response) = @_;
    $response =~ s/\r/\\r/g;
    return $response;
}

=head2 execStep

A wrapper to log and execute subroutines in this PACKAGE from a calling script.

=cut

sub execStep {
    my ($self, $step) = @_;
    $self->{_stepCount} = 1 unless(exists($self->{_stepCount}));
    $l->info("Executing step ".$self->{_stepCount}." -> $step");
    $self->$step();
}

1;
