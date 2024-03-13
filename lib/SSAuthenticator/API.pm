# Copyright 2015 Vaara-kirjastot
# Copyright (C) 2016 Koha-Suomi
# Copyright 2021 Hypernova Oy
#
# This file is part of SSAuthenticator.


package SSAuthenticator::API;

use Modern::Perl;
use DateTime::Format::HTTP;
use DateTime;
use Digest::SHA;
use LWP::UserAgent;
use HTTP::Headers;
use HTTP::Request;
use JSON::XS;
use Scalar::Util qw(blessed);

use SSAuthenticator::Config;
use SSAuthenticator::Pragmas;

my $l = bless({}, 'SSLog');
my $lScraper = bless({category => 'scraper'}, 'SSLog');

my $jsonParser = JSON::XS->new();

sub _getAPIClient {
    my $ua = LWP::UserAgent->new;
    $ua->timeout(  SSAuthenticator::Config::getTimeoutInSeconds()  );
    return $ua;
}

sub _makeSignature {
    my ($method, $userid, $headerXKohaDate, $apiKey) = @_;

    my $message = join(' ', uc($method), $userid, $headerXKohaDate);
    my $digest = Digest::SHA::hmac_sha256_hex($message, $apiKey);

    return $digest;
}

=head2 _prepareAuthenticationHeaders

    @PARAM1 DateTime, OPTIONAL, the timestamp of the HTTP request
    @PARAM2 HTTP verb, 'get', 'post', 'patch', 'put', ...
    @RETURNS HASHRef of authentication HTTP header names and their values. {
    "X-Koha-Date" => "Mon, 26 Mar 2007 19:37:58 +0000",
    "Authorization" => "Koha admin69:frJIUN8DYpKDtOLCwo//yllqDzg=",
}

=cut

sub _prepareAuthenticationHeaders {
    my ($dateTime, $method) = @_;

    my $conf = SSAuthenticator::Config::getConfig();
    return _prepareBasicAuth() if $conf->param("ApiPassword");
    return _prepareApiKeyAuth($dateTime, $method) if $conf->param("ApiKey");
}

sub _prepareBasicAuth {
    my $conf = SSAuthenticator::Config::getConfig();
    return [
        'Authorization', 'Basic '.MIME::Base64::encode($conf->param("ApiUserName").':'.$conf->param("ApiPassword"), '')
    ];
}

sub _prepareApiKeyAuth {
    my ($dateTime, $method) = @_;

    my $conf = SSAuthenticator::Config::getConfig();
    my $userId = $conf->param("ApiUserName");
    my $apiKey = $conf->param("ApiKey");
    my $headerXKohaDate = DateTime::Format::HTTP->format_datetime(
        ($dateTime || DateTime->now)
    );
    return [
        'X-Koha-Date'   => $headerXKohaDate,
        'Authorization' => "Koha ".$userId.":"._makeSignature($method, $userId, $headerXKohaDate, $apiKey),
    ];
}

=head2 getApiResponse

@RETURNS HTTP::Response
@THROWS SSAuthenticator::Exception::HTTPTimeout if configuration ConnectionTimeout is exceeded

=cut

sub getApiResponse {
    my ($cardNumber) = @_;

    my $conf = SSAuthenticator::Config::getConfig();
    my $requestUrl = $conf->param('ApiBaseUrl') . "/borrowers/ssstatus";

    my $ua = _getAPIClient();

    my $body = "cardnumber=$cardNumber";
    $body   .= "&branchcode=".$conf->param('LibraryName') if $conf->param('LibraryName');

    my $headers = HTTP::Headers->new(
        @{_prepareAuthenticationHeaders(undef, "GET")},
        'Content-Type' => 'application/x-www-form-urlencoded',
        'Content-Length' => length($body),
    );

    my $request = HTTP::Request->new(GET => $requestUrl, $headers, $body);

    $lScraper->info($request->as_string);
    my $res = _do_api_request($ua => $request);
    $lScraper->info($res->as_string);

    unless ($res) {
        die "getApiResponse() didn't get a proper Response object?";
    }

    if ($res->header('Client-Warning') && $res->header('Client-Warning') eq 'Internal response') { #Internal LWP::UserAgent error
        return _handleInternalLWPClientError($res);
    }

    my $body2 = _decodeContent($res);
    my $err = $body2->{error} || '';
    my $permission = $body2->{permission} || 0;
    return ($res, $body2, $err, $permission, $res->code);
}

sub _handleResponse {
    my ($res) = @_;
    unless ($res) {
        die "getApiResponse() didn't get a proper Response object?";
    }

    if (my $clientWarning = $res->header('Client-Warning')) { #Internal LWP::UserAgent error
        return _handleInternalLWPClientError($res);
    }
    return _handleAPIResponse($res);
    #return ($response, $body, $err, $permission, $status); # Signature
}

=head2 _handleInternalLWPClientError

LWP::UserAgent might get timeouted by Sys::SigAction::timeout_call() and this causes a cryptic
    500 HASH(0x78a078)
    Content-Type: text/plain
    Client-Date: Thu, 10 Aug 2017 07:47:07 GMT
    Client-Warning: Internal response

    HASH(0x78a078)

response, which cannot be parsed properly using HTTP::Response->as_string()

Work around this limitation here, and try to parse the special internal responses to something loggable.


Alternatively one can just set the timeout to the LWP::UserAgent :(

Regardless LWP::UserAgent for some reason doesnt throw anything so the no connection and timeout situations need to be handled differently.
such issues are flagged with HTTP 500 and Header Client-Warning.
Remodel this to HTTP 510

=cut

sub _handleInternalLWPClientError {
    my ($res) = @_;

    if ($res->code != 500) {
        $l->error("Strange LWP::UserAgent Client-Warning HTTP Status code '".$res->code."'. Should be 500?");
    }
    $res->code(510);
    if (not($res->content)) {
        $l->error("Strange LWP::UserAgent Client-Warning HTTP content missing?");
    }

    return ($res, $res->decoded_content, $res->decoded_content, 0, $res->code);
}

sub _do_api_request { # Used to mock LWP::UserAgent without mocking it.
    my ($ua, $request) = @_;
    return $ua->request($request);
}

=head2 _decodeContent

Extracts the body parameters from the given HTTP::Response-object

@RETURNS HASHRef of body parameters decoded or an empty HASHRef is errors happened.
@DIE     if HTTP::Response content is not valid JSON or if content doesn't exist

=cut

sub _decodeContent {
    my ($res) = @_;

    my $responseContent = $res->decoded_content;
    unless ($responseContent) {
        return {};
    }

    my $body;
    if ($res->header('Content-Type') =~ /json/i) {
        eval {
            $body = $jsonParser->decode($responseContent);
        };
        if ($@) {
            $l->error("Cannot decode HTTP::Response:\n".$res->as_string()."\nCONTENT: ".Data::Dumper::Dumper($responseContent)."\nJSON::decode_json ERROR: ".Data::Dumper::Dumper($@)) if $l->is_error();

            if (ref($responseContent) eq 'HASH') {
                $body = $responseContent;
                $l->error("Looks like \$responseContent is already a HASHRef. Trying to make it work.");
            }
            else {
                $body = {error => $@};
            }
        }
    }

    return $body;
}

sub getPINResponse {
    my ($cardnumber, $pin) = @_;

    my $conf = SSAuthenticator::Config::getConfig();
    my $requestUrl = $conf->param('ApiBaseUrl') . "/selfservice/pincheck";

    my $ua = _getAPIClient();

    my $body = "{\"cardnumber\": \"$cardnumber\", \"password\": \"$pin\"}";

    my $headers = HTTP::Headers->new(
        @{_prepareAuthenticationHeaders(undef, "GET")},
    );

    my $request = HTTP::Request->new(GET => $requestUrl, $headers, $body);

    $lScraper->info($request->as_string);
    my $res = _do_api_request($ua => $request);
    $lScraper->info($res->as_string);

    unless ($res) {
        die "getApiResponse() didn't get a proper Response object?";
    }

    if ($res->header('Client-Warning') && $res->header('Client-Warning') eq 'Internal response') { #Internal LWP::UserAgent error
        return _handleInternalLWPClientError($res);
    }

    my $body2 = _decodeContent($res);
    my $err = $body2->{error} || '';
    my $permission = ($body2->{permission}) ? 1 : 0;
    return ($res, $body2, $err, $permission, $res->code);
}

my $isMalfunctioning = 0;
sub isMalfunctioning {
    $isMalfunctioning = $_[0] if (defined($_[0]));
    return $isMalfunctioning;
}

sub getOpeningHours {
    my $conf = SSAuthenticator::Config::getConfig();

    my $requestUrl = $conf->param('ApiBaseUrl') . "/selfservice/openinghours/self";
    my $headers = HTTP::Headers->new(
        @{_prepareAuthenticationHeaders(undef, "GET")},
    );
    my $ua = _getAPIClient();

    my $request = HTTP::Request->new(GET => $requestUrl, $headers);
    $lScraper->debug($request->as_string);
    my $res = _do_api_request($ua => $request);
    $lScraper->debug($res->as_string);

    unless ($res) {
        die "getOpeningHours() didn't get a proper Response object?";
    }

    if ($res->header('Client-Warning') && $res->header('Client-Warning') eq 'Internal response') { #Internal LWP::UserAgent error
        return _handleInternalLWPClientError($res);
    }

    my $body = _decodeContent($res);
    my $err = (ref($body) eq 'HASH') ? $body->{error} : '';
    return ($res, $body, $err, $res->code);
}

1;
