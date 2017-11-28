#!/usr/bin/env perl

use warnings;
use strict;

use lib './';

use Test::More;

use API::MikroTik;
use API::MikroTik::Response;
use API::MikroTik::Sentence;
use Mojo::IOLoop;

my $r = API::MikroTik::Response->new();

my $count   = 0;
my $chat    = _chat_log();
my $serv_id = Mojo::IOLoop->server(
    {address => '127.0.0.1'} => sub {
        my ($loop, $stream, $id) = @_;
        $stream->on(
            read => sub {
                my ($stream, $bytes) = @_;

                my $data = $r->parse(\$bytes);
                for (@$data) {
                    my $line = $chat->[$count];

                    is_deeply $_, @$line[1, 0];

                    my $resp = '';
                    $resp .= API::MikroTik::Sentence::_encode_word($_)
                        for @{$line->[2]};
                    $stream->write($resp);

                    $count++;
                }
            }
        );
    }
);
my $port = Mojo::IOLoop->acceptor($serv_id)->port;

my $api = API::MikroTik->new(
    user     => 'test',
    password => 'tset',
    host     => '127.0.0.1',
    port     => $port,
    tls      => 0,
);

# delay requests until loop start
Mojo::IOLoop->next_tick(
    sub {
        $api->cmd(
            '/system/resource/print',
            {'.proplist' => 'board-name,version,uptime'} => sub {
                shift;
                isa_ok $_[1], 'Mojo::Collection', 'right result type';
                is_deeply [@_],
                    [
                    '',
                    [
                        {
                            'board-name' => 'dummy',
                            uptime       => '0d0h0s',
                            version      => '0.00'
                        },
                        {
                            'board-name' => 'dummy',
                            uptime       => '0d0h0s',
                            version      => '0.01'
                        },
                    ]
                    ],
                    'c: command response';
            }
        );
        $api->cmd(
            '/random/command' => sub {
                shift;
                is_deeply [@_],
                    [
                    'random error', [{message => 'random error', category => 0}]
                    ],
                    'c: command error';
                Mojo::IOLoop->stop();
            }
        );
    }
);
Mojo::IOLoop->start();

my ($err1, $err2);
$api->cmd('/test/cmd1' => sub { $err1 = $_[1] });
$api->cmd('/test/cmd1' => sub { $err2 = $_[1] });
$api->_fail_all(Mojo::IOLoop->singleton, 'test error');
is $err1, 'test error', 'right error';
is $err2, 'test error', 'right error';

done_testing();


sub _chat_log {
    return [
        [
            's: login request',
            {'.type' => '/login', '.tag' => 3},
            ['!done', '.tag=3', '=ret=098f6bcd4621d373cade4e832627b4f6', '',],
        ],
        [
            's: login response',
            {
                '.type'  => '/login',
                '.tag'   => 4,
                name     => 'test',
                response => '00119ce7e093e33497053e73f37a5d3e15',
            },
            ['!done', '.tag=4', '',],
        ],
        [
            's: command request',
            {
                '.type'     => '/system/resource/print',
                '.tag'      => 1,
                '.proplist' => 'board-name,version,uptime',
            },
            [
                '!re', '.tag=1', '=board-name=dummy', '=version=0.00',
                '=uptime=0d0h0s', '',
                '!re', '.tag=1', '=board-name=dummy', '=version=0.01',
                '=uptime=0d0h0s', '',
                '!done', '.tag=1', '',
             ],
        ],
        [
            's: misused command request',
            {'.type' => '/random/command', '.tag' => 2},
            ['!trap', '.tag=2', '=message=random error', '=category=0', ''],
        ],
    ];
}

