#!/usr/bin/perl

use strict;
use warnings;

use Tk;
use Term::ReadLine 1.09;

use File::Basename;
use lib dirname($0) . '/lib';
use ExampleHelpers qw(
  initialize_completion update_time print_input
);

our $mw = MainWindow->new(-title => '');
$mw->withdraw();

my $w; $w = sub { update_time(); Tk::after($mw, 1000, $w) };
Tk::after($mw, 1000, $w);

my $term = Term::ReadLine->new('...');
initialize_completion($term);

# set up the event loop callbacks.
$term->event_loop(
                  sub {
                      my $data = shift;
                      Tk::DoOneEvent(0) until $$data;
                      $$data = 0;
                  },
                  sub {
                      my $fh = shift;
                      my $data;
                      $$data = 0;
                      Tk->fileevent($fh, 'readable', sub { $$data = 1 });
                      $data;
                  }
                 );

my $input = $term->readline('> ');

# when we're completely done, we can do this.  Note that this still does not
# allow us to create a second T::RL, so only do this when your process
# will not use T::RL ever again.  Most of the time we shouldn't need this,
# though some event loops may require this.  Reading AnyEvent::Impl::Tk
# seems to imply that not cleaning up may cause crashes, for example.
$term->event_loop(undef);

# No further cleanup required other than letting $data->[1] go out of scope
# and thus deregister.

print_input($input);
