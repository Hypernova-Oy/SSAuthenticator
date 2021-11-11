package SSAuthenticator::Pragmas;

=head1 NAME

Pragmas

=head2 SYNOPSIS

Shared pragmas and modules for all Bonkers modules.

=cut

binmode( STDOUT, ":encoding(UTF-8)" ); #Afaik this sets the shared handles for all modules
binmode( STDIN,  ":encoding(UTF-8)" );

use Import::Into;

=head2 import

Imports the shared pragmas and modules into the calling module.

=cut

sub import {
  my $target = caller;
  my %args = map {$_ => 1} @_;

  #Pragmas
  Modern::Perl->import::into($target, '2018');
  utf8->import::into($target); #This file and all Strings within are utf8-encoded
  Carp::Always->import::into($target);
  English->import::into($target);
  Try::Tiny->import::into($target);

  #External modules
  Data::Printer->import::into($target, {
    class => {
      internals  => 1,       # show internal data structures of classes

      inherited  => 'none',  # show inherited methods,
                              # can also be 'all', 'private', or 'public'.

      universal  => 0,       # include UNIVERSAL methods in inheritance list

      parents    => 1,       # show parents, if there are any
      linear_isa => 'auto',  # show the entire @ISA, linearized, whenever
                              # the object has more than one parent. Can
                              # also be set to 1 (always show) or 0 (never).

      expand     => 1,       # how deep to traverse the object (in case
                              # it contains other objects). Defaults to
                              # 1, meaning expand only itself. Can be any
                              # number, 0 for no class expansion, and 'all'
                              # to expand everything.

      sort_methods => 1,     # sort public and private methods

      show_methods => 'none'  # method list. Also 'none', 'public', 'private'
    },
  });
  Scalar::Util->import::into($target, 'blessed', 'weaken');
  Storable->import::into($target, 'dclone');

  #Local modules
  SSLog->import::into($target);
}

1;

