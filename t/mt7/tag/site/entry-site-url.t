#!/usr/bin/perl

use strict;
use warnings;

use lib qw(lib t/lib);

BEGIN {
    $ENV{MT_CONFIG} = 'mysql-test.cfg';
}

use MT::Test::Tag;

plan tests => 2 * blocks;

use MT;
use MT::Test qw(:db :data);
use MT::Test::Permission;

filters {
    blog_id  => [qw( chomp )],
    template => [qw( chomp )],
    expected => [qw( chomp )],
    error    => [qw( chomp )],
};

MT::Test::Permission->make_entry( blog_id => 2 );

MT::Test::Tag->run_perl_tests;
MT::Test::Tag->run_php_tests;

__END__

=== mt:EntrySiteURL - blog
--- blog_id
1
--- template
<mt:Entries limit="1"><mt:EntrySiteURL></mt:Entries>
--- expected
http://narnia.na/nana/

=== mt:EntrySiteURL - website
--- blog_id
2
--- template
<mt:Entries limit="1"><mt:EntrySiteURL></mt:Entries>
--- expected
http://narnia.na/

