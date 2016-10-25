#!/usr/bin/perl

# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

use Test::More tests => 2;
use SSAuthenticator::API;

subtest "Make signature", \&testSignatureMaking;
sub testSignatureMaking {
    my $method = "get";
    my $userid = "testId";
    my $headerXKohaDate = DateTime->new(
	year       => 2015,
	month      => 4,
	day        => 15,
	hour       => 4,
	minute     => 20,
	second     => 13,
	);
    my $apiKey = "F12312mp3K123kljkar";
    is(SSAuthenticator::API::_makeSignature($method, $userid, $headerXKohaDate, $apiKey),
       "f74a83dad4233747b29ec575482f8e8921dcfc0b4e0891c5792d4a78078ccf8d",
       "signature making");
}


    
subtest "Make authentication headers", \&testprepareAuthenticationHeaders;
sub testprepareAuthenticationHeaders {
    my $method = "get";
    my $userid = "testId";
    my $headerXKohaDate = DateTime->new(
	year       => 2015,
	month      => 4,
	day        => 15,
	hour       => 4,
	minute     => 20,
	second     => 13,
	);
    my $apiKey = "F12312mp3K123kljkar";
    my $authHeaders = SSAuthenticator::API::_prepareAuthenticationHeaders($userid,
							$headerXKohaDate,
							$method,
							$apiKey);
    
    is($$authHeaders{'X-Koha-Date'},
       DateTime::Format::HTTP->format_datetime($headerXKohaDate),
    "date returned correctly");

    is($$authHeaders{'Authorization'},
       "Koha " . $userid . ":" . "d8d2002376cf7ba80d3c694a348f3fa0d91a592c502a70227c7aa90f7c558ad4",
       "Authorization header looks correct");



}
