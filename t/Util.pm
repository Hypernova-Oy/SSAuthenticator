package t::Util;

use Modern::Perl;

use Data::Dumper;
use Exporter;
use Storable;
use Test::More;

use SSAuthenticator;
use SSAuthenticator::Transaction;

use t::Mocks;


our @ISA = qw(Exporter);
our @EXPORT = qw(scenario);

sub _defaultHTTPTransactions {
    return [
        {   request => {
                cardnumber => '167A006007',
            },
            response => t::Mocks::api_response_card_authz_ok(),
        },
        {   request => {
                password => '1234',
            },
            response => t::Mocks::api_response_pin_authn_ok(),
        },
    ];
}

sub scenario {
    my $scen = shift;
    $t::Mocks::mock_httpTransactions_list = $scen->{httpTransactions} || _defaultHTTPTransactions();
    $t::Mocks::keyPad_read_inputs = Storable::dclone($scen->{pinCharInput});

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
        is($trans->pinCode, $scen->{assert_pinCode},
           "PIN code ".($scen->{assert_pinCode} || 0)) if exists $scen->{assert_pinCode};

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

        if ($scen->{pinCharInput}) {
            subtest $scen->{name}.' - PIN input', sub {
                my @errors;
                for (my $i=0 ; $i<@{$scen->{pinCharInput}} ; $i++) {
                    my $pinCharInput = $scen->{pinCharInput}->[$i];
                    my $pinKeyEvent = $trans->pinKeyEvents()->[$i];

                    next if $pinCharInput->[2] eq 'KEYPAD_INACTIVE';
                    is($pinKeyEvent->[0], $pinCharInput->[0], "PIN input '$i' key is as expected"); #keys match
                    is($pinKeyEvent->[1], $pinCharInput->[2], "PIN input '$i' key state is as expected");
                }
            }
        }

        $scen->{postTests}->() if ($scen->{postTests});
    }
}