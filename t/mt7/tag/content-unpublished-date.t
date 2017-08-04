#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use lib qw(lib t/lib);

use MT::Test::Tag;

# plan tests => 2 * blocks;
plan tests => 1 * blocks;

use MT;
use MT::Test qw(:db);
use MT::Test::Permission;
my $app = MT->instance;

my $blog_id = 1;

filters {
    template => [qw( chomp )],
    expected => [qw( chomp )],
    error    => [qw( chomp )],
};

my $mt = MT->instance;

my $ct = MT::Test::Permission->make_content_type(
    name    => 'test content data',
    blog_id => $blog_id,
);
my $cd1 = MT::Test::Permission->make_content_data(
    blog_id         => $blog_id,
    content_type_id => $ct->id,
    unpublished_on => '20170530190100',
);
my $cd2 = MT::Test::Permission->make_content_data(
    blog_id => $blog_id,
    content_type_id => $ct->id,
    unpublished_on => undef,
);

MT::Test::Tag->run_perl_tests($blog_id);
# MT::Test::Tag->run_php_tests($blog_id);

__END__

=== MT::ContentUnpublishedDate
--- template
<mt:Contents blog_id="1" name="test content data"><mt:ContentUnpublishedDate></mt:Contents>
--- expected
May 30, 2017  7:01 PM

=== MT::ContentUnpublishedDate with language="ja"
--- template
<mt:Contents blog_id="1" name="test content data"><mt:ContentUnpublishedDate language="ja"></mt:Contents>
--- expected
2017年5月30日 19:01

