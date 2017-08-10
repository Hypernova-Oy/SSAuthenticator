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


use SSAuthenticator::Exception::HTTPTimeout;


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

=head2 getApiResponse

@RETURNS HTTP::Response
@THROWS SSAuthenticator::Exception::HTTPTimeout if configuration ConnectionTimeout is exceeded

=cut

sub getApiResponse {
    my ($cardNumber) = @_;

    my $conf = SSAuthenticator::Config::getConfig();
    my $requestUrl = $conf->param('ApiBaseUrl') . "/borrowers/ssstatus";

    my $ua = LWP::UserAgent->new;
    $ua->timeout(  SSAuthenticator::Config::getTimeoutInSeconds()  );
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

    unless ($response) {
        die "getApiResponse($cardNumber) didn't get a proper Response object?";
    }

    if (my $clientWarning = $response->header('Client-Warning')) { #Internal LWP::UserAgent error
        $l->debug("Receiving the response failed with HTTP Client error: "._parseClientErrorToString($response));
    }
    elsif ($l->is_debug) {
        $l->debug("Got response: ".$response->as_string());
    }

    return $response;
}

=head2 _parseClientErrorToString

LWP::UserAgent might get timeouted by Sys::SigAction::timeout_call() and this causes a cryptic
    500 HASH(0x78a078)
    Content-Type: text/plain
    Client-Date: Thu, 10 Aug 2017 07:47:07 GMT
    Client-Warning: Internal response

    HASH(0x78a078)

response, which cannot be parsed properly using HTTP::Response->as_string()

Work around this limitation here, and try to parse the special internal responses to something loggable.


Alternatively one can just set the timeout to the LWP::UserAgent :(


=cut

sub _parseClientErrorToString {
    my ($res) = @_;

    my $code = $res->code() || '<Status code undef>' ;
    my $message = $res->message() || '<Message undef>';
    if (ref($message)) { #This can bug out and be a HASH
        $message = $l->flatten($message);
    }
    my $headersStr = $res->headers_as_string() || '<Headers undef>';
    my $content = $res->content() || '<Content undef>';
    if ($content =~ /^HASH/) { #content is royally mangĺed
        $content = $res->{_content}; #Dangerously directly access a private variable!
    }
    my $as_string = "$code $message\n$headersStr\n$content";

    if ($message eq 'read timeout') {
        #LWP::UserAgent probably killed by Sys::SigAction::timeout_call()
        SSAuthenticator::Exception::HTTPTimeout->throw(error => "HTTP Request timed out");
    }
    if ($message eq '[{}]') {
        #LWP::UserAgent probably killed by Sys::SigAction::timeout_call()
        SSAuthenticator::Exception::HTTPTimeout->throw(error => "HTTP Request probably timeoutted");
    }

    return $as_string;
}

1;
