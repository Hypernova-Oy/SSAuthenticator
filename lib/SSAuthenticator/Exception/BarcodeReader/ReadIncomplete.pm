package SSAuthenticator::Exception::BarcodeReader::ReadIncomplete;

use Modern::Perl;

use Exception::Class (
    'SSAuthenticator::Exception::BarcodeReader::ReadIncomplete' => {
        isa => 'SSAuthenticator::Exception',
    },
);

1;