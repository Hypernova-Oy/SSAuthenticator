package SSAuthenticator::Exception::BarcodeReader::ReadFailed;

use Modern::Perl;

use Exception::Class (
    'SSAuthenticator::Exception::BarcodeReader::ReadFailed' => {
        isa => 'SSAuthenticator::Exception',
    },
);

1;