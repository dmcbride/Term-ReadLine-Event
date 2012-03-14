#!/usr/bin/perl
# vim: ts=2 sw=2 expandtab

use strict;
use warnings;

use Term::ReadLine;
use Reflex::Filehandle;
use Reflex::Interval;

use Term::ReadLine::Event::ExampleHelpers qw(
  initialize_completion update_time print_input
);

# Create a Term::ReadLine object.
# Initialize completion to test whether tab-completion works.

my $term = Term::ReadLine->new('...');
initialize_completion($term);

# Drive the Term::ReadLine object with a Reflex::Filehandle watcher.

$term->event_loop(

  # This callback is a "wait function".  It's invoked every time
  # Term::ReadLine wants to read something from its input.  The
  # parameter is the data returned from the "registration function",
  # below.

  sub {
    my $input_watcher = shift();
    $input_watcher->next();
  },

  # This callback is a "registration function".  It's invoked as
  # Term::ReadLine is starting up for the first time.  It sets up an
  # input watcher for the terminal's input file handle.
  #
  # This registration function returns the input watcher.
  # Term::ReadLine passes the watcher to the wait function (above).

  sub {
    my $input_handle  = shift();
    my $input_watcher = Reflex::Filehandle->new(
      handle => $input_handle,
      rd     => 1,
    );
    return $input_watcher;
  },
);

# Mark time with a single-purpose Reflex::Interval timer.

my $ticker = Reflex::Interval->new(
  interval => 1,
  on_tick  => \&update_time,
);

# Get a line of input while POE continues to dispatch events.
# Display the line and the time it took to receive.
# Exit.

my $input = $term->readline('> ');
print_input($input);
exit;
