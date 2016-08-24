#!/usr/bin/perl
# Copyright (C) 2016 Koha-Suomi
#
# This file is part of Authenticator.
#
# Authenticator is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Authenticator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Authenticator.  If not, see <http://www.gnu.org/licenses/>.

package Buzzer;

use Modern::Perl;

use GPIO;

use constant {
    BUZZ_FREQUENCY => 3050
};

sub new {
    my ($class, $BUZZER_GPIO_PORT) = @_;
    my $self = {};

    $self->{buzzerPort} = $BUZZER_GPIO_PORT;

    return bless $self, $class;
}

sub buzz {
    my ($self, $herz, $playTime) = @_;

    my $buzzer = GPIO->new($self->{buzzerPort});
    my $waveLength = 1 / $herz;

    # The constant in period calculation is for taking account processing time
    my $periods = int ( $herz * $playTime * 0.6 );
    my $halfWave = $waveLength / 2;
    
    for (my $i = 0; $i <= $periods; $i++) {
	$buzzer->turnOn();
	Time::HiRes::sleep($halfWave);
	$buzzer->turnOff();
	Time::HiRes::sleep($halfWave);
    }

}

sub beepWithPauses {
    my ($self, $beepCount, $pauseInSec, $beebLengthInSec) = @_;

    while ($beepCount >= 1) {
	$self->buzz(BUZZ_FREQUENCY, $beebLengthInSec);
	Time::HiRes::sleep($pauseInSec);
	$beepCount--;
    }
}

1;
