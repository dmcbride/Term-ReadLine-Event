#!/usr/bin/perl

use strict;
use warnings;

use Term::ReadLine;

my $CSI = "\x1b[";
print "${CSI}2J${CSI}3H";
$|++;
my $t = 0;
sub tick {print STDERR "${CSI}s${CSI}1H$t s ${CSI}u";++$t}

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

# Presumably, if you're using this loop, you're also selecting on other
# fileno's.  It is up to you to add that in to the wait callback (first
# one passed to event_loop) and deal with those file handles.

$term->event_loop(
                  sub {
                      # This callback is called every time T::RL wants to
                      # read something from its input.  The parameter is
                      # the return from the other callback.
                      my $fileno = shift;
                      my $rvec = '';
                      vec($rvec, $fileno, 1) = 1;
                      while(1) {
                          select my $rout = $rvec, undef, undef, 1.0;
                          last if vec($rout, $fileno, 1);
                          tick();
                      }
                  },
                  sub {
                      # This callback is called as the T::RL is starting up
                      # readline the first time.  The parameter is the file
                      # handle that we need to monitor.  The return value
                      # is used as input to the previous callback.

                      # We return the fileno that we will use later.
                      $fh->fileno;
                  }
                 );

my $x = $term->readline('> ');

# No further cleanup required

print STDOUT "Got: [$x] in $t s\n";