use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";    # t/lib
use Test::More;
use MT::Test::Env;
BEGIN {
    eval { require Test::MockModule }
        or plan skip_all => 'Test::MockModule is not installed';
}

our $test_env;
BEGIN {
    $test_env = MT::Test::Env->new;
    $ENV{MT_CONFIG} = $test_env->config_file;
}
$test_env->prepare_fixture('db');

use MT::Test;

my $app  = MT->instance;
my $blog = MT::Website->load(1);

use MT::Stats qw(readied_provider);

my $ga_provider_mock = Test::MockModule->new('GoogleAnalytics::Provider');
$ga_provider_mock->mock('is_ready', sub { 1 });
my $ga4_provider_mock = Test::MockModule->new('GoogleAnalyticsV4::Provider');
$ga4_provider_mock->mock('is_ready', sub { 1 });

my $provider;
subtest 'test DefaultStatsProvider' => sub {
    $provider = readied_provider($app, $blog);
    ok $provider->id eq 'GoogleAnalyticsV4';

    $app->config('DefaultStatsProvider', 'GoogleAnalytics');

    $provider = readied_provider($app, $blog);
    ok $provider->id eq 'GoogleAnalytics';

};

subtest 'test provider attribute' => sub {
    $provider = readied_provider($app, $blog, 'GoogleAnalyticsV4');
    ok $provider->id eq 'GoogleAnalyticsV4';

    $provider = readied_provider($app, $blog, 'GoogleAnalytics');
    ok $provider->id eq 'GoogleAnalytics';

};

done_testing;
