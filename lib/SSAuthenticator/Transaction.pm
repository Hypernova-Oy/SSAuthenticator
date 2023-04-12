package SSAuthenticator::Transaction;

use SSAuthenticator::Pragmas;

sub new {
  my $self =  bless({}, $_[0]);
  $self->{_oledMessages} = [];
  $self->{_pinKeyEvents} = [];
  return $self;
}

=head attributes

        'auth',               # Overall status of authentication for the User access transaction
        'cacheUsed',          # Was any of the caches used?
        'cacheFlushed',       #
        'cardAuthz',          # Authorization of the Card-based access. Card in itself authenticates the user, but also has linked authorization.
        'cardAuthzCacheUsed', # Was cache used for the card-based access control check?
        'cardCached',         #
        'cardCacheFlushed',   #
        'pinAuthn',           # Authnetication result of the pin-code access control check
        'pinAuthnCacheUsed',  # Was cache used to check the PIN-code?
        'pinCached',          #
        'pinCacheFlushed',    # 
        'pinCode',            # PIN-code of the User
        'pinLatestKeyStatus', # Status of the PIN-transaction after the latest key input. Eg. are there enough characters entered?

re-match     ^(\w+?)$
re-replace   sub $1 {\n  $_[0]->{$1} = $_[1] if (defined($_[1]));\n  return $_[0]->{$_[1]};\n}

=cut

sub auth {
  $_[0]->{auth} = $_[1] if (defined($_[1]));
  return $_[0]->{auth};
}
sub cacheUsed {
  $_[0]->{cacheUsed} = $_[1] if (defined($_[1]));
  return $_[0]->{cacheUsed};
}
sub cacheFlushed {
  $_[0]->{cacheFlushed} = $_[1] if (defined($_[1]));
  return $_[0]->{cacheFlushed};
}
sub cardAuthz {
  $_[0]->{cardAuthz} = $_[1] if (defined($_[1]));
  return $_[0]->{cardAuthz};
}
sub cardAuthzCacheUsed {
  $_[0]->{cardAuthzCacheUsed} = $_[1] if (defined($_[1]));
  return $_[0]->{cardAuthzCacheUsed};
}
sub cardAuthzTimedOut {
  $_[0]->{cardAuthzTimedOut} = $_[1] if (defined($_[1]));
  return $_[0]->{cardAuthzTimedOut};
}
sub cardCached {
  $_[0]->{cardCached} = $_[1] if (defined($_[1]));
  return $_[0]->{cardCached};
}
sub cardCacheFlushed {
  $_[0]->{cardCacheFlushed} = $_[1] if (defined($_[1]));
  return $_[0]->{cardCacheFlushed};
}
sub pinAuthn {
  $_[0]->{pinAuthn} = $_[1] if (defined($_[1]));
  return $_[0]->{pinAuthn};
}
sub pinAuthnCacheUsed {
  $_[0]->{pinAuthnCacheUsed} = $_[1] if (defined($_[1]));
  return $_[0]->{pinAuthnCacheUsed};
}
sub pinAuthnTimedOut {
  $_[0]->{pinAuthnTimedOut} = $_[1] if (defined($_[1]));
  return $_[0]->{pinAuthnTimedOut};
}
sub pinCached {
  $_[0]->{pinCached} = $_[1] if (defined($_[1]));
  return $_[0]->{pinCached};
}
sub pinCacheFlushed {
  $_[0]->{pinCacheFlushed} = $_[1] if (defined($_[1]));
  return $_[0]->{pinCacheFlushed};
}
sub pinCode {
  $_[0]->{_pinCode} = $_[1] if (defined($_[1]));
  return $_[0]->{_pinCode};
}
sub pinKeyEvents {
  #my ($self, $tuple_key_status) = @_;
  push(@{$_[0]->{_pinKeyEvents}}, $_[1]) if $_[1];
  return $_[0]->{_pinKeyEvents};
}
sub pinLatestKeyStatus {
  return $_[0]->{_pinKeyEvents}->[-1]->[1] if $_[0]->{_pinKeyEvents}->[-1];
  return 0;
}
sub pinOldKeyStatus {
  return $_[0]->{_pinKeyEvents}->[-2]->[1] if $_[0]->{_pinKeyEvents}->[-2];
  return 0;
}
sub pinStateTransitionedTo {
  #my ($self, $targetStatus) = @_;
  return 1 if $_[0]->pinLatestKeyStatus == $_[1] && $_[0]->pinOldKeyStatus != $_[0]->pinLatestKeyStatus;
  return 0;
}

sub statusesToString {
  my ($s) = @_;
  return join(', ', map {($_ !~ /^_/) ? $_.'='.$s->{$_} : ''} sort keys(%$s));
}

sub oledMessages {
    my ($self, $type, $rows) = @_;
    if ($type && $rows) {
        push(@{$self->{_oledMessages}}, [$type, $rows]);
    }
    return $self->{_oledMessages};
}

1;
