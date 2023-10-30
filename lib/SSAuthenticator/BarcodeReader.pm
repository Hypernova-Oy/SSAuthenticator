# Copyright (C) 2020 Hypernova Oy
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator::BarcodeReader;

use SSAuthenticator::Pragmas;
my $l = bless({}, 'SSLog');

sub configureBarcodeScanner {
    my $brm = SSAuthenticator::Config::getConfig()->param('BarcodeReaderModel');
    if    ($brm =~ /^GFS4400$/) {
        my $configurer = SSAuthenticator::AutoConfigurer->new;
        $configurer->configure();
    }
    elsif ($brm =~ /^WGC300UsbAT$/) {
        GetReader()->autoConfigure();
    }
    $l->info("Barcode scanner '$brm' configured") if $l->is_info;
}

sub GetReader {
    my $brm = SSAuthenticator::Config::getConfig()->param('BarcodeReaderModel');
    if    ($brm =~ /^GFS4400$/) {
        ##Sometimes the barcode scanner can disappear and reappear during/after configuration. Try to find a barcode scanner handle
        for (my $tries=0 ; $tries < 10 ; $tries++) {
            open(my $device, "<", "/dev/barcodescanner");
            return $device if $device;
            sleep 1;
        }
    }
    elsif ($brm =~ /^WGC300UsbAT$/) {
        require SSAuthenticator::Device::WGC300UsbAT;
        return SSAuthenticator::Device::WGC300UsbAT->new();
    }
}

sub ReadBarcode {
    my ($device, $timeout) = @_;
    my $brm = SSAuthenticator::Config::getConfig()->param('BarcodeReaderModel');
    if    ($brm =~ /^GFS4400$/) {
        timeout_call(
            $timeout,
            sub {return <$device>}
        );
    }
    elsif ($brm =~ /^WGC300UsbAT$/) {
        return $device->pollData($timeout);
    }
}

# Flush buffers from possible repeated reads
sub FlushBarcodeBuffers {
    my ($device) = @_;
    my $brm = SSAuthenticator::Config::getConfig()->param('BarcodeReaderModel');
    if    ($brm =~ /^GFS4400$/) {
        close $device;
    }
    elsif ($brm =~ /^WGC300UsbAT$/) {
        $device->receiveData();
    }
}

1;
