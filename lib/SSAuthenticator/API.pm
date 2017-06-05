# Copyright 2015 Vaara-kirjastot
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.


package SSAuthenticator::API;

use Modern::Perl;
use DateTime::Format::HTTP;
use DateTime;
use Digest::SHA;
use LWP::UserAgent;
use HTTP::Request;

use SSAuthenticator::Config;
use SSLog;

my $l = bless({}, 'SSLog');

sub _makeSignature {
    my ($method, $userid, $headerXKohaDate, $apiKey) = @_;

    my $message = join(' ', uc($method), $userid, $headerXKohaDate);
    my $digest = Digest::SHA::hmac_sha256_hex($message, $apiKey);

    return $digest;
}

=head2 _prepareAuthenticationHeaders
    @PARAM1 userid, the userid that we use to authenticate
    @PARAM2 DateTime, OPTIONAL, the timestamp of the HTTP request
    @PARAM3 HTTP verb, 'get', 'post', 'patch', 'put', ...
    @RETURNS HASHRef of authentication HTTP header names and their values. {
    "X-Koha-Date" => "Mon, 26 Mar 2007 19:37:58 +0000",
    "Authorization" => "Koha admin69:frJIUN8DYpKDtOLCwo//yllqDzg=",
}
=cut
sub _prepareAuthenticationHeaders {
    my ($userid, $dateTime, $method, $apiKey) = @_;

    my $headerXKohaDate = DateTime::Format::HTTP->format_datetime(
	($dateTime || DateTime->now)
	);
    my $headerAuthorization = "Koha ".$userid.":"._makeSignature($method, $userid, $headerXKohaDate, $apiKey);
    return {'X-Koha-Date' => $headerXKohaDate,
	    'Authorization' => $headerAuthorization};
}

sub getApiResponse {
    my ($cardNumber) = @_;

    my $conf = SSAuthenticator::Config::getConfig();
    my $requestUrl = $conf->param('ApiBaseUrl') . "/borrowers/ssstatus";

    my $ua = LWP::UserAgent->new;
    my $userId = $conf->param("ApiUserName");
    my $apiKey = $conf->param("ApiKey");
    my $authHeaders = _prepareAuthenticationHeaders($userId,
                            undef,
                            "GET",
                            $apiKey);

    my $date = $authHeaders->{'X-Koha-Date'};
    my $authorization = $authHeaders->{'Authorization'};

    my $request = HTTP::Request->new(GET => $requestUrl);
    $request->header('X-Koha-Date' => $date);
    $request->header('Authorization' => $authorization);
    $request->header('Content-Type' => 'application/x-www-form-urlencoded');
    $request->header('Content-Length' => length('cardnumber='.$cardNumber));
    $request->content('cardnumber='.$cardNumber);

    if ($l->is_trace) {
        $l->trace("Sending request: ".$request->as_string());
    }

    my $response = $ua->request($request);

    if ($l->is_debug) {
        $l->debug("Got response: ".$response->as_string());
    }

    return $response;
}

1;
