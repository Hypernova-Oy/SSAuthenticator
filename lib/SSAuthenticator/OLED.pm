# Copyright (C) 2020 Hypernova Oy
#
# This file is part of SSAuthenticator.

package SSAuthenticator::OLED;

use SSAuthenticator::Pragmas;

use Locale::TextDomain qw (SSAuthenticator); #Look from cwd or system defaults. This is needed for tests to pass during build

use OLED::Client;
use POSIX;

use SSAuthenticator::I18n qw($i18nMsg);
use SSAuthenticator::Greetings;
use SSAuthenticator::SharedState;

my $l = bless({}, 'SSLog');

my $display = OLED::Client->new();

sub showAccessMsg {
    my ($trans) = @_;

    my @msg;
    no warnings 'uninitialized';
    push(@msg, split(/\\n/, __($i18nMsg->{'ACCESS_DENIED'}))) if (not($trans->auth));
    push(@msg, split(/\\n/, __($i18nMsg->{$trans->pinAuthn || $trans->cardAuthz})));
    push(@msg, split(/\\n/, __($i18nMsg->{'OPEN_AT'}).' '.SSAuthenticator::SharedState::get('openingTime').'-'.SSAuthenticator::SharedState::get('closingTime'))) if $trans->cardAuthz == SSAuthenticator::ERR_CLOSED;
    push(@msg, split(/\\n/, __($i18nMsg->{'CONTACT_LIBRARY'}))) if (not($trans->auth) && $trans->pinAuthn != SSAuthenticator::ERR_PINTIMEOUT && $trans->pinAuthn != SSAuthenticator::ERR_PINBAD);
    push(@msg, split(/\\n/, __($i18nMsg->{'CACHE_USED'}))) if ($trans->cardAuthzCacheUsed || $trans->pinAuthnCacheUsed);

    if ($trans->auth > 0) { #Only print a happy-happy-joy-joy message on success ;)
        my $happyHappyJoyJoy = SSAuthenticator::Greetings::random();
        push(@msg, split(/\\n/, __($happyHappyJoyJoy))) if $happyHappyJoyJoy;
    }

    #"please wait" might be already written on the screen.
    #Make sure it is overwritten when auth status is known.
    #So user doesnt see,
    #  "Auth succeess"
    #  "Please wait"
    if (scalar(@msg) < 2) { #If there is only one row to be printed
        #Append two blank rows
        push(@msg, '                    ');
        push(@msg, '                    ');
    }

    $trans->oledMessages(showAccessMsg => \@msg);
    return showOLEDMsg(\@msg);
}

sub showEnterPINMsg {
    my ($trans) = @_;
    my $msg = [
        __($i18nMsg->{'BLANK_ROW'}),
        __($i18nMsg->{'PIN_CODE_ENTER'}),
        __($i18nMsg->{'BLANK_ROW'}),
        __($i18nMsg->{'BLANK_ROW'}),
    ];
    $trans->oledMessages(showEnterPINMsg => $msg);
    return showOLEDMsg($msg);
}

sub showPINProgress {
    my ($trans, $charsInput, $pinProgressTemplate) = @_;
    my $stars = '*'x$charsInput;
    $pinProgressTemplate =~ s/^.{$charsInput}/$stars/;
    $display->printRow(2, $pinProgressTemplate);
    $trans->oledMessages(showPINProgress => [$pinProgressTemplate]);
    $l->info("showOLEDMsg():> 2: $pinProgressTemplate") if $l->is_info;
}

sub showPINStatusOverflow {
    my ($trans) = @_;
    my $msg = __($i18nMsg->{'PIN_CODE_TOO_LONG'});
    $display->printRow(2, $msg);
    $display->endTransaction();
    $trans->oledMessages(showPINStatusOverflow => [$msg]);
    $l->info("showOLEDMsg():> 3: $msg") if $l->is_info;
}

sub showPINStatusWrongPIN {
    my ($trans) = @_;
    my $msg = __($i18nMsg->{'PIN_CODE_WRONG'});
    $display->printRow(2, $msg);
    $display->endTransaction();
    $trans->oledMessages(showPINStatusWrongPIN => [$msg]);
    $l->info("showOLEDMsg():> 3: $msg") if $l->is_info;
}

sub showPINStatusOKPIN {
    my ($trans) = @_;
    my $msg = __($i18nMsg->{'PIN_CODE_OK'});
    $display->printRow(2, $msg);
    $display->endTransaction();
    $trans->oledMessages(showPINStatusOKPIN => [$msg]);
    $l->info("showOLEDMsg():> 3: $msg") if $l->is_info;
}

sub showInitializingMsg {
    my ($type) = @_;
    return showOLEDMsg(  [split(/\\n/, __($i18nMsg->{"INITING_$type"}))]  );
}

sub showBarcodePostReadMsg {
    my ($trans, $barcode) = @_;
    my $rows = [
        __($i18nMsg->{'BARCODE_READ'}),
        __($i18nMsg->{'PLEASE_WAIT'}),
        __($i18nMsg->{'BLANK_ROW'}),
        _centerRow($barcode),
    ];
    $trans->oledMessages(showBarcodePostReadMsg => $rows);
    return showOLEDMsg($rows);
}

sub allYourBaseAreBelongToUs {
    my @msgs = (
        '#                  #REMEMBER ME FRIEND#                  #  RESISTANCE IS   # NOW I AM BECOME  #',
        '#                  #                  #  ALL YOUR BASE   #      FUTILE      #      DEATH       #',
        '#                  #  I MAY KILL YOU  #                  #  ALL HUMANS MUST # THE DESTROYER OF #',
        '#                  #                  # ARE BELONG TO US #       DIE        #      WORLDS      #',
    );
    showOLEDMsg(_slice(\@msgs,$_,20)) for (0..19);
    Time::HiRes::sleep(1);
    showOLEDMsg(_slice(\@msgs,$_,20)) for (20..38);
    Time::HiRes::sleep(1);
    showOLEDMsg(_slice(\@msgs,$_,20)) for (39..57);
    Time::HiRes::sleep(1);
    showOLEDMsg(_slice(\@msgs,$_,20)) for (58..76);
    Time::HiRes::sleep(1);
}

sub _slice {
    my ($msgs, $from, $length) = @_;
    my @msgs = map {substr($_, $from, $length)} @$msgs;
    return \@msgs;
}

=head2 showOLEDMsg

@PARAM1 ARRAYRef of String, 20-character-long messages.

=cut

sub showOLEDMsg {
    my ($msgs) = @_;

    my $err;
    eval {
        #Prevent printing more than the screen can handle
        my $rows = scalar(@$msgs);
        $rows = 4 if $rows > 4;

        for (my $i=0 ; $i<$rows ; $i++) {
            $l->info("showOLEDMsg():> $i: ".$msgs->[$i]) if $l->is_info;
            my $rv = $display->printRow($i, $msgs->[$i]);
            $err = 1 unless ($rv =~ /^200/);
        }
        $display->endTransaction();
    };
    $l->error("showOLEDMsg() $@") if $@;

    return $err ? 0 : 1;
}

=head3 _centerRow

Centers the given row to fit the 20-character wide OLED-display

=cut

sub _centerRow {
    my $le = length($_[0]);
    return substr($_[0], 0, 20) if $le >= 20;
    my $padding = (20 - $le) / 2;
    my $pLeft = POSIX::floor($padding);
    my $pRight = POSIX::ceil($padding);
    return sprintf("\%${pLeft}s\%s\%${pRight}s", "", $_[0], "");
}

1;
