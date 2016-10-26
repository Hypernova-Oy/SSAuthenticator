programName=ssauthenticator
confDir=etc/$(programName)
systemdServiceDir=etc/systemd/system
cacheDir=/var/cache/$(programName)
udevDir=udev/rules.d
systemUdevDir=/lib/$(udevDir)
systemPath=/usr/local/bin

#Macro to check the exit code of a make expression and possibly not fail on warnings
RC      := test $$? -lt 100 


build: compile

install: build configure perlDeploy scriptsLink translateDeploy serviceEnable

perlDeploy:
	./Build installdeps
	./Build install

compile:
	#Build Perl modules
	perl Build.PL
	./Build

test:
	prove -Ilib -I. t/*.t

configure:
	mkdir -p /$(confDir)
	cp $(confDir)/daemon.conf /$(confDir)/
	cp $(systemdServiceDir)/$(programName).service /$(systemdServiceDir)/$(programName).service

	mkdir -p $(cacheDir)
	touch $(cacheDir)/patron.db

	cp $(udevDir)/50-$(programName).rules $(systemUdevDir)/

unconfigure:
	rm -r /$(confDir) || $(RC)
	rm -r $(cacheDir)
	rm $(systemUdevDir)/50-$(programName).rules

serviceEnable:
	systemctl daemon-reload
	systemctl enable $(programName)
	systemctl start $(programName)

serviceDisable:
	systemctl stop $(programName)
	rm /$(systemdServiceDir)/$(programName).service
	systemctl daemon-reload

scriptsLink:
	cp scripts/$(programName) $(systemPath)/

scriptsUnlink:
	rm $(systemPath)/$(programName)

translateDeploy:
	bash translate.sh

clean:
	./Build realclean

uninstall: serviceDisable unconfigure scriptsUnlink clean

