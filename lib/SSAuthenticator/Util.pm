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
    next unless _is_constant($package_name, $variable_name);
    next unless *{$symbol_table->{$variable_name}}{CODE}->() eq $constant_value;   
    return *{$symbol_table->{$variable_name}}{NAME};
  }
}

sub _is_constant {
  my ($package_name, $variable_name) = @_;

  no strict 'refs';

  ### is it a subentry?
  my $sub = $package_name->can( $variable_name );
  return undef unless defined $sub;

  return undef unless defined prototype($sub) and 
                       not length prototype($sub);

  return 1;
}

1;

