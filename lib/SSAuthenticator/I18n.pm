# Copyright (C) 2020 Hypernova Oy
#
# This file is part of SSAuthenticator.

package SSAuthenticator::I18n;

use Modern::Perl;

use Locale::TextDomain qw (SSAuthenticator); #Look from cwd or system defaults. This is needed for tests to pass during build
use POSIX qw(LC_MESSAGES LC_ALL);

use SSAuthenticator::Pragmas;
my $l = bless({}, 'SSLog');
use SSAuthenticator::Config;

our %i18nMsg = (
                            #-----+++++-----+++++\n-----+++++-----+++++\n-----+++++-----+++++\n-----+++++-----+++++
    ##ACCESS MESSAGES
    $SSAuthenticator::OK           , N__"   Access granted   ", # '=>' quotes the key automatically, use ',' to not quote the constants to strings
    'ACCESS_DENIED'              => N__"   Access denied    ",
    $SSAuthenticator::ERR_API_AUTH , N__" Device API failure \\n Bad authentication ",
    $SSAuthenticator::ERR_UNDERAGE , N__"     Age limit      ",
    $SSAuthenticator::ERR_SSTAC    , N__" Terms & Conditions \\n    not accepted    ",
    $SSAuthenticator::ERR_BBC      , N__"   Wrong borrower   \\n      category      ",
    $SSAuthenticator::ERR_REVOKED  , N__" Self-service usage \\n permission revoked ",
    $SSAuthenticator::ERR_NAUGHTY  , N__" Circulation rules  \\n    not followed    ",
    $SSAuthenticator::ERR_CLOSED   , N__"   Library closed   ",
    $SSAuthenticator::ERR_BADCARD  , N__"Card not recognized ",
    $SSAuthenticator::ERR_PINBAD   , N__"  Invalid PIN-code  ",
    $SSAuthenticator::ERR_PINTIMEOUT,N__"PIN entry timeouted ",
    $SSAuthenticator::ERR_PININVALID,N__" Reading PIN failed \\n  PIN device error  ",
    $SSAuthenticator::ERR_SERVER   , N__"    Server error    ",
    $SSAuthenticator::ERR_SERVERCONN,N__"  Connection error  ",
    'CACHE_USED'                 => N__" I Remembered you!  ",
    'CONTACT_LIBRARY'            => N__"Contact your library",
    'OPEN_AT'                    => N__"Open at",
    'BARCODE_READ'               => N__"    Barcode read    ",
    'PLEASE_WAIT'                => N__"    Please wait     ",
    'BLANK_ROW'                  => N__"                    ",
    'PIN_CODE_ENTER'             => N__"  Please enter PIN  ",
    'PIN_CODE_TOO_LONG'          => N__"   Wrong PIN code...",
    'PIN_CODE_WRONG'             => N__"   Wrong PIN code   ",
    'PIN_CODE_OK'                => N__"       PIN OK       ",
    'PIN_CODE_OPTION'            => N__"* reset         ok #",

    ##INITIALIZATION MESSAGES
    'INITING_STARTING'  => N__"  I am waking up.   \\nPlease wait a moment\\nWhile I check I have\\n everything I need. ",
    'INITING_ERROR'     => N__" I have failed you  \\n  I am not working  \\nPlease contact your \\n      library       ",
    'INITING_FINISHED'  => N__"   I am complete    \\n   Please use me.   \\n                    \\n                    ",
);
our $i18nMsg = \%i18nMsg;

=head2 changeLanguage

    changeLanguage('fi_FI', 'UTF-8');

Changes the language of the running process

=cut

sub changeLanguage {
    my ($lang, $encoding) = @_;
    $ENV{LANGUAGE} = $lang;
    POSIX::setlocale(LC_ALL, "$lang.$encoding");
}

sub setDefaultLanguage {
    changeLanguage(
        SSAuthenticator::Config::getConfig()->param('DefaultLanguage'),
        'UTF-8',
    );
    $l->info("setDefaultLanguage() ".SSAuthenticator::Config::getConfig()->param('DefaultLanguage')) if $l->is_info;
}

use Exporter 'import'; # gives you Exporter's import() method directly
our @EXPORT_OK = qw($i18nMsg);  # symbols to export on request

1;
