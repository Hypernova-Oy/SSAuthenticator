#
# Copyright (C) 2016 Koha-Suomi
# Copyright (C) 2023 Hypernova Oy
#
# This file is part of SSAuthenticator.
#

package t::Mocks;

use Modern::Perl;

use HTTP::Headers;
use HTTP::Response;
use JSON;
use Time::HiRes;

our $mock_httpTransactions_list = [];
our $mock_httpTransactions_list_i = -1;
sub _do_api_request_check_against_list {
    my ($ua, $request) = @_;
    my $expectedTransaction = $mock_httpTransactions_list->[$mock_httpTransactions_list_i++];
    die "_do_api_request_check_against_list():> No more prepared transactions!" unless $expectedTransaction;
    my $expecRequest = $expectedTransaction->{request};
    my $msg = $request->as_string;
    my @errors;
    while (my ($k, $v) = each %$expecRequest) {
        push(@errors, "Key='$k' is missing") unless $msg =~ /$k/gsm;
        push(@errors, "Val='$v' is missing") unless $msg =~ /$v/gsm;
    }
    if (@errors) {
        Test::More::is(join("\n", @errors), $msg, 'API Request validity check');
    }
    else {
        Test::More::ok(1, 'API Request validity check');
    }


    my $expecResponse = $expectedTransaction->{response};
    _mark_response_as_fired($expecResponse);
    return $expecResponse if (ref($expecResponse) eq 'HTTP::Response');
    if ($expecResponse->{_no_connection}) {
        return HTTP::Response->new(
            500,
            undef,
            HTTP::Headers->new('Client-Warning' => 'Internal response'),
            "Can't connect to 127.0.0.1:120 (Connection refused)",
        );
    }
    return HTTP::Response->new(
        $expecResponse->{httpCode},
        undef,
        HTTP::Headers->new(($expecResponse->{headers}) ? @{$expecResponse->{headers}} : ()),
        $expecResponse->{body} || '',
    );
}

sub _mark_response_as_fired {
    my ($expecResponse) = @_;
    if (ref($expecResponse)) {
        if ($expecResponse->{_fired}) {
            $expecResponse->{_fired}++;
        } else {
            $expecResponse->{_fired} = 1
        }
    }
}
sub _was_last_http_response_fired {
    return $mock_httpTransactions_list->[$mock_httpTransactions_list_i]->{response}->{_fired};
}

our $keyPad_read_inputs = [];
sub _keyPad_read_inputs {
    my ($keypad, $readBytes) = @_;
    return (0,0) if $readBytes == 256; #When the KeyPad serial buffer is flushed, 256 bytes is requested. Avoid consuming user input mocks.

    my $resp = shift(@$keyPad_read_inputs);
    Time::HiRes::sleep($resp->[1]/1000) if $resp->[1];
    return (1,$resp->[0]);
}

our ($doorOnTime, $doorOffTime);
sub doorOnTimed {
    $doorOnTime = Time::HiRes::time();
    return 1;
}

sub doorOffTimed {
    $doorOffTime = Time::HiRes::time();
    return 1;
}

sub api_response_card_library_closed {
    return {
        httpCode => 200,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            permission => 'false',
            error => 'Koha::Exception::SelfService::OpeningHours',
            startTime => '12:00',
            endTime => '23:00'
        }),
    };
}

sub api_response_feature_unavailable {
    return {
        httpCode => 501,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            error => 'Koha::Exception::SelfService::FeatureUnavailable',
        }),
    };
}

sub api_response_server_error {
    return {
        httpCode => 500,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            error => 'Something went wrong, check the logs.',
        }),
    };
}

sub api_response_card_not_found {
    return {
        httpCode => 404,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
             error => 'Koha::Exceptions::Patron',
        }),
    };
}

sub api_response_card_authz_ok {
    return {
        httpCode => 200,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            permission => 'True',
        }),
    };
}

sub api_response_card_authz_bad {
    return {
        httpCode => 200,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            permission => 'false',
            error => 'Koha::Exception::SelfService',
        }),
    };
}

sub api_response_card_bad_borrower_category {
    return {
        httpCode => 200,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            permission => 'false',
            error => 'Koha::Exception::SelfService::BlockedBorrowerCategory',
        }),
    };
}

sub api_response_pin_authn_ok {
    return {
        httpCode => 200,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            permission => 1,
        }),
    };
}

sub api_response_pin_authn_bad {
    return {
        httpCode => 200,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            permission => 0,
            error => "Wrong password.",
        }),
    };
}

1;

