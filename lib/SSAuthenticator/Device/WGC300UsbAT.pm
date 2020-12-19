package SSAuthenticator::Device::WGC300UsbAT;

use SSAuthenticator::Pragmas;

use SSAuthenticator::Device::WGC300UsbAT::Commands;

use Device::SerialPort;
use Time::HiRes;

my $logger = bless({}, 'SSLog');

my $reader; #We can have only one Reader, so far.
sub new {
  my ($class) = @_;
  $reader = bless({}, $class) unless $reader;
  return $reader;
}

sub init {
  my ($s, $portName) = @_;

  my $portObj = Device::SerialPort->new($portName, 0) || die "Can't open $portName: $!\n";
  $portObj->baudrate(9600); #115200
  $portObj->parity("none");
  $portObj->databits(8);
  $portObj->stopbits(1);
  $portObj->handshake("none");
  $portObj->user_msg(1);       # built-in instead of warn/die above
  $portObj->error_msg(1);      # translate error bitmasks and carp
  #$portObj->debug(1);

  # These are unnecessary on Ubuntu 18.04
  $portObj->read_char_time(0);     # don't wait for each character
  $portObj->read_const_time(0); # 1 second per unfulfilled "read" call

  $portObj->write_settings || die "write_settings failed: $!";
  $s->{dev} = $portObj;
}

sub sendCommand {
  my ($s, $commandCode) = @_;

  my $command = SSAuthenticator::Device::WGC300UsbAT::Commands::getCommand($commandCode);
  my $codePointsInDecimal = $command->{codePoints};
  $logger->trace("Sending command '$commandCode' - '".$command->{description}."'");

  my $str = join('', map {chr($_)} @$codePointsInDecimal);
  my $hexes = join(' ', map {sprintf("%02X", $_)} @$codePointsInDecimal);
  $logger->trace("Sending: '$str'");

  my $countOut = $s->{dev}->write($str) or die "Unable to send message '$hexes': $!";
  $logger->trace("Wrote '$countOut' characters with message '$hexes'");

  $s->pollData(1);
}

sub pollData {
  my ($s, $timeout) = @_;
  $timeout = 10 unless($timeout);

  my $timeoutLeft = $timeout*10;
  my $chars = 0;
  my $buffer = "";

  while ($timeoutLeft > 0) {
    my ($count, $saw) = $s->receiveData();
    if ($count && $count > 0) {
      $chars += $count;
      $buffer.= $saw;

      my @hexes = map {sprintf("%02X", ord($_))} split('', $buffer);
      $logger->trace("Received '$count' characters: string:'$saw' hex:[@hexes]");
      return $saw;
    }
    else {
      Time::HiRes::sleep(0.1);
      $timeoutLeft--;
    }
  }

  if ($timeoutLeft == 0) {
    $logger->trace("Timed out in '$timeout' seconds/ticks.");
  }
  return undef;
}

sub receiveData {
  my ($s) = @_;
  my ($count, $data) = $s->{dev}->read(255);
  return ($count, $data) unless ($count && $data);

  $data =~ s/(:?^\s+)|(:?\s+$)//g;
  chomp $data;
  return ($count, $data);
}

sub autoConfigure {
  my ($s) = @_;

  my @configurations = qw(%SET I1000 IF001 IF810 IF912 F0001 F0102 F0220 %END);

  $s->sendCommand($_) for @configurations;
}

sub close {
  my ($s) = @_;
  $s->{dev}->close() || die "Failed to close: $!";
}

sub DESTROY {
  my ($s) = @_;
  $s->close();
}

# Initialize the singleton
unless ($reader) {
  $reader = new(__PACKAGE__);
  $reader->init("/dev/ttyWGC300USBAt");
  #$reader->autoConfigure();
}

1;
