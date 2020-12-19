package SSAuthenticator::Password;

use Encode;
use Crypt::Eksblowfish::Bcrypt;


=head1 COPYRIGHT NOTICE

Most of the code here is borrowed from Koha ILS => Koha::AuthUtils -package. Both licensed under GPL-3 or similar.

=cut

sub check_password {
    my ($cardnumber, $pw_plain, $pw_hashed) = @_;
    return 1 if (hash_password($pw_plain, $cardnumber) eq $pw_hashed);
    return 0;
}

=head2 hash_password
    my $hash = Koha::AuthUtils::hash_password($password, $settings);
=cut

# Using Bcrypt method for hashing. This can be changed to something else in future, if needed.
sub hash_password {
    my ($password, $cardnumber) = @_;
    $password = Encode::encode( 'UTF-8', $password )
      if Encode::is_utf8($password);

    $settings = '$2a$08$'.Crypt::Eksblowfish::Bcrypt::en_base64(generate_salt($cardnumber));
    return Crypt::Eksblowfish::Bcrypt::bcrypt($password, $settings);
}

sub generate_salt {
    die "Cannot generate salt with an empty seed?" unless(defined($_[0]) && length($_[0]) > 0);
    while (length($_[0]) < 16) {
        $_[0] = $_[0].$_[0];
    }
    return substr($_[0],0,16);
}

1;
