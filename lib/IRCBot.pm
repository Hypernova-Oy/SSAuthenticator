# Copyright (C) 2017 Koha-Suomi
#
# This file is part of SSAuthenticator.

package IRCBot;

use Modern::Perl;

use Scalar::Util qw(blessed);

use SSAuthenticator::Config;

use SSLog;
my $l = bless({}, 'SSLog');

# Subclass Bot::BasicBot to provide event-handling methods.
use Bot::BasicBot;
use base qw(Bot::BasicBot);

=head1 PACKAGE

IRCBot

=head2 SYNOPSIS

see t/11-ircbot.t

=cut

my $ircbot;

sub new {
  my ($class, $params) = @_;
  $l->debug("IRCBot starting") if $l->is_debug();
  my $cnf = SSAuthenticator::Config::getConfig();

  warn Data::Dumper::Dumper($cnf);

  my $server = $params->{server} || $cnf->param('ircserver');
  $l->logdie("IRCBot needs config ircserver") unless $server;
  my $port = $params->{port} || $cnf->param('ircport');
  $l->logdie("IRCBot needs config ircport") unless $port;
  my $channels = $params->{channels} || $cnf->param('ircchannels');
  my @channels = split(/\s*,\s*/, $channels);
  $l->logdie("IRCBot needs config ircchannels") unless scalar(@channels);
  my $nick = $params->{nick} || $cnf->param('ircnick');
  $l->logdie("IRCBot needs config ircnick") unless $nick;
  my $name = $params->{name} || $cnf->param('ircname');
  $l->logdie("IRCBot needs config ircname") unless $name;
  my $iglist = $params->{ignore_list} || $cnf->param('ircignore_list') || '';
  my @iglist = split(/\s*,\s*/, $iglist);
  $l->logdie("IRCBot needs config ircchannels") unless scalar(@iglist);

$DB::single=1;
  $ircbot = $class->SUPER::new(
    server      => $server,
    port        => $port,
    channels    => \@channels,
    nick        => $nick,
    name        => $name,
    ignore_list => \@iglist,
  );
  $ircbot->{_inited} = 1; #Show that this object has actually been lazy-loaded already

  $ircbot->run();
  $l->debug("IRCBot is alive") if $l->is_debug();
  return $ircbot;
}

sub get {
  return $ircbot;
}

sub alertChannels {
  my $message = shift;
  my $params  = shift;
  $ircbot = __PACKAGE__->new($params) unless (blessed($ircbot) && $ircbot->isa('Bot::BasicBot'));

  my $cnf = SSAuthenticator::Config::getConfig();
  my $address = $params->{address} || $cnf->{ircaddress}; #To whom we address this message

  # The bot will respond by uppercasing the message and echoing it back.
  foreach my $channel (@{$ircbot->{channels}}) {
    $l->info("IRCBot chats") if $l->is_info();
    $ircbot->say(
      channel => $channel,
      body    => $message,
      address => $address,
    );
  }

  # The bot will shut down after sending messages
  #$self->shutdown('I have done my job here.');
  return 1;
}

1;
