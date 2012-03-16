use strict;
use warnings;

BEGIN { $ENV{PERL_RL} = 'Stub'; }
BEGIN { $^W = 0 } # common::sense does funny things, we don't need to hear about it.

use Test::More;

use Term::ReadLine 1.09;
use Term::ReadLine::Event;

plan skip_all => "Reflex is not installed" unless eval "use Reflex::Filehandle; use Reflex::Interval; 1";
plan tests => 2;

my $term = Term::ReadLine::Event->with_Reflex('test');
isa_ok($term->trl, 'Term::ReadLine::Stub');

my $ticker = Reflex::Interval->new(
                                   interval => 1,
                                   on_tick  => sub {
                                       pass;
                                       print {$term->trl()->OUT()} $Term::ReadLine::Stub::rl_term_set[3];
                                       exit 0 
                                   },
                                  );

$term->readline('> Do not type anything');
fail();
