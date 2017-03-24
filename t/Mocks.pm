#
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.
#

package t::Mocks;

use Modern::Perl;

use HTTP::Response;
use JSON;

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

1;

