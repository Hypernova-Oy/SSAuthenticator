#
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package t::Mocks;

use Modern::Perl;

use HTTP::Headers;
use HTTP::Response;
use JSON;
use Time::HiRes;

=head getApiResponse_mockResponse

    $t::Mocks::$getApiResponse_mockResponse = {
        httpCode   => 200,  #HTTP status code of the HTTP::Response
        error      => 'Koha::Exception::SelfService::OpeningHours', #JSON-body key
        permission => 'false', #JSON-body key
        startTime  => '09:00', #JSON-body key
        endTime    => '21:00', #JSON-body key
        timeout    => 1|0,  #Should the request sleep until it times out?
        _triggered => 0|1|2|3++ #How many times getApiResponse() has been called? Do not manually set this!!
    };

=cut

#'our' makes sure this variable can be directly accessed from other packages
our $getApiResponse_mockResponse;

=head2 getApiResponse

    $t::Mocks::$getApiResponse_mockResponse = {
        httpCode   => 501,
        error      => 'Koha::Exception::FeatureUnavailable',
    };
    $ssAuthenticatorApiMockModule = Test::MockModule->new('SSAuthenticator::API');
    $ssAuthenticatorApiMockModule->mock('getApiResponse', \&t::Mocks::getApiResponse);

Mocks SSAuthenticator::API::getApiResponse() to return a predetermined response based on
the \$getApiResponse_mockResponse-variable

=cut

sub getApiResponse {
    my ($cardNumber) = @_;

    warn __PACKAGE__.'::getApiResponse():> \$getApiResponse_mockResponse is not defined. You must define it to tell what kind of response should be returned.' unless (ref($getApiResponse_mockResponse) eq 'HASH');
    my $garmr = $getApiResponse_mockResponse;

    #Keep track of how many times this mock has been called.
    $garmr->{_triggered} = ($garmr->{_triggered}) ? $garmr->{_triggered}+1 : 1;
 
    my $jsonBody = {};
    $jsonBody->{error}      = $garmr->{error}      if $garmr->{error};
    $jsonBody->{permission} = $garmr->{permission} if $garmr->{permission};
    $jsonBody->{startTime}  = $garmr->{startTime}  if $garmr->{startTime};
    $jsonBody->{endTime}    = $garmr->{endTime}    if $garmr->{endTime};
    $jsonBody = JSON::encode_json($jsonBody);

    my $response = HTTP::Response->new(
        $garmr->{httpCode},
        undef,
        undef,    
        $jsonBody,
    );

    sleep SSAuthenticator::getTimeout() if $garmr->{timeout};
    return $response;
}

our $mock_httpTransactions_list = [];
sub _do_api_request_check_against_list {
    my ($ua, $request) = @_;
    my $expectedTransaction = shift @$mock_httpTransactions_list;
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

our $keyPad_read_inputs = [];
sub _keyPad_read_inputs {
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
            error => 'Koha::Plugin::Fi::KohaSuomi::SelfService::Exception::OpeningHours',
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
            error => 'Koha::Plugin::Fi::KohaSuomi::SelfService::Exception::FeatureUnavailable',
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
            error => 'Koha::Plugin::Fi::KohaSuomi::SelfService::Exception',
        }),
    };
}

sub api_response_card_bad_borrower_category {
    return {
        httpCode => 200,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            permission => 'false',
            error => 'Koha::Plugin::Fi::KohaSuomi::SelfService::Exception::BlockedBorrowerCategory',
        }),
    };
}

sub api_response_pin_authn_ok {
    return {
        httpCode => 200,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            sessionid => 'SESSIONID1234',
            permissions => {},
            borrowernumber => 10,
        }),
    };
}

sub api_response_pin_authn_bad {
    return {
        httpCode => 401,
        headers  => ['Content-Type' => 'application/json;charset=UTF-8'],
        body     => JSON::encode_json({
            error => "Login failed.",
        }),
    };
}

1;

