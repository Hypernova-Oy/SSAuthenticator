use Modern::Perl;
use Test::More tests => 2;
use Test::MockModule;

use Authenticator;

subtest "Config validation works", \&testConfigValidation;
sub testConfigValidation {
    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getConfig', \&getConfig);
    
    my @params = ('ApiBaseUrl', 'LibraryName', 'ApiUserName', 'ApiKey');
    foreach my $param (@params) {
	open(my $fh, ">", "daemon.conf");
	say $fh $param, " testValue";
	close $fh;
	ok(!Authenticator::isConfigValid(), "partial (only $param".
	   ") config not valid");
    }


    rmConfig();
}

subtest "Config timeout validation works", \&testConfigTimeoutValidation;
sub testConfigTimeoutValidation {

    my $module = Test::MockModule->new('Authenticator');
    $module->mock('getConfig', \&getConfig);

    makeConfigValid();

    open(my $fh, ">>", "daemon.conf");
    say $fh "ConnectionTimeout", " testString";
    close $fh;
    ok(!Authenticator::isConfigValid(), "not string as timeout value");

    open($fh, ">>", "daemon.conf");
    say "\n";
    say $fh "ConnectionTimeout", " 3";
    close $fh;
    ok(Authenticator::isConfigValid(), "integer is valid timeout value");

    rmConfig();
}

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
}

sub getConfig {
    my $configFile = "daemon.conf";
    my $config = new Config::Simple($configFile)
	|| die Config::Simple->error(), ".\n",
	"Please check the syntax in daemon.conf.";
    return $config;
}
