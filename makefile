programName=ssauthenticator
confDir=etc/$(programName)
crontabDir=etc/cron.d
logDir=var/log/$(programName)
systemdServiceDir=etc/systemd/system
cacheDir=var/cache/$(programName)
udevDir=etc/udev/rules.d
systemUdevDir=/lib/$(udevDir)
systemPath=/usr/local/bin


debianPackages=perl gettext

debianPackagedPerlModules=libtest-simple-perl libtest-mockmodule-perl \
               libmodern-perl-perl libconfig-simple-perl libdbm-deep-perl \
               libwww-perl libjson-perl libsys-sigaction-perl libdatetime-perl \
               libdatetime-format-http-perl libdigest-sha-perl libsystemd-dev \
               liblog-log4perl-perl liblocale-gettext-perl libjson-xs-perl \
               libbot-basicbot-perl libcarp-always-perl libdata-printer-perl


#Macro to check the exit code of a make expression and possibly not fail on warnings
RC      := test $$? -lt 100


build: compile
	sudo apt-get install -y $(debianPackages)
	sudo apt-get install -y $(debianPackagedPerlModules)

restart: serviceEnable

install: build configure perlDeploy scriptsLink translateInstall serviceEnable

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
	cp --backup=numbered $(confDir)/log4perl.conf /$(confDir)/
	cp --backup=numbered $(confDir)/daemon.conf /$(confDir)/
	cp $(systemdServiceDir)/$(programName).service /$(systemdServiceDir)/$(programName).service
	cp $(crontabDir)/sssync /$(crontabDir)/sssync

	mkdir -p /$(cacheDir)
	touch /$(cacheDir)/patron.db

	mkdir -p /$(logDir)

	cp $(udevDir)/99-$(programName).rules /$(udevDir)/

	cp boot/config.txt /boot/config.txt

unconfigure:
	rm -r /$(confDir) || $(RC)
	rm -r /$(cacheDir)
	rm /$(udevDir)/99-$(programName).rules
	rm /$(crontabDir)/sssync

serviceEnable:
	# Stop serial getty from listening for serial connections on the Raspberry serial console
	systemctl stop serial-getty@AMA0
	systemctl mask serial-getty@AMA0
	systemctl daemon-reload
	systemctl enable $(programName)
	systemctl restart $(programName)

serviceDisable:
	systemctl stop $(programName)
	rm /$(systemdServiceDir)/$(programName).service
	systemctl daemon-reload

scriptsLink:
	cp scripts/$(programName) $(systemPath)/

scriptsUnlink:
	rm $(systemPath)/$(programName)

translateInstall:
	bash translate.sh install

clean:
	./Build realclean

uninstall: serviceDisable unconfigure scriptsUnlink clean

