# Authenticator

Authenticator is a system daemon that controls access to a library
using Koha instance's REST API and its local cache as fallback.

## Installation

Prerequisites:

* Barcode reader that has a serial interface. The device should show
up in the following format /dev/ttyACM?, where '?' is some integer.

* If using Datalogic GFS4400 you should put the device to serial mode by
scanning the QR code provided in the manual for interface 'USB-COM'.

* The reading from the barcode scanner should end in a newline
character ('\n').

Raspian:
```
$ wget http://raspberry.znix.com/hipifiles/hipi-install
$ sudo perl hipi-install

# Download debian package from https://github.com/KohaSuomi/SSAuthenticator/releases, for example:
$ wget https://github.com/KohaSuomi/SSAuthenticator/releases/download/v0.10/authenticator_0.10-1_all.deb

$ sudo dpkg -i authenticator_<version>_all.deb
$ sudo apt-get install -f

# Edit configure file (mandatory)
# Instructions on how to do that are provided in that file
$ sudo $EDITOR /etc/authenticator/daemon.conf

# Finally reboot in order for the barcodescanner udev rules to take place
$ sudo reboot
```

## Development

For development and packaging you want the following packages:

Rasbian:
```
$ sudo apt-get install perl libtest-simple-perl libtest-mockmodule-perl \
libmodern-perl-perl libconfig-simple-perl libdbm-deep-perl \
libwww-perl libjson-perl libsys-sigaction-perl libdatetime-perl \
libdatetime-format-http-perl libdigest-sha-perl
```

### Release process

```
$ git clone https://github.com/KohaSuomi/SSAuthenticator --depth=1

$ cd SSAuthenticator

# Update Debian changelog (add release info and new version (X.XX)).
# dch will launch you an editor where you can update the changelog.
$ dch -v X.XX-1

# Update the version number in lib/Authenticator.pm, too!
$ $EDITOR lib/Authenticator.pm

$ mv SSAuthenticator authenticator-X.XX

$ mkdir Packaging && cd Packaging
$ tar -cvzf authenticator_X.XX.orig.tar.gz ../authenticator-X.XX
$ tar -xzmf authenticator_X.XX.orig.tar.gz
$ cd authenticator-X.XX

# Create .deb package, will appear in one directory above current.
# If you want signed package, leave -uc -us out.
$ debuild -uc -us
```

After that you can create in Github a new release and attach the
generated binary to it.


## License

Authenticator is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or (at
your option) any later version.

Authenticator is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with Authenticator; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
02110-1301 USA
