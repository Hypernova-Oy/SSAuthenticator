# Copyright (C) 2020 Hypernova Oy
#
# This file is part of SSAuthenticator.
#

package t::Mocks::SerialDevice;

use Time::HiRes;

sub new {
  my ($class, $responses) = @_;
  my $s = bless({}, $class);
  $s->{response} = $responses;
  die "'responses' is not an array of responses with delays" unless ref($responses) eq 'ARRAY';
  return $s;
}

sub read {
  my $resp = shift(@{$s->{response}});
  Time::HiRes::sleep($resp->[0]) if $resp->[0];
  return $resp->[1];
}

return 1;
