version=$( head debian/changelog -n1 | sed 's/.*(//' | sed 's/-.*//')

cd ..

mkdir Authenticator-packaging && cd Authenticator-packaging

cp ../SSAuthenticator authenticator-$version -r

tar -cvzf authenticator_$version.orig.tar.gz authenticator-$version
cd authenticator-$version

debuild -uc -us
