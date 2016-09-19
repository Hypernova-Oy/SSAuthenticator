#!/usr/bin/perl
#
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#
# SSAuthenticator is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SSAuthenticator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with SSAuthenticator.  If not, see <http://www.gnu.org/licenses/>.

package t::Examples;

use Modern::Perl;

use File::Temp;

use Authenticator;

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
    Authenticator::unloadConfig();
}

1;
