#!/usr/bin/perl

use strict;
use warnings;

use lib qw(lib t/lib);

use MT::Test::Tag;

# plan tests => 2 * blocks;
plan tests => 1 * blocks;

use MT;
use MT::Test qw(:db);
use MT::Test::Permission;
my $app = MT->instance;

my $blog_id = 1;

my $uid;

sub uid {
    $uid;
}

filters {
    template => [qw( chomp )],
    expected => [qw( uid chomp )],
};

my $mt = MT->instance;

my $ct = MT::Test::Permission->make_content_type(
    name    => 'test content data',
    blog_id => $blog_id,
);
my $cd = MT::Test::Permission->make_content_data(
    blog_id         => $blog_id,
    content_type_id => $ct->id,
);
$uid = $cd->unique_id;

MT::Test::Tag->run_perl_tests($blog_id);
# MT::Test::Tag->run_php_tests($blog_id);

__END__

=== MT::ContentUniqueID
--- template
<mt:Contents blog_id="1" name="test content data"><mt:ContentUniqueID> </mt:Contents>
--- expected
__dummy__

