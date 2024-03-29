#
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package t::Examples;

use Modern::Perl;

use File::Temp;


use SSAuthenticator::Config;
use SSAuthenticator::DB;

my $tempConfFile;
my $tempLog4perlFile;
my $tempOpeningHoursDBFile;
sub _writeTempConf {
    my ($content) = @_;
    $tempConfFile = File::Temp->new();
#    $tempConfFile->unlink_on_destroy( 0 );

    open(my $FILE, '>', $tempConfFile->filename) or die $!;
    print $FILE $content;
    close $FILE;

    return $tempConfFile;
}

my $mailboxDir = File::Temp->newdir();
sub _getDefaultConf {
    my $dir = $mailboxDir->dirname();
    setLog4perlConfig();
    setOpeningHoursDBFile();
    my $log4perl = $tempLog4perlFile->filename();
    my $openingHoursDBFile = $tempOpeningHoursDBFile->filename();

#Pins in BCM numbering
    return <<CONF;
ApiBaseUrl http://localhost-api/api/v1
LibraryName MyTestLibrary
ApiKey testAPikey
ApiUserName testUser
GreenLEDPin 5
BlueLEDPin 6
RedLEDPin 13
DoorPin 20
DoorOffPin 21
PINOnPin 22
PINOffPin 26
RequirePIN 1
PINLength 4
PINLengthMin 4
PINTimeout 1000
PINCodeResetKey '\$'
PINCodeEnterKey '#'
PINValidatorRegexp '^\\d+\$'
Verbose 0
ConnectionTimeout 5
RandomGreetingChance 50
MailboxDir $dir
DefaultLanguage en_US
DoorOpenDuration 1000
Log4perlConfig $log4perl
OpeningHoursDBFile $openingHoursDBFile
BarcodeReaderModel WGC300UsbAT

ircserver irc.oftc.net
ircport 6667
ircchannels #kohasuomi
ircnick toveri-testibot-epsilon
ircname Toveri Testibottinen Epsilon
ircignore_list ,
ircaddress kivilahtio

DoubleReadTimeout 200
Code39DecodingLevel 5

OLED_ShowCardNumberWhenRead hide

CONF
}

sub writeDefaultConf {
    my $content = _getDefaultConf();
    return _writeTempConf($content);
}

sub writeConf {
    my (@overloads) = @_;

    my $content = _getDefaultConf();
    $content .= "\n$_\n" for @overloads;
    return _writeTempConf($content);
}

sub rmConfig {
    $tempConfFile->DESTROY();
    SSAuthenticator::Config::unloadConfig();
}


sub createCacheDB {
    open(my $fh, ">", "patron.db");
    print $fh "";
    close $fh;
    SSAuthenticator::DB::setDB("patron.db");
}

sub rmCacheDB {
    unlink "patron.db";
}

=head2 createTestFile

Truncates and populates a test file.

Does not automatically remove it.

Use File::Temp to generate test files and make sure they get removed.
Do not directly generate files with this subroutine.

=cut

sub createTestFile {
    my ($filePath, $contents) = @_;

    open(my $FH, '>', $filePath) or die $!;
    print $FH $contents;
    close $FH or die $!;
    return 1;
}

sub setLog4perlConfig {
    my $conf = <<CONF;

log4perl.rootLogger = TRACE, SCREEN

log4perl.appender.SCREEN = Log::Log4perl::Appender::ScreenColoredLevels
log4perl.appender.SCREEN.layout=PatternLayout
log4perl.appender.SCREEN.layout.ConversionPattern=[%d] [%p] %m{indent} [%M]%n
log4perl.appender.SCREEN.utf8=1
log4perl.appender.SCREEN.stderr=0


CONF

    $tempLog4perlFile = _writeTempConf($conf);
    return $tempLog4perlFile;
}

sub setOpeningHoursDBFile {
    my $conf = <<CONF;
---

CONF

    $tempOpeningHoursDBFile = _writeTempConf($conf);
    return $tempOpeningHoursDBFile;
}

1;
