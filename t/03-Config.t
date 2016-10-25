use Modern::Perl;
use Test::More;
use Test::MockModule;

use t::Examples;

use SSAuthenticator;
use SSAuthenticator::Config;


subtest "Config timeout validation works", \&testConfigTimeoutValidation;
sub testConfigTimeoutValidation {

    my ($defaultConfTempFile);

    $defaultConfTempFile = t::Examples::writeBadConnectionTimeoutConf();
    SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

    ok(!SSAuthenticator::Config::isConfigValid(), "not string as timeout value");
    rmConfig();

    $defaultConfTempFile = t::Examples::writeDefaultConf();
    SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

    ok(SSAuthenticator::Config::isConfigValid(), "integer is valid timeout value");
    rmConfig();
}


######## TEST HELPERS #########
###############################

sub makeConfigValid() {
    open(my $fh, ">", "daemon.conf");

    say $fh "ApiBaseUrl http://localhost-api/api/v1";
    say $fh "LibraryName MyTestLibrary";
    say $fh "ApiKey testAPikey";
    say $fh "ApiUserName testUser";

    close $fh;
}

sub rmConfig {
    unlink "daemon.conf";
    SSAuthenticator::Config::unloadConfig();
}

sub getConfig {
    my $configFile = "daemon.conf";
    my $config = new Config::Simple($configFile)
	|| die Config::Simple->error(), ".\n",
	"Please check the syntax in daemon.conf.";
    return $config;
}

done_testing;
