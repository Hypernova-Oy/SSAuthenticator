package t::Util;

use Modern::Perl;

use Data::Dumper;
use Exporter;
use Test::More;

use SSAuthenticator;
use SSAuthenticator::Transaction;

use t::Mocks;


our @ISA = qw(Exporter);
our @EXPORT = qw(scenario);

sub scenario {
    my $scen = shift;
    $t::Mocks::mock_httpTransactions_list = $scen->{httpTransactions};
    $t::Mocks::keyPad_read_inputs = $scen->{pinCharInput};
    # When the keypad begins a new transaction, it flushes the input buffer. This removes the first element from the mocked pin-entry list. Adjust to input buffer flushing here.
    unshift(@$t::Mocks::keyPad_read_inputs, [0,0,0]) if ($t::Mocks::keyPad_read_inputs);

    subtest $scen->{name}, sub {
        my $trans = SSAuthenticator::Transaction->new();
        SSAuthenticator::controlAccess($scen->{cardnumber} // '167A006007', $trans);

        is($trans->auth, $scen->{assert_authStatus},
           "Auth status ".($scen->{assert_authStatus} || 0)) if exists $scen->{assert_authStatus};
        is($trans->cardAuthz, $scen->{assert_cardAuthStatus},
           "Card Auth status ".($scen->{assert_cardAuthStatus} || 0)) if exists $scen->{assert_cardAuthStatus};
        is($trans->cardCached, $scen->{assert_cardCached},
           "Card cached ".($scen->{assert_cardCached} || 0)) if exists $scen->{assert_cardCached};
        is($trans->cardCacheFlushed, $scen->{assert_cardCacheFlushed},
           "Card cache flushed ".($scen->{assert_cardCacheFlushed} || 0)) if exists $scen->{assert_cardCacheFlushed};
        is($trans->cardAuthzCacheUsed, $scen->{assert_cardCacheUsed},
           "Card cache used ".($scen->{assert_cardCacheUsed} || 0)) if exists $scen->{assert_cardCacheUsed};
        is($trans->pinAuthn, $scen->{assert_pinAuthStatus},
           "PIN Auth status ".($scen->{assert_pinAuthStatus} || 0)) if exists $scen->{assert_pinAuthStatus};
        is($trans->pinCached, $scen->{assert_pinAuthCached},
           "PIN cached ".($scen->{assert_pinAuthCached} || 0)) if exists $scen->{assert_pinAuthCached};
        is($trans->pinCacheFlushed, $scen->{assert_pinCacheFlushed},
           "PIN cache flushed ".($scen->{assert_pinCacheFlushed} || 0)) if exists $scen->{assert_pinCacheFlushed};
        is($trans->pinAuthnCacheUsed, $scen->{assert_pinAuthCacheUsed},
           "PIN cache used ".($scen->{assert_pinAuthCacheUsed} || 0)) if exists $scen->{assert_pinAuthCacheUsed};

        if ($scen->{assert_oledMsgs}) {
            subtest $scen->{name}.' - OLED Messages', sub {
                my @actualOledMsgs = map {
                    $_->[1] = join("\n", @{$_->[1]});
                    $_;
                } @{$trans->oledMessages()};
                my @errors;
                for my $check (@{$scen->{assert_oledMsgs}}) {
                    my $re = $check->[1];
                    my $found = 0;
                    for my $oledm (@actualOledMsgs) {
                        $found = 1 if ($check->[0] eq $oledm->[0]) && ($oledm->[1] =~ /$re/sm);
                    }
                    if ($found) {
                        ok(1, 'OLED msg matches '.$check->[0].' - '.$check->[1]);
                    }
                    else {
                        push(@errors, $check->[0].' - '.$check->[1]);
                        ok(0, 'OLED msg matches '.$check->[0].' - '.$check->[1]);
                    }
                }
                if (@errors) {
                    is(Data::Dumper::Dumper(@actualOledMsgs), Data::Dumper::Dumper($scen->{assert_oledMsgs}), 'OLED msgs match');
                }
                else {
                    ok(1, 'OLED msgs match');
                }
            }
        }

        $scen->{postTests}->() if ($scen->{postTests});
    }
}