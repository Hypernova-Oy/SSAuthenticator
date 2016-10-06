#!/usr/bin/perl
#
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package t::Examples;

use Modern::Perl;

use File::Temp;

use SSAuthenticator;

my $tempConfFile;
sub _writeTempConf {
    my ($content) = @_;
    $tempConfFile = File::Temp->new();

    open(my $FILE, '>>', $tempConfFile->filename) or die $!;
    print $FILE $content;
    close $FILE;

    return $tempConfFile;
}

sub _getDefaultConf {
    return <<CONF;
ApiBaseUrl http://localhost-api/api/v1
LibraryName MyTestLibrary
ApiKey testAPikey
ApiUserName testUser
GreenLEDPin 22
BlueLEDPin 27
RedLEDPin 17
DoorPin 25
RTTTL-PlayerPin 1

CONF
}
sub writeDefaultConf {
    my $content = _getDefaultConf();
    return _writeTempConf($content);
}

sub writeBadConnectionTimeoutConf {
    my $content = _getDefaultConf();
    $content .= "ConnectionTimeout testString\n\n";
    return _writeTempConf($content);
}

sub rmConfig {
    $tempConfFile->DESTROY();
    SSAuthenticator::unloadConfig();
}

1;
