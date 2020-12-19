package SSAuthenticator::Exception;

use Modern::Perl;

use Exception::Class (
  'SSAuthenticator::Exception' => {
    description => 'SSAuthenticator exceptions base class',
  },
  'SSAuthenticator::Exception::KeyPad::WaitTimeout' => {
    description => 'KeyPad timed out waiting for a new user key input',
  },
);

1;
