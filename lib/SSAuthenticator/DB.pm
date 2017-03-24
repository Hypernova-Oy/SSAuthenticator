# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.


package SSAuthenticator::DB;

use Modern::Perl;

use Data::Dumper;
use DBM::Deep;

use SSLog;

=head1 SSAuthenticator::DB

Manage database access for this daemon

=cut

my $l = SSLog->get_logger(); #Package logger

my $CARDNUMBER_FILE = "/var/cache/ssauthenticator/patron.db";
sub getDB {
    my ($newDB) = @_;
    $CARDNUMBER_FILE = $newDB if $newDB;
    my $CARDNUMBER_DB = DBM::Deep->new($CARDNUMBER_FILE);
    return $CARDNUMBER_DB;
}

sub setDB {
    my ($dbPath) = @_;
    my $oldCARDNUMBER_FILE = $CARDNUMBER_FILE;
    $CARDNUMBER_FILE = $dbPath;
    return $oldCARDNUMBER_FILE;
}

sub clearDB {
    getDB()->clear();
}

1;
