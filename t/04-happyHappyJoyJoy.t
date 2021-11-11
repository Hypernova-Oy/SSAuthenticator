use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;

use SSAuthenticator;
use SSAuthenticator::Greetings;



my $defaultConfTempFile = t::Examples::writeConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());
SSAuthenticator::I18n::changeLanguage('en_GB', 'UTF-8');


subtest "Get greetings", \&getGreetings;
sub getGreetings {
    my @greetings;
    foreach my $i (0..100) {
        my $greet = SSAuthenticator::Greetings::random();
        push(@greetings, $greet) if $greet;
    }
    ok(scalar(@greetings),
       "Got \@greetings");
    ok($greetings[0] =~ /.{20}/,
       "Greeting is 20 characters long");
}

subtest "Make sure a greeting is shown in OLED-display on success", \&OLEDMsg;
sub OLEDMsg {
    SSAuthenticator::Greetings::overloadGreetings(['testGreetingNice']);

    my @rows;
    foreach my $i (0..50) {
        push(@rows, @{SSAuthenticator::_getAccessMsg(SSAuthenticator::OK, undef)});
    }
    my $rows = join("\n", @rows);
    ok($rows =~ /testGreetingNice/gsmi,
       "Test greeting injected");
}

subtest "Barcode read message", \&BarcodeReadMsg;
sub BarcodeReadMsg {
    my $bc = '167A1515616';
    my $centered = SSAuthenticator::centerRow($bc);
    is($centered, "    $bc     ", "centering works as expected");

    my $rows = SSAuthenticator::getBarcodeReadMsg($bc);
    is($rows->[0], "    Barcode read    ");
    is($rows->[1], "    Please wait     ");
    is($rows->[2], "                    ");
    is($rows->[3], "    $bc     ");
}

t::Examples::rmConfig();
done_testing;
