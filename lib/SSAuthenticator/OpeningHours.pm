#!/usr/bin/perl
# Copyright (C) 2022 Hypernova Oy
#
# This file is part of SSAuthenticator.
#

package SSAuthenticator::OpeningHours;

=encoding utf8

=head1 NAME

    SSAuthenticator::Koha - Synchronize configurations, such as opening hours from Koha

=cut

use Modern::Perl;

use DateTime;
use File::BackupCopy;
use Scalar::Util qw(blessed);
use Struct::Diff;
use Try::Tiny;
use YAML::XS;

use SSAuthenticator::API;
use SSAuthenticator::Config;
use SSLog;

my $l = bless({}, 'SSLog');

sub new {
    my ($class, $weekdays) = @_;
    my $self = bless({}, $class);
    $self->{weekdays} = $weekdays;
    return $self;
}

sub start {
    my ($self, $weekday) = @_;
    return $self->{weekdays}->[$weekday || $self->{weekday}]->[0];
}

sub end {
    my ($self, $weekday) = @_;
    return $self->{weekdays}->[$weekday || $self->{weekday}]->[1];
}

sub isOpen {
    my ($self) = @_;
    my $dt = DateTime->now();
    my $time = $dt->strftime('%H%M');
    $self->{weekday} = $dt->day_of_week() - 1; #DateTime->day_of_week() Returns the day of the week as a number, from 1..7, with 1 being Monday and 7 being Sunday.
    my $start = $self->start($self->{weekday});
    $start =~ s/://;
    my $end = $self->end($self->{weekday});
    $end =~ s/://;
    if ($start <= $time && $time <= $end) {
        return 1;
    }
    else {
        return 0;
    }
}

=head2 sanitate

Trim non-number characters from the start and end times, to make internal date comparison fast and effective.

12:00 => 1200

=cut

sub sanitate {
    my ($self) = @_;

    for (my $i=0 ; $i<@{$self->{weekdays}} ; $i++) {
        $self->{weekdays}->[$i]->[0] =~ s/[^0-9]//gsm;
        $self->{weekdays}->[$i]->[1] =~ s/[^0-9]//gsm;
    }
}





sub synchronize {
    my () = @_;
    $l->debug("synchronize()") if $l->is_debug();

    my $openingHours = loadOpeningHoursFromDB();
    my ($response, $body, $err, $status) = SSAuthenticator::API::getOpeningHours();

    if ($err || $status != 200) {
        die "Error synchronizing OpeningHours! API response:\n error='$err'\n status='$status'\n HTTP Request dump:\n".$response->as_string()."\n";
    }

    if (_hasConfigurationChanged($openingHours, $body)) {
        _logOpeningHoursDiff(_persistOpeningHoursToDB($body));
    }
    else {
        # There is no diff
    }
    return 1;
}

sub loadOpeningHoursFromDB {
    my $c = SSAuthenticator::Config::getConfig();

    my $rv = eval {
        unless (-e $c->param("OpeningHoursDBFile")) {
            File::Slurp::write_file($c->param("OpeningHoursDBFile"), "");
        };

        my $file = File::Slurp::read_file(
            $c->param("OpeningHoursDBFile"),
            binmode => 'utf8'
        );

        my $s = YAML::XS::Load(
            $file
        );

        return __PACKAGE__->new(
            $s
        );
    };
    if ($@) {
        die "Failed to load the OpeningHoursDBFile '".$c->param("OpeningHoursDBFile")."'.\n".$@;
    }
    return $rv;
}

sub _persistOpeningHoursToDB {
    my ($openingHours) = @_;
    my $c = SSAuthenticator::Config::getConfig();

    my $backupName;
    eval {
        my $file = YAML::XS::Dump(
            $openingHours
        );

        $backupName = File::BackupCopy::backup_copy($c->param("OpeningHoursDBFile"), BACKUP_NUMBERED);

        File::Slurp::write_file(
            $c->param("OpeningHoursDBFile"),
            { binmode => 'utf8' },
            "# This file contains the opening hours for this specific Toveri access control device.\n",
            "# It is synchronized using the sssync-utility which is configured to be ran periodically via crontab.\n",
            $file,
        )
    };
    if ($@) {
        die("Writing OpeningHoursDBFile '".$c->param("OpeningHoursDBFile")."' failed!\n".$@);
    }
    return ($c->param("OpeningHoursDBFile"), $backupName);
}

sub _hasConfigurationChanged {
    my ($self, $newOpeningHours) = @_;
    my $diff = Struct::Diff::diff($self->{weekdays}, $newOpeningHours);
    return ($diff->{A} || $diff->{D} || $diff->{I} || $diff->{N} || $diff->{O} || $diff->{R});
}

sub _logOpeningHoursDiff {
    my ($newFile, $backupFile) = @_;
    unless(-e $newFile && -e $backupFile) { # Defensive programming to prevent privilege escalation here.
        $l->error("_persistOpeningHoursToDB() returned backup file '$backupFile' and the original file '$newFile', but they do not exist?");
    }
    else {
        $l->info("New Opening Hours configuration found:\n    New opening hours  <=>  Old opening hours\n".`diff -y $newFile $backupFile`);
    }
}

1;
