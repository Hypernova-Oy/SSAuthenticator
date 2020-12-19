# Copyright (C) 2020 Hypernova Oy
#
# This file is part of SSAuthenticator.

package SSAuthenticator::SharedState;

=head SYNOPSIS

SharedState is a hack to share information that is difficult to move between subroutine calls.
A result of poor architecture, but too expensive to refactor everything.

Certain $authorization-statuses have extra parameters that need to be displayed. Use this package variable
as a hack to deliver parameters through the authorization-stack without needing to refactor everything.

=cut

use SSAuthenticator::Pragmas;
my $l = bless({}, 'SSLog');

our %state = (
  openingTime => undef,
  closingTime => undef,
);

sub set {
  $l->debug("SharedState::set(@_)");
  $state{$_[0]} = $_[1];
  return $state{$_[0]};
}

sub get {
  $l->debug("SharedState::get(@_)");
  return $state{$_[0]};
}

1;
