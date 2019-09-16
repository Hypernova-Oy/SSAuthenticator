package SSAuthenticator::Device::WGC300UsbAT::Commands;

use SSAuthenticator::Pragmas;

my $logger = bless({}, 'SSLog');

# Define the message elements a typical message consists of
my @messageFormat = qw(Length MessageSource MessageTarget Reserve Opcode Command Beeper CheckSum);

my $defaults = {
  MessageSource => sub { return 0x04 },
  MessageTarget => sub { return 0x31 },
  Reserve       => sub { return 0x00 },
  Beeper        => sub { return 0x31 // 0xFF }, # 0xFF Disable, 0x31 Enable
  CheckSum      => sub { return checkSum(@_) }, # This must always be calculated case-by-case
};

my $commands = {
  '%SET' => {
    Description => 'Enter setting mode',
    Length => 0x0A,
    Opcode => 0x24,
    Command => asBytesStream('%SET'),
  },
  '%END' => {
    Description => 'Save & Exit',
    Length => 0x0A,
    Opcode => 0x24,
    Command => asBytesStream('%END'),
  },
  'LT' => {
    Description => 'Trigger scan',
    Length => 0x08,
    Opcode => 0x26,
    Command => asBytesStream('LT'),
  },
  'LS' => {
    Description => 'Stop scan',
    Length => 0x8,
    Opcode => 0x27,
    Command => asBytesStream('LS'),
  },
  'DF' => {
    Description => 'Restore factory default',
    Length => 0x08,
    Opcode => 0x28,
    Command => asBytesStream('DF'),
  },
  'RV' => {
    Description => 'Read program version',
    Length => 0x08,
    Opcode => 0x2B,
    Command => asBytesStream('RV'),
  },
  'OPEN_BEEPER' => {
    Description => 'Maybe beeps?',
    Length => 0x0F,
    Opcode => 0x31,
    Command => [0x2F, 0x03, 0x05, 0x04, 0x01, 0x04, 0x05, 0x04, 0x0A],
  },
  'ACK' => {
    Description => 'Maybe talks back?',
    Length => 0x07,
    Opcode => 0x3F,
    Command => [0x2F],
  },
  'E0001' => {
    Description => 'Enable respond',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('E0001'),
  },
  'F0001' => {
    Description => 'Continuous read',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('F0001'),
  },
  'F0102' => {
    Description => 'Continuous read - Multiple Read',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('F0102'),
  },
  'F0220' => {
    Description => 'Multiple Read - Repeat read delay 2000ms',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('F0220'),
  },
  'F0410' => {
    Description => 'Serial command/infrared self-sensing trigger scan timeout 1000ms',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('F0410'),
  },
  'I1000' => {
    Description => 'Disable read all barcodes',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('I1000'),
  },
  'I1001' => {
    Description => 'Enable read all barcodes',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('I1001'),
  },
  'IF001' => {
    Description => 'Code39 Enable',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('IF001'),
  },
  'IF810' => {
    Description => 'Code39 Min barcode length 10',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('IF810'),
  },
  'IF912' => {
    Description => 'Code39 Max barcode length 12',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('IF912'),
  },
  'TTL/RS232' => {
    Description => 'Data output mode - TTL/RS232 -mode',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('A0000'),
  },
  'USB_HID' => {
    Description => 'Data output mode - USB HID Keyboard',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('A0001'),
  },
  'USB_COM' => {
    Description => 'Data output mode - USB virtual com port',
    Length => 0x0B,
    Opcode => 0x50,
    Command => asBytesStream('A0002'),
  },
};

sub getCommand {
  my ($commandName) = @_;
  $logger->trace("Building message for command '$commandName'");

  my $conf = $commands->{$commandName} || die "Unkown command '$commandName'! Available commands [".availableCommandNamesString()."]";

  my @bytes;
  for my $messageElement (@messageFormat) {
    $logger->trace("Building message element '$messageElement'");
    die "Unknown message element '$messageElement' for command '$commandName'!" unless ($conf->{$messageElement} || $defaults->{$messageElement});
    my $data = $conf->{$messageElement} // $defaults->{$messageElement}->(\@bytes) // die "Message element '$messageElement' for command '$commandName' is undef!";
    push(@bytes, (ref $data eq 'ARRAY') ? @$data : $data);
  }

  return { codePoints => \@bytes, description => $conf->{Description} };
}

sub asBytesStream {
  my ($string) = @_;
  my @bytes;
  push(@bytes, ord) for (split('', $string));
  $logger->trace("Translated '$string' to '".dumpBytesString(\@bytes)."'");
  return \@bytes;
}

=head2 checkSum

1. Check Sum: Radix complement of command sum, high byte in the beginning and low byte in the end.
   Check digit calculation method:
     Adding up all bytes to get sum before checking (excluding two check digit bytes).
     Check digit value=Sum reversed as per digit then add one. 
   Example:
     Save & Exit (0A 04 31 00 24 25 45 4E 44 FF)
     adding up to obtain the sum:
       02 5E
     switch to binary (0000 0010 0101 1110),
     then reverse (1111 1101 1010 0001),
     finally add one is check digit
       FD A2

=cut

sub checkSum {
  my ($bytes) = @_;

  my $sum = 0;
  $sum += $_ for @$bytes;
  $logger->trace("Checksum sum is '$sum'");

  my $cs = (~$sum & 0xFFFF) # Complement the bits, but only pick the first 2 bytes we are interested in.
           +1;              # Add +1 per the Radix complement algorithm
  $logger->trace("Checksum Radix complement is '$cs'");

  #Now the dirty ugly formatting hack to split the checksum to two bytes.
  my @csBytes = (
    ($cs & 0xFF00) >> 8,   # Shift the second byte to right, this pushes the first byte out and leaves only the second byte
    $cs & 0x00FF, # Pick the first byte by AND-masking the first 8 bits
  );
  $logger->trace("Checksum for bytes [".dumpBytesString(\@$bytes)."] is [".dumpBytesString(\@csBytes)."]");
  return \@csBytes;
}

sub availableCommandNamesString {
  return join(", ", sort keys %$commands );
}

sub dumpBytesString {
  my ($bytes) = @_;
  my @bytes;
  push(@bytes, sprintf("%02X", $_)) for @$bytes;
  return join(' ', @bytes);
}

1;
