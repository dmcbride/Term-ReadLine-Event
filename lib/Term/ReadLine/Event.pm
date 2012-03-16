package Term::ReadLine::Event;

use 5.006;
use strict;
use warnings;

use Term::ReadLine 1.09;

=head1 NAME

Term::ReadLine::Event - Wrappers for Term::ReadLine's new event_loop model.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Provides many of the event loop interactions shown in the examples
as a small change to your code rather than the longer code required.

    use AnyEvent;
    use Term::ReadLine::Event;

    my $term = Term::ReadLine::Event->with_AnyEvent();

    my $input = $term->readline('Prompt >');

This may actually be sufficient for your use, or it may not.  This likely
depends on the loop being used.

=head1 METHODS

All constructors (C<with_>*) take as their first parameter the name 
of the application, which gets passed in to Term::ReadLine's constructor.

If you need to use more parameters to Term::ReadLine's constructor, such
as specifying the input and output filehandles, then pass all of the
parameters for Term::ReadLine in as an anonymous array ref:

   Term::ReadLine::Event->with_Foo(['myapp', \*STDIN, \*STDOUT]);

Paramters for setting up the event loop, if any are required, will be
after the application name or array ref as named parameters, e.g.:

   Term::ReadLine::Event->with_IO_Async('myapp', loop => $loop);

All constructors also assume that the required module(s) is(are) already
loaded.  That is, if you're using with_AnyEvent, you have already loaded
AnyEvent; if you're using with_POE, you have already loaded POE, etc.

=head2 with_AnyEvent

Creates a L<Term::ReadLine> object and sets it up for use with AnyEvent.

=cut

sub _new {
    my $class = shift;
    my $app   = shift;

    my $self = bless {@_}, $class;

    $self->{_term} = Term::ReadLine->new(ref $app ? @$app : $app);
    $self;
}

sub with_AnyEvent {
    my $self = _new(@_);

    $self->trl->event_loop(
                           sub {
                               my $data = shift;
                               $data->[0] = AE::cv();
                               $data->[0]->recv();
                           }, sub {
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

    $self;
}

=head2 with_Coro

Creates a L<Term::ReadLine> object and sets it up for use with Coro.

=cut

sub with_Coro {
    my $self = _new(@_);

    $self->trl->event_loop(
                           sub {
                               # Tell Coro to wait until we have something to read,
                               # and then we can return.
                               shift->readable();
                           }, sub {
                               # in Coro, we just need to unblock the filehandle,
                               # and save the unblocked filehandle.
                               unblock $_[0];
                           }
                          );
    $self;
}

=head2 with_IO_Async

Creates a L<Term::ReadLine> object and sets it up for use with IO::Async.

Parameters:

=over 4

=item loop

The IO::Async loop object to integrate with.

=back

=cut

sub with_IO_Async {
    my $self = _new(@_);

    $self->trl->event_loop(
                           sub {
                               my $ready = shift;
                               $$ready = 0;
                               $self->{loop}->loop_once while !$$ready;
                           },
                           sub {
                               my $fh = shift;

                               # The data for IO::Async is just the ready flag.  To
                               # ensure we're referring to the same value, this is
                               # a SCALAR ref.
                               my $ready = \ do{my $dummy};
                               $self->{loop}->add(
                                                  $self->{watcher} =
                                                  IO::Async::Handle->new(
                                                                                    read_handle => $fh,
                                                                                    on_read_ready => sub { $$ready = 1 },
                                                                                   )
                                                 );
                               $ready;
                           }
                          );

    $self->{_cleanup} = sub {
        my $s = shift;
        $s->{loop}->remove($s->{watcher});
    };

    $self;
}

=head2 with_POE

Creates a L<Term::ReadLine> object and sets it up for use with POE.

=cut

sub with_POE
{
    my $self = _new(@_);

    my $waiting_for_input;

    POE::Session->create(
    inline_states => {

      # Initialize the session that will drive Term::ReadLine.
      # Tell Term::ReadLine to invoke a couple POE event handlers when
      # it's ready to wait for input, and when it needs to register an
      # I/O watcher.

      _start => sub {
        $self->trl->event_loop(
          $_[POE::Session->SESSION]->callback('term_readline_waitfunc'),
          $_[POE::Session->SESSION]->callback('term_readline_regfunc'),
        );
      },

      # This callback is invoked every time Term::ReadLine wants to
      # read something from its input file handle.  It blocks
      # Term::ReadLine until input is seen.
      #
      # It sets a flag indicating that input hasn't arrived yet.
      # It watches Term::ReadLine's input filehandle for input.
      # It runs while it's waiting for input.
      # It turns off the input watcher when it's no longer needed.
      #
      # POE::Kernel's run_while() dispatches other events (including
      # "term_readline_readable" below) until $waiting_for_input goes
      # to zero.

      term_readline_waitfunc => sub {
        my $input_handle = $_[POE::Session->ARG1][0];
        $waiting_for_input = 1;
        $_[POE::Session->KERNEL]->select_read($input_handle => 'term_readline_readable');
        $_[POE::Session->KERNEL]->run_while(\$waiting_for_input);
        $_[POE::Session->KERNEL]->select_read($input_handle => undef);
      },

      # This callback is invoked as Term::ReadLine is starting up for
      # the first time.  It saves the exposed input filehandle where
      # the "term_readline_waitfunc" callback can see it.

      term_readline_regfunc => sub {
        my $input_handle = $_[POE::Session->ARG1][0];
        return $input_handle;
      },

      # This callback is invoked when data is seen on Term::ReadLine's
      # input filehandle.  It clears the $waiting_for_input flag.
      # This causes run_while() to return in "term_readline_waitfunc".

      term_readline_readable => sub {
        $waiting_for_input = 0;
      },
    },
  );
    $self;
}

=head2 with_Reflex

Creates a L<Term::ReadLine> object and sets it up for use with Reflex.

=cut

sub with_Reflex
{
    my $self = _new(@_);

    $self->trl->event_loop(
                           sub {
                               my $input_watcher = shift();
                               $input_watcher->next();
                           },
                           sub {
                               my $input_handle  = shift();
                               my $input_watcher = Reflex::Filehandle->new(
                                                                           handle => $input_handle,
                                                                           rd     => 1,
                                                                          );
                               return $input_watcher;
                           },
                          );


    $self;
}

=head2 DESTROY

During destruction, we attempt to clean up.  Note that L<Term::ReadLine>
does not like to have a second T::RL object created in the same process.
This means that you should only ever let the object returned by the
constructors to go out of scope when you will I<never use Term::ReadLine
again in that process>.

This largely makes destruction moot, but it can be nice in some scenarios
to clean up after oneself.

=cut

sub DESTROY
{
    my $self = shift;

    local $@;
    eval {
        $self->trl->event_loop(undef);

        $self->{_cleanup}->($self) if $self->{_cleanup};
    };
}

=head2 trl

Access to the Term::ReadLine object itself.  Since Term::ReadLine::Event
is not a Term::ReadLine, but HAS a Term::ReadLine, this gives access to
the underlying object in case something isn't exposed sufficiently.

=cut

sub trl
{
    my $self = shift;
    $self->{_term};
}

=head2 readline

Wrapper for Term::ReadLine's readline.  Makes it convenient to just
call C<$term->readline(...)>.

=cut

sub readline
{
    my $self = shift;
    $self->trl->readline(@_);
}

=head2 Attribs

Wrapper for Term::ReadLine's Attribs.  Makes it convenient to just
call C<$term->Attribs(...)>.

=cut

sub Attribs
{
    my $self = shift;
    $self->trl->Attribs(@_);
}

=head1 AUTHOR

Darin McBride, C<< <dmcbride at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-term-readline-event at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Term-ReadLine-Event>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Term::ReadLine::Event


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Term-ReadLine-Event>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Term-ReadLine-Event>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Term-ReadLine-Event>

=item * Search CPAN

L<http://search.cpan.org/dist/Term-ReadLine-Event/>

=back


=head1 ACKNOWLEDGEMENTS

=over 4

=item Paul "LeoNerd" Evans <leonerd@leonerd.org.uk>

For all the examples (IO-Async, IO-Poll, select, and fixes for AnyEvent).

=item Rocco Caputo <rcaputo@cpan.org>

For a final patch to Term::ReadLine that helps reduce the number
of variables that get closed upon making much of this easier to handle.

For the POE and Reflex examples, and a push to modularise the examples.

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Darin McBride and others.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Term::ReadLine::Event
