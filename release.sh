version=$( head debian/changelog -n1 | sed 's/.*(//' | sed 's/-.*//')

cd ..

mkdir SSAuthenticator-packaging && cd SSAuthenticator-packaging

cp ../SSAuthenticator ssauthenticator-$version -r

tar -cvzf ssauthenticator_$version.orig.tar.gz ssauthenticator-$version
cd ssauthenticator-$version

debuild -uc -us
