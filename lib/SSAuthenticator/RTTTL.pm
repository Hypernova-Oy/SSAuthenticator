# Copyright (C) 2020 Hypernova Oy
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator::RTTTL;

use Sys::SigAction;

use SSAuthenticator::Pragmas;
my $l = bless({}, 'SSLog');

sub playAccessBuzz {
    playRTTTL('ToveriAccessGranted');
}
sub playDenyAccessBuzz {
    playRTTTL('ToveriAccessDenied');
}
sub playZelda {
    my $pid = fork();
    if ($pid == 0) {
        playRTTTL('Zelda1');
        exit;
    }
    else {
        return;
    }
}

=head2 playRTTTL

Plays the given song.

 @param1 {String} Name of the song in the rtttl-player library to play

=cut

sub playRTTTL {
    my ($song, $timeout) = @_;
    system("rtttl-player -o song-$song &"); # Due to fork causing havok with GPIO and & making it impossible to trace what actually happens to the rtttl-player, we can just hope everything worked ok.
}

1;
