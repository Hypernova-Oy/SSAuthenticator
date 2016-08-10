# Copyright 2015 Vaara-kirjastot
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of Authenticator.
#
# Authenticator is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package API;

use Modern::Perl;
use DateTime::Format::HTTP;
use DateTime;
use Digest::SHA;

sub makeSignature {
    my ($method, $userid, $headerXKohaDate, $apiKey) = @_;

    my $message = join(' ', uc($method), $userid, $headerXKohaDate);
    my $digest = Digest::SHA::hmac_sha256_hex($message, $apiKey);

    return $digest;
}

=head prepareAuthenticationHeaders
    @PARAM1 userid, the userid that we use to authenticate
    @PARAM2 DateTime, OPTIONAL, the timestamp of the HTTP request
    @PARAM3 HTTP verb, 'get', 'post', 'patch', 'put', ...
    @RETURNS HASHRef of authentication HTTP header names and their values. {
    "X-Koha-Date" => "Mon, 26 Mar 2007 19:37:58 +0000",
    "Authorization" => "Koha admin69:frJIUN8DYpKDtOLCwo//yllqDzg=",
}
=cut
sub prepareAuthenticationHeaders {
    my ($userid, $dateTime, $method, $apiKey) = @_;

    my $headerXKohaDate = DateTime::Format::HTTP->format_datetime(
	($dateTime || DateTime->now)
	);
    my $headerAuthorization = "Koha ".$userid.":".makeSignature($method, $userid, $headerXKohaDate, $apiKey);
    return {'X-Koha-Date' => $headerXKohaDate,
	    'Authorization' => $headerAuthorization};
}

1;
