use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;

use SSAuthenticator;
use SSAuthenticator::Greetings;
use SSAuthenticator::Transaction;


my $defaultConfTempFile = t::Examples::writeConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());
SSAuthenticator::I18n::changeLanguage('en_GB', 'UTF-8');


subtest "OLED message barcode read", \&OLED_message_barcode_read;
sub OLED_message_barcode_read {
    my $trans = SSAuthenticator::Transaction->new();
    my $barcode = '123A0010';

    SSAuthenticator::Config::getConfig()->param('OLED_ShowCardNumberWhenRead', 'b');
    ok(SSAuthenticator::OLED::showBarcodePostReadMsg($trans, $barcode),
        "showBarcodePostReadMsg with barcode");
    is($trans->oledMessages()->[0]->[0], 'showBarcodePostReadMsg');
    is($trans->oledMessages()->[0]->[1]->[0], "    Barcode read    ");
    is($trans->oledMessages()->[0]->[1]->[1], "    Please wait     ");
    is($trans->oledMessages()->[0]->[1]->[2], "                    ");
    is($trans->oledMessages()->[0]->[1]->[3], "      $barcode      ");

    SSAuthenticator::Config::getConfig()->param('OLED_ShowCardNumberWhenRead', 'm');
    ok(SSAuthenticator::OLED::showBarcodePostReadMsg($trans, $barcode),
        "showBarcodePostReadMsg with message only");
    is($trans->oledMessages()->[1]->[0], 'showBarcodePostReadMsg');
    is($trans->oledMessages()->[1]->[1]->[0], "    Barcode read    ");
    is($trans->oledMessages()->[1]->[1]->[1], "    Please wait     ");
    is($trans->oledMessages()->[1]->[1]->[2], undef);
    is($trans->oledMessages()->[1]->[1]->[3], undef);

    SSAuthenticator::Config::getConfig()->param('OLED_ShowCardNumberWhenRead', 'h');
    ok(SSAuthenticator::OLED::showBarcodePostReadMsg($trans, $barcode),
        "showBarcodePostReadMsg hidden");
    is($trans->oledMessages()->[2], undef);
}

subtest "Make sure a greeting is shown in OLED-display on success", \&OLEDMsg;
sub OLEDMsg {
    SSAuthenticator::Greetings::overloadGreetings(['testGreetingNice']);

    my @rows;
    foreach my $i (0..50) {
        my $happyMsg = SSAuthenticator::Greetings::random();
        push(@rows, $happyMsg) if $happyMsg;
    }
    my $rows = join("\n", @rows);
    ok($rows =~ /testGreetingNice/gsmi,
       "Test greeting injected");
}

t::Examples::rmConfig();
done_testing;
