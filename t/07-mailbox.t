#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

BEGIN {
    $ENV{SSA_LOG_LEVEL} = -4; #Logging verbosity adjustment 4 is fatal -4 is debug always
    $ENV{SSA_TEST_MODE} = 1;
}

use Modern::Perl;

use Test::More;
use Test::MockModule;

use t::Examples;
use t::Mocks;
use t::Mocks::HTTPResponses;
use t::Mocks::OpeningHours;
use SSAuthenticator::Mailbox;
use SSAuthenticator::Config;
use SSAuthenticator;


=head2 07-mailbox.t

Testing the mailbox functionality

=cut

#Create test context
#SSAuthenticator::changeLanguage('en_GB', 'UTF-8');
t::Examples::createCacheDB();
my $defaultConfTempFile = t::Examples::writeDefaultConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());

##Mock subroutines
my $ssAuthenticatorApiMockModule = Test::MockModule->new('SSAuthenticator::API');
$ssAuthenticatorApiMockModule->mock('_do_api_request', \&t::Mocks::_do_api_request_check_against_list);
my $ssAuthenticatorMockModule = Test::MockModule->new('SSAuthenticator');
$ssAuthenticatorMockModule->mock('controlAccess', \&controlAccess_counter);
my $controlAccess_invokedCount = 0;




subtest "Scenario: Process a SSAuthenticator::controlAccess() request from the mailbox.", \&ssauth_controlAccess;
sub ssauth_controlAccess {
    my ($module, $moduleApi, $config);

    eval {
    $config = SSAuthenticator::Config::getConfig();
    my $ohs = t::Mocks::OpeningHours::createAlwaysOpen();
    ok(SSAuthenticator::OpeningHours::_persistOpeningHoursToDB($ohs), "Given the OpeningHours: Always open");

    $t::Mocks::mock_httpTransactions_list = [{
        request => {
            cardnumber => '167A0123123',
        },
        response => HTTP::Response->parse(t::Mocks::HTTPResponses::SSStatus401Unauthenticated()),
    }];

    ok(SSAuthenticator::Mailbox::sendMessage(
           'controlAccess',
           '167A0123123'),
       'Given a controlAccess-file in the mailbox containing a barcode');

    ok(SSAuthenticator::Mailbox::checkMailbox(),
       'When SSAuthenticator checks the mailbox');

    is($controlAccess_invokedCount, 1,
       'Then we have accessed SSAuthenticator::controlAccess()');
    is(t::Mocks::_was_last_http_response_fired(), 1,
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

