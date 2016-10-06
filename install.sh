#!/bin/bash
## IN THIS FILE
#
# This is the installer for SSAuthenticator dependencies and packages
#

echo ""
echo "INSTALLING SSAuthenticator"
echo ""

wget http://raspberry.znix.com/hipifiles/hipi-install
sudo perl hipi-install 

wget https://github.com/KohaSuomi/SSAuthenticator/releases/download/v0.10/ssauthenticator_0.10-1_all.deb
dpkg -i authenticator_0.10-1_all.deb
sudo apt-get install -f -y

echo ""
echo "INSTALLATION COMPLETE"
echo "manually configure /etc/authenticator/daemon.conf"
echo ""
echo ""
