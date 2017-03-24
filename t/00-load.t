#!/usr/bin/perl
#
# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

use Modern::Perl;
use Test::More;

use File::Find;

subtest "Compile all modules", \&compile;
sub compile {
    File::Find::find({
            no_chdir => 1,
            wanted => sub {
                require_ok($File::Find::name) if ($_ =~ m/\.pm$/);
            },
        },
        'lib', 't', #Directories to look for files
    );
}
