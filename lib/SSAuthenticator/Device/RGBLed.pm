package SSAuthenticator::Device::RGBLed;

use POSIX;
use Time::HiRes;

use SSAuthenticator::Pragmas;

my $l = bless({}, 'SSLog');

my %leds = ();

sub init {
    my ($config) = @_;
    $config = SSAuthenticator::Config::getConfig() unless $config;
    $leds{red}   = GPIO->new($config->param('RedLEDPin'));
    $leds{green} = GPIO->new($config->param('GreenLEDPin'));
    $leds{blue}  = GPIO->new($config->param('BlueLEDPin'));
}
sub ledOn {
    my ($colour) = @_;
    $leds{$colour}->turnOn();
    return 1;
}
sub ledOff {
    my ($colour) = @_;
    $leds{$colour}->turnOff();
    return 1;
}

sub ledShow {
    my $pid = fork();
    if ($pid == 0) {
        my $i = 100;
        while ($i-- > 0) {
            my $r = POSIX::floor(rand(6));
            print($r);
            $leds{red}->turnOn()    if ($r == 0);
            $leds{red}->turnOff()   if ($r == 1);
            $leds{green}->turnOn()  if ($r == 2);
            $leds{green}->turnOff() if ($r == 3);
            $leds{blue}->turnOn()   if ($r == 4);
            $leds{blue}->turnOff()  if ($r == 5);
            Time::HiRes::sleep(0.1);
        }
        exit;
    }
    else {
        return;
    }
}

1;
