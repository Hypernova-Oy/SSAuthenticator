package SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored;

use Modern::Perl;

use Exception::Class (
    'SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored' => {
        isa => 'SSAuthenticator::Exception',
    },
);

sub throwDefault {
    my ($expected, $got) = @_;
    my @cc = caller(1);
    my $subroutine = $cc[3];
    $subroutine =~ s/^.+:://g; #Trim prepending packages
    SSAuthenticator::Exception::BarcodeReader::Configuration::ValueNotStored->throw(error =>
            "$subroutine() failed to persist '$expected', got '$got' instead.");
}

1;