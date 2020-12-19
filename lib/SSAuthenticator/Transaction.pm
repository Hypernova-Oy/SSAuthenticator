package SSAuthenticator::Transaction;

use SSAuthenticator::Pragmas;

sub new {
  return bless({}, $_[0]);
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
sub pinLatestKeyStatus {
  $_[0]->{pinLatestKeyStatus} = $_[1] if (defined($_[1]));
  return $_[0]->{pinLatestKeyStatus};
}

sub statusesToString {
  my ($s) = @_;
  return join(', ', map {($_ !~ /^_/) ? $_.'='.$s->{$_} : ''} sort keys(%$s));
}

sub oledMessages {
    my ($self, $type, $rows) = @_;
    $self->{_oledMessages} = [] if (not($self->{_oledMessages}));
    if ($type && $rows) {
        push(@{$self->{_oledMessages}}, [$type, $rows]);
    }
    return $self->{_oledMessages};
}

1;
