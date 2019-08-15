#!/usr/bin/perl -w

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib"; # t/lib
use Test::More;
use MT::Test::Env;
our $test_env;
BEGIN {
    $test_env = MT::Test::Env->new;
    $ENV{MT_CONFIG} = $test_env->config_file;
}

use MT::Test;

MT::Test->init_app;

$test_env->prepare_fixture('db_data');

my $admin = MT::Author->load(1);
$admin->email('test@localhost.localdomain');
$admin->save;

{
    my $app = _run_app(
        'MT::App::CMS',
        {
            __mode => 'start_recover',
            return_to => 'http://foo',
        },
    );
    my $out = delete $app->{__test_output};
    like $out => qr!Invalid request!, 'invalid request at start_recover';
    unlike $out => qr!"http://foo"!, 'no invalid return_to link';
}

{
    my $app = _run_app(
        'MT::App::CMS',
        {
            __mode => 'start_recover',
            return_to => 'http://narnia.na',
        },
    );
    my $out = delete $app->{__test_output};
    unlike $out => qr!Invalid request!, 'not an invalid request at start_recover';
    like $out => qr!value="http://narnia.na"!, 'valid return_to';
}

{
    my $app = _run_app(
        'MT::App::CMS',
        {
            __mode => 'recover',
            email => $admin->email,
            return_to => 'http://foo',
        },
    );
    my $out = delete $app->{__test_output};
    like $out => qr!Invalid request!, 'invalid request at recover';
    unlike $out => qr!href="http://foo"!, 'no invalid return_to link';
    unlike $out => qr!"http://foo"!, 'no invalid return_to link';
}

{
    my $app = _run_app(
        'MT::App::CMS',
        {
            __mode => 'recover',
            email => $admin->email,
            return_to => 'http://narnia.na',
        },
    );
    my $out = delete $app->{__test_output};
    unlike $out => qr!Invalid request!, 'not invalid request';
    like $out => qr!href="http://narnia.na"!, 'valid return_to';
}

done_testing;
