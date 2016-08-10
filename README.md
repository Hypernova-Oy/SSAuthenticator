=== Authenticator ===

Authenticator is a system daemon that controls access to a library
using Koha instance's REST API and its local cache as fallback.

=== License ===

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or (at
your option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
02110-1301 USA

=== Installation ===

Prerequisites:

* Barcode reader that has a serial interface. The device should show
up in the following format /dev/ttyACM?, where '?' is some integer.

* If using Datalogic GFS4400 you should put the device to serial mode by
scanning the QR code provided in the manual for interface 'USB-COM'.

* The reading from the barcode scanner should end in a newline
character ('\n').

=== Package dependencies ===

Raspian:

perl libtest-simple-perl libtest-mockmodule-perl \
libmodern-perl-perl libconfig-simple-perl libdbm-deep-perl \
libwww-perl libjson-perl libsys-sigaction-perl