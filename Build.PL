use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Term::ReadLine::Event',
    license             => 'perl',
    dist_author         => q{Darin McBride <dmcbride@cpan.org>},
    dist_version_from   => 'lib/Term/ReadLine/Event.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl' => 5.006,
        'Term::ReadLine' => 1.09,
    },
    add_to_cleanup      => [ 'Term-ReadLine-Event-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
