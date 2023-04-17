# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SSAuthenticator.

package SSAuthenticator::Mailbox;

use Modern::Perl;

use Locale::TextDomain qw (SSAuthenticator); #Look from cwd or system defaults. This is needed for tests to pass during build

use File::Basename;
use File::Slurp;

use SSLog;
use SSAuthenticator::Config;

=head1 SSAuthenticator::Mailbox

Checks a designated "mailbox"-dir for a simple IPC message.
If there is such a file, parses it, does the given action, and truncates the file.

=cut

my $l = bless({}, 'SSLog');

=head2 checkMailbox

Checks the mailbox for anything to execute
Skips files starting with . or README

=cut

sub checkMailbox {
    #We initiate a "object" so we can more easily dynamically invoke subroutines
    my $self = bless({}, __PACKAGE__);

    my $config = SSAuthenticator::Config::getConfig();

    my @files = glob($config->param('MailboxDir').'/*');

    foreach my $filePath (@files) {
        my $file = File::Basename::basename($filePath);
        my $content = File::Slurp::read_file($filePath, { binmode => ':utf8' });

        next if $file =~ /^(\.|README)/;

        $self->dispatch($file, split(/\s+/,$content));
        $l->debug("checkMailBox() removing '$filePath'");
        unlink $filePath;
    }
    return 1;
}

=head2 sendMessage

Sends a message to the mailbox

@PARAM1 String, Command to execute. One of:
                - controlAccess
                - ...
@PARAM2 ARRAY, Parameters to pass to the command message
@THROWS die if the command cannot be dispatched

=cut

sub sendMessage {
    my ($command, @params) = @_;
    my $config = SSAuthenticator::Config::getConfig();

    #We initiate a "object" so we can more easily dynamically invoke subroutines
    my $self = bless({}, __PACKAGE__);

    #Die or succeed
    $self->_canDispatch($command);

    my $mailboxFile = $config->param('MailboxDir').'/'.$command;
    open(my $FH, '>:encoding(UTF-8)', $mailboxFile)
        or die("Failed to write a mailbox message to mailbox '$mailboxFile': $!");
    print $FH join(' ', @params);
    close($FH);
    return 1;
}

sub dispatch {
    my ($self, $command, @params) = @_;
    my $rv;

    my $subroutineDispatcher;
    eval {
        $subroutineDispatcher = $self->_canDispatch($command);
    };
    if ($@) {
        $l->error("dispatch() $@");
        return undef;
    }
    eval {
        $l->info("Mailbox dispatching '$command' with \@params '@params'") if $l->is_info;
        $rv = $self->$subroutineDispatcher(@params);
        $l->info("Mailbox dispatched '$command'. Returned '$rv'") if $l->is_info;
    };
    if ($@) {
        $l->fatal("Mailbox dispatched '$command' died with '$@'");
    }
    return $rv;
}

=head2 _canDispatch

@PARAM1 SSAuthenticator::Mailbox
@PARAM2 String, command to dispatch
@RETURNS String, the name of the subroutine to execute
@THROWS die, if the given command cannot be dispatched

=cut

sub _canDispatch {
    my ($self, $command) = @_;

    my $subroutineDispatcher = 'dispatch_'.$command;
    unless ($self->can($subroutineDispatcher)) {
        die "Mailbox is not allowed to dispatch '$command'";
    }
    return $subroutineDispatcher;
}

sub dispatch_controlAccess {
    my $self = shift @_;
    return SSAuthenticator::controlAccess(@_, SSAuthenticator::Transaction->new());
}

1;
