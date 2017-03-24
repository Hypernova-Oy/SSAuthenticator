#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

use Modern::Perl;

use Test::More;
use Test::MockModule;

use t::Examples;
use t::Mocks;
use SSAuthenticator::Mailbox;
use SSAuthenticator::Config;
use SSAuthenticator;

SSAuthenticator::openLogger(-1); #Show only fatal errors. If you have problems with these tests. Give parameter 2 for debug logging.

=head2 07-mailbox.t

Testing the mailbox functionality

=cut

#Create test context
#SSAuthenticator::changeLanguage('en_GB', 'UTF-8');
t::Examples::createCacheDB();
my $defaultConfTempFile = t::Examples::writeDefaultConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

##Mock subroutines
$t::Mocks::getApiResponse_mockResponse = {
    httpCode   => 200,
    error      => 'Koha::Exception::SelfService::OpeningHours',
    permission => 'false',
    startTime  => '09:00',
    endTime    => '21:00',
};
my $ssAuthenticatorApiMockModule = Test::MockModule->new('SSAuthenticator::API');
$ssAuthenticatorApiMockModule->mock('getApiResponse', \&t::Mocks::getApiResponse);
my $ssAuthenticatorMockModule = Test::MockModule->new('SSAuthenticator');
$ssAuthenticatorMockModule->mock('controlAccess', \&controlAccess_counter);
my $controlAccess_invokedCount = 0;




subtest "Scenario: Process a SSAuthenticator::controlAccess() request from the mailbox.", \&ssauth_controlAccess;
sub ssauth_controlAccess {
    my ($module, $moduleApi, $config);

    eval {
    $config = SSAuthenticator::Config::getConfig();

    ok(SSAuthenticator::Mailbox::sendMessage(
           'controlAccess',
           '167A0123123'),
       'Given a controlAccess-file in the mailbox containing a barcode');

    ok(SSAuthenticator::Mailbox::checkMailbox(),
       'When SSAuthenticator checks the mailbox');

    is($controlAccess_invokedCount, 1,
       'Then we have accessed SSAuthenticator::controlAccess()');
    is($t::Mocks::getApiResponse_mockResponse->{_triggered}, 1,
       'Then we have accessed SSAuthenticator::API::getApiResponse()');

    };
    ok(0, $@) if $@;
}



t::Examples::rmConfig();
t::Examples::rmCacheDB();

done_testing();


sub controlAccess_counter {
    $controlAccess_invokedCount++;
    my $subroutine = $ssAuthenticatorMockModule->original('controlAccess');
    return &$subroutine(@_);
}

