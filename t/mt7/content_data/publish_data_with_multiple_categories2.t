# MTC-27944

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";    # t/lib
use Test::More;
use MT::Test::Env;
our $test_env;

BEGIN {
    $test_env = MT::Test::Env->new;
    $ENV{MT_CONFIG} = $test_env->config_file;
}

use MT::Test;
use MT::Test::Fixture;
use MT::Test::App;
use MT::ContentStatus;
use File::Spec;

$test_env->prepare_fixture('db');

my $site_path    = File::Spec->catdir($test_env->root, 'site');
my $archive_path = File::Spec->catdir($test_env->root, 'site/archive');

mkdir $site_path;
mkdir $archive_path;

my $objs = MT::Test::Fixture->prepare({
    author => [qw/author/],
    blog   => [{
        name         => 'my_blog',
        theme_id     => 'mont-blanc',
        site_path    => $site_path,
        archive_path => $archive_path,
    }],
    category_set => {
        my_category_set => [qw/aaa bbb ccc ddd eee/],
    },
    content_type => {
        ct => [
            cf_title          => 'single_line_text',
            cf_text           => 'multi_line_text',
            my_category_set_a => {
                type         => 'categories',
                category_set => 'my_category_set',
            },
            my_category_set_b => {
                type         => 'categories',
                category_set => 'my_category_set',
            },
            my_category_set_c => {
                type         => 'categories',
                category_set => 'my_category_set',
            },
        ],
    },
    content_data => {
        first_cd => {
            content_type => 'ct',
            author       => 'author',
            authored_on  => '20200202000000',
            label        => 'first_cd',
            status       => 'draft',
            data         => {
                cf_title          => 'title',
                cf_text           => 'body',
                my_category_set_a => [qw/ccc/],
                my_category_set_b => [qw/ddd/],
                my_category_set_c => [qw/eee/],
            },
        },
    },
    template => [{
            archive_type => 'ContentType',
            name         => 'tmpl_ct',
            content_type => 'ct',
            text         => 'test',
            mapping      => [{
                    file_template => '%-c/%-f',
                    cat_field     => 'my_category_set_b',
                    is_preferred  => 1,
                },
            ],
        },
    ],
});

my $admin = MT::Author->load(1);
my $blog  = $objs->{blog}{my_blog};
my $ct    = $objs->{content_type}{ct}{content_type};
my $cd    = $objs->{content_data}{first_cd};

sub get_files {
    my @files;
    $test_env->ls(
        $archive_path,
        sub {
            my $file = shift;
            return unless -f $file;
            my $path = File::Spec->abs2rel($file, $archive_path);
            $path =~ s|\\|/|g if $^O eq 'MSWin32';
            push @files, $path;
        });
    @files;
}

subtest 'archive_file' => sub {
    my $path = $objs->{content_data}{first_cd}->permalink;
    like $path, qr{^/nana/archives/ddd/}, 'right path';
};

subtest 'publish' => sub {
    my @files = get_files();
    ok !@files, "no files";
    note explain \@files if @files;

    my $app = MT::Test::App->new('MT::App::CMS');
    $app->login($admin);

    $app->get_ok({
        __mode          => 'view',
        _type           => 'content_data',
        blog_id         => $blog->id,
        content_type_id => $ct->id,
        id              => $cd->id,
    });
    my $res = $app->post_form_ok({ status => MT::ContentStatus::RELEASE(), });
    # note explain $res;

    @files = get_files();
    is(@files, 1, 'right number of files generated');
    like($files[0], qr{^ddd/}, 'right path');
};

done_testing;
