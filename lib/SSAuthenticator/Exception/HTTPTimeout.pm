package SSAuthenticator::Exception::HTTPTimeout;

use Modern::Perl;

use Exception::Class (
    'SSAuthenticator::Exception::HTTPTimeout' => {
        isa => 'SSAuthenticator::Exception',
    },
);

1;
