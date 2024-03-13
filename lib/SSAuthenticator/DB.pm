# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.


package SSAuthenticator::DB;

use Modern::Perl;

use Data::Dumper;
use DBM::Deep;

use SSAuthenticator::Pragmas;

=head1 SSAuthenticator::DB

Manage database access for this daemon

=cut

my $l = bless({}, 'SSLog');

my $CARDNUMBER_FILE = "/var/cache/ssauthenticator/patron.db";
my $db = DBM::Deep->new($CARDNUMBER_FILE);

sub getDB {
    return $db;
}

sub setDB {
    my ($dbPath) = @_;
    my $oldCARDNUMBER_FILE = $CARDNUMBER_FILE;
    $CARDNUMBER_FILE = $dbPath;
    $db = DBM::Deep->new($CARDNUMBER_FILE);
    return $oldCARDNUMBER_FILE;
}

sub clearDB {
    getDB()->clear();
}

1;
