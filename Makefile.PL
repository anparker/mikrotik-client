use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'API::MikroTik',
  VERSION_FROM => 'lib/API/MikroTik.pm',
  AUTHOR       => 'Andre Parker <andreparker@gmail.com>',
  PREREQ_PM    => {'Mojolicious' => '7.00'},
  test         => {TESTS => 't/*.t'}
);

