# Copyright (C) 2016 Koha-Suomi
#
# This file is part of SSAuthenticator.


package SSAuthenticator::Greetings;

use Modern::Perl;

use Locale::TextDomain qw (SSAuthenticator); #Look from cwd or system defaults. This is needed for tests to pass during build


=head1 SSAuthenticator::Greetings

Nice friendly random greetings generator.

=cut


my @greetings = (
    N__"   Welcome again!   ",
    N__"Thanks for visiting.",
    N__"   See you soon!    ",
    N__" I aim to please ;) ",
    N__"I hope you like us! ",
    N__" Enjoy our library. ",
    N__"     Have fun!   :) ",
    N__"     Take care!     ",
    N__" You are the best!  ",
    N__"I like you already. ",
    N__"Our place is great. ",
    N__"Please remember me! ",
    N__"<3 <3 <3 <3 <3 <3 <3",
    N__"I am but a robot ...",
    ###"-----+++++-----+++++"
);

sub random {
    my $chance = SSAuthenticator::config()->param('RandomGreetingChance');
    if ($chance > rand(100)) {
        return $greetings[ rand(scalar(@greetings)) ];
    }
    return undef;
}

=head2 overloadGreetings

Used mostly from test scripts when they need to set a predictable test context

=cut

sub overloadGreetings {
    my ($greetings) = @_;
    die "\$greetings must be an ARRAYREF" unless ref($greetings) eq 'ARRAY';

    @greetings = @$greetings;
}

1;
