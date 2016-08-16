#!/bin/bash
## IN THIS FILE
#
# This is the installer for SSAuthenticator dependencies and packages
#

echo ""
echo "INSTALLING SSAuthenticator"
echo ""

apt-get install -y \
libconfig-simple-perl \
libdatetime-format-http-perl \
libdatetime-perl \
libdbm-deep-perl \
libdigest-sha-perl \
libjson-perl \
libmodern-perl-perl \
libsys-sigaction-perl \
libtest-simple-perl \
libtest-mockmodule-perl \
libwww-perl \
perl \


wget http://raspberry.znix.com/hipifiles/hipi-install
sudo perl hipi-install 

wget https://github.com/KohaSuomi/SSAuthenticator/releases/download/v0.10/authenticator_0.10-1_all.deb
dpkg -i authenticator_0.10-1_all.deb

echo ""
echo "INSTALLATION COMPLETE"
echo "manually configure /etc/authenticator/daemon.conf"
echo ""
echo ""
