#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";    # t/lib
use Test::More;
use MT::Test::Env;

our $test_env;
BEGIN {
    $test_env = MT::Test::Env->new(
        PluginPath => [qw(
            MT_HOME/plugins
            TEST_ROOT/plugins
        )]
    );
    $ENV{MT_CONFIG} = $test_env->config_file;

    my $config_yaml = 'plugins/CallbackTest/config.yaml';
    $test_env->save_file( $config_yaml, <<'YAML' );
name: CallbackTest
id: CallbackTest

applications:
  cms:
    methods:
      save_config_test:
        requires_login: 0
        code: |
          sub {
            my ($app) = @_;
            my $cfg = $app->model('config')->load;
            $cfg->save;
            $app->{no_print_body} = 1;
            $app->send_http_header('text/plain');
            $app->print_encode('Save Config OK');
          }
  data_api:
    endpoints:
      - id: save_config_test
        route: /save_config_test
        version: 4
        requires_login: 0
        handler: |
          sub {
            my ($app) = @_;
            my $cfg = $app->model('config')->load;
            $cfg->save;
            +{
              message => 'Save Config OK',
            }
          }
YAML
}

use MT::Test;
use MT;
use MT::Theme;
use Mock::MonkeyPatch;

MT::Test->init_app;
$test_env->prepare_fixture('db');

my $admin = MT->model('author')->load(1);
my $site  = MT->model('blog')->load(1);
MT::Theme->load('classic_blog')->apply($site);
my $index_template = MT->model('template')->load({
    blog_id => 1,
    type    => 'index',
});
$site->site_path(File::Spec->catdir($test_env->root, 'site'));
$site->save;

my %reboot_counter = ();
my %touch_counter  = ();

my $reboot_guard = Mock::MonkeyPatch->patch(
    'MT::App::do_reboot' => sub {
        my $app = shift;
        $reboot_counter{ ref $app }++ if $app->{do_reboot};
        delete $app->{do_reboot};
    });
my $touch_guard = Mock::MonkeyPatch->patch(
    'MT::App::touch_blogs' => sub {
        my $app = shift;
        $touch_counter{ ref $app }++;
    },
);

sub reset_counter {
    %reboot_counter = ();
    %touch_counter  = ();
}

subtest 'save_config in MT::App::CMS' => sub {
    reset_counter();

    my $app = _run_app(
        'MT::App::CMS',
        { __mode => 'save_config_test' });

    like $app->{__test_output}, qr/Status: 200/;
    like $app->{__test_output}, qr/Save Config OK/;
    is_deeply \%reboot_counter, { 'MT::App::CMS' => 1 };
};

subtest 'save_config in MT::App::DataAPI' => sub {
    reset_counter();

    my $app = _run_app(
        'MT::App::DataAPI',
        {
            __path_info      => '/v4/save_config_test',
            __request_method => 'GET',
        });

    like $app->{__test_output}, qr/Status: 200/;
    like $app->{__test_output}, qr/Save Config OK/;
    is_deeply \%reboot_counter, { 'MT::App::DataAPI' => 1 };
};

subtest 'pre_build in MT::App::CMS' => sub {
    reset_counter();

    my $app = _run_app(
        'MT::App::CMS',
        {
            __test_user => $admin,
            __mode      => 'rebuild',
            blog_id     => $site->id,
            type        => 'index',
            start_time  => time,
        });

    like $app->{__test_output}, qr/Status: 200/;
    is_deeply \%touch_counter, { 'MT::App::CMS' => 1 };
};

subtest 'pre_build in MT::App::DataAPI' => sub {
    reset_counter();

    my $authenticate_guard = Mock::MonkeyPatch->patch('MT::App::DataAPI::authenticate' => sub { $admin });

    my $app = _run_app(
        'MT::App::DataAPI',
        {
            __path_info      => "/v4/sites/@{[$site->id]}/templates/@{[$index_template->id]}/publish",
            __request_method => 'POST',
        });

    like $app->{__test_output}, qr/Status: 200/;
    is_deeply \%touch_counter, { 'MT::App::DataAPI' => 1 };
};

done_testing;
