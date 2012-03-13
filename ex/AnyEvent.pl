#!/usr/bin/perl

use strict;
use warnings;

use AnyEvent;
use Term::ReadLine;

my $CSI = "\x1b[";
print "${CSI}2J${CSI}3H";
$|++;

my $t = 0;
sub tick {print STDERR "${CSI}s${CSI}1H$t s ${CSI}u";++$t}
my $w = AE::timer (0,1,\&tick);
my $term = Term::ReadLine->new('...');

my @words = qw(abase
abased
abasedly
abasedness
abasement
abaser
abash
abashed
abashedly
abashedness
abashless
abashlessly);

$term->Attribs()->{completion_function} = sub {
    my ($word, $line, $pos) = @_;
    $word ||= "";

    grep /^$word/i, @words;
};

# set up the event loop callbacks.
$term->event_loop(
                  sub {
                      # This callback is called every time T::RL wants to
                      # read something from its input.  The parameter is
                      # the return from the other callback.
                      my $data = shift;
                      $data->[0] = AE::cv();
                      $data->[0]->recv();
                  }, sub {
                      # This callback is called as the T::RL is starting up
                      # readline the first time.  The parameter is the file
                      # handle that we need to monitor.  The return value
                      # is used as input to the previous callback.
                      my $fh = shift;

                      # The data for AE are: the file event watcher (which
                      # cannot be garbage collected until we're done) and
                      # a placeholder for the condvar we're sharing between
                      # the AE::io callback created here and the wait
                      # callback above.
                      my $data = [];
                      $data->[1] = AE::io($fh, 0, sub { $data->[0]->send() });
                      $data;
                  }
                 );


my $x = $term->readline('> ');

# when we're completely done, we can do this.  Note that this still does not
# allow us to create a second T::RL, so only do this when your process
# will not use T::RL ever again.  Most of the time we shouldn't need this,
# though some event loops may require this.  Reading AnyEvent::Impl::Tk
# seems to imply that not cleaning up may cause crashes, for example.
$term->event_loop(undef);

# No further cleanup required other than letting $data->[1] go out of scope
# and thus deregister.

print "Got: [$x] in $t s\n";
