package SSAuthenticator::Util;

=head1 NAME

Util

=head2 SYNOPSIS

Stuff

=cut

use SSAuthenticator::Pragmas;


# Thanks O'Reilly
# https://www.oreilly.com/library/view/mastering-perl/9780596527242/ch08.html
# https://metacpan.org/pod/Symbol::Get
sub get_constant_name {
  my ($package_name, $constant_value) = @_;

  no strict 'refs';

  my $symbol_table = $package_name . '::';
  for my $variable_name (keys %$symbol_table) {
    my $scalar = ${*{$symbol_table->{$variable_name}}{SCALAR}};
    next unless ($scalar);
    return $variable_name if ($scalar eq $constant_value);
#    next unless *{$symbol_table->{$variable_name}}{CODE}->() eq $constant_value;
#    return *{$symbol_table->{$variable_name}}{NAME};
  }
}

sub as_hex {
  my ($m) = @_;
  my @a; push(@a,unpack(" H* ", $_)) for (split(//, $m));
  return 'HEX: '.join(" ", @a).' UTF8='.Encode::is_utf8($m);
}

1;

