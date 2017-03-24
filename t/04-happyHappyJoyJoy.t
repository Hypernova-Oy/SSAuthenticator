use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;

use SSAuthenticator;
use SSAuthenticator::Greetings;



my $defaultConfTempFile = t::Examples::writeConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());



subtest "Get greetings", \&getGreetings;
sub getGreetings {
    my @greetings;
    foreach my $i (0..100) {
        my $greet = SSAuthenticator::Greetings::random();
        push(@greetings, $greet) if $greet;
    }
    ok(scalar(@greetings) < 75 && scalar(@greetings > 25),
       "Got more than 25 but less than 75 \@greetings");
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

t::Examples::rmConfig();
done_testing;
