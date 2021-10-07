use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";    # t/lib
use Test::More;
use MT::Test::Env;
our $test_env;

BEGIN {
    $test_env = MT::Test::Env->new;
    $ENV{MT_CONFIG} = $test_env->config_file;
}

use MT::Test::Tag;

$test_env->prepare_fixture('db');

MT::Test::Tag->run_perl_tests(1);
MT::Test::Tag->run_php_tests(1);

done_testing;

__DATA__

=== test 1
--- template
<mt:PasswordValidation form="password_reset_form" password="mypassfield" username="myusernamefield">
--- expected regexp=s
function verify_password.+mypassfield.+myusernamefield
