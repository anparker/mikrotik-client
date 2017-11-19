#!/usr/bin/env perl

use warnings;
use strict;

use lib './';

use Test::More;
use API::MikroTik::Response;
use API::MikroTik::Sentence qw(encode_sentence);

my $r = API::MikroTik::Response->new();

my $packed = encode_sentence('!re', {one => 1, two => 2});
$packed .= encode_sentence('!re', {three => 3, four => 4, five => 5}, undef, 3);
$packed .= encode_sentence('!done');

my $data = $r->parse(\$packed);
is_deeply $data,
    [
    {'one' => '1', 'two' => '2', '.tag' => '', '.type' => '!re'},
    {
        'five'  => '5',
        'four'  => '4',
        'three' => '3',
        '.tag'  => '3',
        '.type' => '!re'
    },
    {'.tag' => '', '.type' => '!done'}
    ],
    'right response';

$packed = encode_sentence('!trap', {category => 1, message => 'error message'},
    undef, 4);
$data = $r->parse(\$packed);

is_deeply $data,
    [
    {
        'category' => '1',
        'message'  => 'error message',
        '.tag'     => '4',
        '.type'    => '!trap'
    }
    ],
    'right error response';

# reassemble partial buffer
my ($attr, @parts);
$attr->{$_} = $_ x 200 for 1 .. 4;
$packed = encode_sentence('!re', $attr);
$packed .= $packed;
$packed .= $packed;
push @parts, (substr $packed, 0, $_, '') for (900, 700, 880);
push @parts, $packed;
$attr->{'.tag'}  = '';
$attr->{'.type'} = '!re';

my $w = $r->parse(\$parts[0]);
is_deeply $w, [$attr], 'right result';
ok $r->sentence->is_incomplete, 'incomplete is set';
$w = $r->parse(\$parts[1]);
is_deeply $w, [], 'right result';
ok $r->sentence->is_incomplete, 'incomplete is set';
$w = $r->parse(\$parts[2]);
is_deeply $w, [($attr) x 2], 'right result';
ok $r->sentence->is_incomplete, 'incomplete is set';
$w = $r->parse(\$parts[3]);
is_deeply $w, [$attr], 'right result';
ok !$r->sentence->is_incomplete, 'incomplete is not set';

done_testing();

