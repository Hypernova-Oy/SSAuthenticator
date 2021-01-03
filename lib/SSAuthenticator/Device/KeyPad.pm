package SSAuthenticator::Device::KeyPad;

use SSAuthenticator::Pragmas;

use Device::SerialPort;
use Time::HiRes;

use SSAuthenticator::Exception::KeyPad::WaitTimeout;

our $KEYPAD_TRANSACTION_OVERFLOW = 1;
our $KEYPAD_TRANSACTION_UNDERFLOW = 2;
our $KEYPAD_TRANSACTION_DONE = 3;
our $KEYPAD_TRANSACTION_MAYBE_DONE = 4;

my $logger = bless({}, 'SSLog');

my $kp; #We can have only one Reader, so far.

sub init {
  $kp->DESTROY() if $kp;
  $kp = __PACKAGE__->new(@_) unless $kp;
  return $kp;
}

sub new {
  $logger->info("KeyPad::new():>");
  my ($class, $config) = @_;
  my $s = bless({}, $class);
  $s->{key_buffer} = '';
  $s->{transaction_timeout_s} = $config->param('PINTimeout')/1000;
  $s->{code_length_min} = $config->param('PINLength');
  $s->{code_length_max} = $config->param('PINLength');
  $s->{keypad_on_pin}  = GPIO->new($config->param('PINOnPin'));
  $s->{keypad_off_pin} = GPIO->new($config->param('PINOffPin'));

  $s->_transaction_new();
  $s->connectSerial();
  $s->_create_pin_progress_meter_template();
  return $s;
}

sub connectSerial {
  my ($s) = @_;

  my $portObj = Device::SerialPort->new('/dev/ttyAMA0', 0) || die "Can't open '/dev/ttyAMA0': $!\n";
  $portObj->baudrate(9600);
  $portObj->parity("none");
  $portObj->databits(8);
  $portObj->stopbits(1);
  $portObj->handshake("none");
  $portObj->user_msg(1);       # built-in instead of warn/die above
  $portObj->error_msg(1);      # translate error bitmasks and carp
  #$portObj->debug(1);

  # These are unnecessary on Ubuntu 18.04
  $portObj->read_char_time(0);     # don't wait for each character
  $portObj->read_const_time(1000); # 1 second per unfulfilled "read" call

  $portObj->write_settings || die "write_settings failed: $!";
  $s->{dev} = $portObj;
}

sub _create_pin_progress_meter_template {
  my ($s) = @_;
  $s->{pin_progress_template} = (' 'x($s->{code_length_min}-1)).'I'.(' 'x(20-$s->{code_length_max})) if ($s->{code_length_min} == $s->{code_length_max});
  $s->{pin_progress_template} = (' 'x($s->{code_length_min}-1)).'I'.(' 'x($s->{code_length_max}-$s->{code_length_min}-1)).'I'.(' 'x(20-$s->{code_length_max})) unless ($s->{code_length_min} == $s->{code_length_max});
  $logger->info("KeyPad::new():> pin_progress_template='".$s->{pin_progress_template}."'");
}

sub _transaction_new {
  my ($s) = @_;
  $logger->info("KeyPad::_transaction_new():>");

  $s->{keys_read_idx} = -1;
  $s->{last_key_press_s} = time();
  $s->{key_buffer} = '';
}

sub _read { # Used to easily mock the serial read interface, to inject timeout behaviour here.
  return $_[0]->{dev}->read($_[1]); # Device read() returns immediately with data or no
}

sub wait_for_key {
  my ($s) = @_;

  my ($count, $c);

  my $waiting_started_s = Time::HiRes::time();
  do {
    ($count, $c) = $s->_read(1);

    if (Time::HiRes::time() - $waiting_started_s >= $s->{transaction_timeout_s}) { # Check for time first, to make testing the timeout triggering more easy.
      $logger->trace("KeyPad::wait_for_key():> Wait timeout. Now='".Time::HiRes::time()."', waiting started='$waiting_started_s', transaction timeout='".$s->{transaction_timeout_s}."'");
      $s->_transaction_new();
      SSAuthenticator::Exception::KeyPad::WaitTimeout->throw();
    }

    if ($c eq "") {
      $logger->error("KeyPad::wait_for_key():> KeyPad is not on!") if $logger->is_trace();
      $c = -1;
    }
    elsif ($c != -1) {
      $logger->trace("KeyPad::wait_for_key():> Key received!") if $logger->is_trace();
      $s->_push_key($c);
      # last; # lst in do-while raises a warning :(
    }
    else {
      Time::HiRes::sleep(0.1);
    }
  } while ($c == -1);
  return $c;
}

sub flush_buffer {
  my ($s) = @_;
  my ($count, $c);
  do {
    ($count, $c) = $s->_read(1);
    print($c);
  } while (not($c eq "" || $c != -1)); #When the KeyPad is off, it returns "", otherwise -1
}

sub _push_key {
  my ($s, $c) = @_;
  $s->{keys_read_idx}++;
  $s->{key_buffer} .= $c;
  $s->{last_key_press_s} = Time::HiRes::time();
  return $s;
}

sub maybe_transaction_complete {
  my ($s) = @_;
  if ($s->{keys_read_idx} == $s->{code_length_max}) {
    $s->_transaction_new();
    return $KEYPAD_TRANSACTION_OVERFLOW;
  }
  elsif ($s->{keys_read_idx} < $s->{code_length_min}-1) {
    return $KEYPAD_TRANSACTION_UNDERFLOW;
  }
  elsif ($s->{code_length_min} == $s->{code_length_max} && $s->{keys_read_idx} == $s->{code_length_min}-1) {
    return $KEYPAD_TRANSACTION_DONE;
  }
  else {
    return $KEYPAD_TRANSACTION_MAYBE_DONE;
  }
}

sub turnOn {
  my ($s) = @_;
  $s->{keypad_on_pin}->turnOn();
  Time::HiRes::sleep(0.1);
  $s->{keypad_on_pin}->turnOff();
  $s->{_device_on} = 1;
}

sub turnOff {
  my ($s) = @_;
  $s->{keypad_off_pin}->turnOn();
  Time::HiRes::sleep(0.1);
  $s->{keypad_off_pin}->turnOff();
  $s->{_device_on} = 0;
}

sub isOn {
  return $_[0]->{_device_on};
}

1;
