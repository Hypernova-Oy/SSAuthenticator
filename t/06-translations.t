#!/usr/bin/perl

# Copyright (C) 2021 Hypernova Oy
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of Authenticator.

use Test::More;
use Test::MockModule;

use t::Examples;

use SSAuthenticator;
use SSAuthenticator::Config;
use SSAuthenticator::I18n;
use SSAuthenticator::Transaction;

my $defaultConfTempFile = t::Examples::writeDefaultConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());


=head2 Trouble?

Try running
    bash -x translate.sh
to create the translations and update them after modifying the .po-files afterwards.

=cut


subtest "Translations fi_FI", \&translationsFi_FI;
sub translationsFi_FI {
    #Set the locale to fi_FI to test the expected Finnish language translations
    SSAuthenticator::I18n::changeLanguage('fi_FI', 'UTF-8');

    subtest "accessGranted fi_FI", sub {
        my $trans = SSAuthenticator::Transaction->new();
        $trans->auth(SSAuthenticator::OK);
        $trans->pinAuthn(SSAuthenticator::OK);
        $trans->cardAuthz(SSAuthenticator::OK);

        ok(SSAuthenticator::OLED::showAccessMsg($trans), "Show access message");
        is($trans->oledMessages()->[0]->[0], "showAccessMsg", "Correct type of OLED message generated");
        is($trans->oledMessages()->[0]->[1]->[0], "   Paasy sallittu   ", "Paasy sallittu, shown");
    };
    subtest "accessDenied fi_FI", sub {
        my $trans = SSAuthenticator::Transaction->new();
        $trans->auth(SSAuthenticator::ERR_SSTAC);
        $trans->pinAuthn(SSAuthenticator::ERR_SSTAC);
        $trans->cardAuthz(SSAuthenticator::ERR_SSTAC);

        ok(SSAuthenticator::OLED::showAccessMsg($trans), "Show access message");
        is($trans->oledMessages()->[0]->[0], "showAccessMsg", "Correct type of OLED message generated");
        is($trans->oledMessages()->[0]->[1]->[0], "Kayttoehtoja ei ole ", "access denied, shown");
        is($trans->oledMessages()->[0]->[1]->[1], "     hyvaksytty     ", "access denied2, shown");
    };
}

subtest "Translations en_GB", \&translationsEn_GB;
sub translationsEn_GB {
    #Set the locale to en_GB to test the expected Finnish language translations
    SSAuthenticator::I18n::changeLanguage('en_GB', 'UTF-8');

    subtest "accessGranted en_GB", sub {
        my $trans = SSAuthenticator::Transaction->new();
        $trans->auth(SSAuthenticator::OK);
        $trans->pinAuthn(SSAuthenticator::OK);
        $trans->cardAuthz(SSAuthenticator::OK);

        ok(SSAuthenticator::OLED::showAccessMsg($trans), "Show access message");
        is($trans->oledMessages()->[0]->[0], "showAccessMsg", "Correct type of OLED message generated");
        is($trans->oledMessages()->[0]->[1]->[0], "   Access granted   ", "Access granted, shown");
    };
    subtest "accessDenied en_GB", sub {
        my $trans = SSAuthenticator::Transaction->new();
        $trans->auth(SSAuthenticator::ERR_SSTAC);
        $trans->pinAuthn(SSAuthenticator::ERR_SSTAC);
        $trans->cardAuthz(SSAuthenticator::ERR_SSTAC);

        ok(SSAuthenticator::OLED::showAccessMsg($trans), "Show access message");
        is($trans->oledMessages()->[0]->[0], "showAccessMsg", "Correct type of OLED message generated");
        is($trans->oledMessages()->[0]->[1]->[0], " Terms & Conditions ", "access denied, shown");
        is($trans->oledMessages()->[0]->[1]->[1], "    not accepted    ", "access denied2, shown");
    };
}

t::Examples::rmConfig();

done_testing();
