# Copyright (C) 2022 Hypernova Oy
#
# This file is part of SSAuthenticator.
#

package t::Mocks::OpeningHours;

sub createAlwaysClosed {
    return [
        [_fromNow('01:00'), _fromNow('-01:00')],
        [_fromNow('01:00'), _fromNow('-01:00')],
        [_fromNow('01:00'), _fromNow('-01:00')],
        [_fromNow('01:00'), _fromNow('-01:00')],
        [_fromNow('01:00'), _fromNow('-01:00')],
        [_fromNow('01:00'), _fromNow('-01:00')],
        [_fromNow('01:00'), _fromNow('-01:00')],
    ];
}

sub createAlwaysOpen {
    return [
        [_fromNow('-01:00'), _fromNow('01:00')],
        [_fromNow('-01:00'), _fromNow('01:00')],
        [_fromNow('-01:00'), _fromNow('01:00')],
        [_fromNow('-01:00'), _fromNow('01:00')],
        [_fromNow('-01:00'), _fromNow('01:00')],
        [_fromNow('-01:00'), _fromNow('01:00')],
        [_fromNow('-01:00'), _fromNow('01:00')],
    ];
}

sub _fromNow {
    my ($adjust) = @_;
    my ($h, $m) = split(":", $adjust);
    my $dt = DateTime->now();
    $dt->add(hours => $h)->add(minutes => $m);
    return $dt->hour.':'.$dt->minute;
}

return 1;
