#!/usr/bin/perl
# vim: ts=2 sw=2 expandtab

use strict;
use warnings;

use POE;             # We're going to use POE here.
POE::Kernel->run();  # Silence run() warning.  See POE docs.

use Term::ReadLine::Event::ExampleHelpers qw(
  initialize_completion update_time print_input
);

# Mark time with a single-purpose POE session.
#
# It's often better to divide programs with multiple concerns into
# loosely coupled units, each addressing a single concern.

POE::Session->create(
  inline_states => {
    _start => sub { $_[KERNEL]->delay(tick => 1);                },
    tick   => sub { $_[KERNEL]->delay(tick => 1); update_time(); },
  },
);

# Create a Term::ReadLine object.
# Initialize completion to test whether tab-completion works.
# Hook Term::ReadLine into POE so everybody is happy.
# Get a line of input while POE continues to dispatch events.
# Display the line and the time it took to receive.
# Exit.

my $term = Term::ReadLine->new('...');
initialize_completion($term);
drive_with_poe($term);

my $input = $term->readline('> ');
print_input($input);

exit;

# This function takes a Term::ReadLine object and drives it with POE.
# Abstracted into a function for easy reuse.

sub drive_with_poe {
  my ($term_readline) = @_;

  my $waiting_for_input;

  POE::Session->create(
    inline_states => {

      # Initialize the session that will drive Term::ReadLine.
      # Tell Term::ReadLine to invoke a couple POE event handlers when
      # it's ready to wait for input, and when it needs to register an
      # I/O watcher.

      _start => sub {
        $term_readline->event_loop(
          $_[SESSION]->callback('term_readline_waitfunc'),
          $_[SESSION]->callback('term_readline_regfunc'),
        );
      },

      # This callback is invoked every time Term::ReadLine wants to
      # read something from its input file handle.  It blocks
      # Term::ReadLine until input is seen.
      #
      # POE::Kernel's run_while() dispatches other events (including
      # "term_readline_readable" below) until $waiting_for_input goes
      # to zero.

      term_readline_waitfunc => sub {
        $waiting_for_input = 1;
        $_[KERNEL]->run_while(\$waiting_for_input);
      },

      # This callback is invoked as Term::ReadLine is starting up for
      # the first time.  It sets up an input watcher for the
      # terminal's input file handle.
      #
      # The "term_readline_readable" callback will be invoked as
      # keystrokes arrive on the terminal.  That callback will clear
      # $waiting_for_input, which will allow "term_readline_waitfunc"
      # to return.

      term_readline_regfunc => sub {
        my $fh = $_[ARG1][0];
        $_[KERNEL]->select_read($fh => 'term_readline_readable');
      },

      # Clear the waiting flag when input is seen on the console.
      # This causes run_while() to return in "term_readline_waitfunc".

      term_readline_readable => sub {
        $waiting_for_input = 0;
      },
    },
  );
}
