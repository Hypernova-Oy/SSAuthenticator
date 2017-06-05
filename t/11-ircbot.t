#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

BEGIN {
    $ENV{SSA_LOG_LEVEL} = -4; #Logging verbosity adjustment 4 is fatal -4 is debug always
}

use Modern::Perl;

use Test::More;

use IRCBot;

use t::Examples;

#Create test context
#SSAuthenticator::changeLanguage('en_GB', 'UTF-8');
my $defaultConfTempFile = t::Examples::writeDefaultConf();
SSAuthenticator::Config::setConfigFile($defaultConfTempFile->filename());



subtest "Scenario: IRCBot sends a message to kivilahtio at our channel.", \&send_message;
sub send_message {
    my ($bot);

    eval {
    SKIP: {
      skip "Outbound port 6667 not open, 3",
      ok(! IRCBot::get(),
         "Global IRCBot not yet initialized");

      ok(IRCBot::alertChannels('I am IRCBot. A tiny dirty littler helper. If you can see me, it makes me happy. If you can hear me, I am glad. I hope I am not a burden. Thank you for loving me.'),
         "IRCBot yabbers");

      ok($bot = IRCBot::get(),
         "Global IRCBot auto initialized from config");
    }
    };
    ok(0, $@) if $@;
}



t::Examples::rmConfig();

done_testing();

