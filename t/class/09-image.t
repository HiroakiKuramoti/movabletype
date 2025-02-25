#!/usr/bin/perl -w
# $Id: 09-image.t 2713 2008-07-04 05:01:40Z bchoate $

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
use File::Spec;

use MT::Image;
use MT::ConfigMgr;
use MT;
use MT::Test::Image;
use File::Copy;

my $TESTS_FOR_EACH = 30;

my @Img = (
    [ 'test.gif', 400, 300 ],
    [ 'test.jpg', 640, 480 ],
    [ 'test.png', 150, 150 ],
    [ 'test.bmp', 600, 450 ],
);
my @drivers = $test_env->image_drivers;

MT->set_language('en-us');

my $File   = "test.file";
my $String = "testing";
my $cfg    = MT::ConfigMgr->instance;
my $tested = 0;
for my $rec (@Img) {
    my ( $img_filename, $img_width, $img_height ) = @$rec;
    my ($ext) = $img_filename =~ /\.(gif|jpg|png|bmp)$/;
    my ( $guard, $img_file ) = MT::Test::Image->tempfile(
        DIR    => $test_env->root,
        SUFFIX => ".$ext",
    );
    close $guard;

    ok( -B $img_file, "$img_file looks like a binary file" );

    ( my $img_file_with_unrecognized_ext = $img_file ) =~ s/\.//;
    File::Copy::copy $img_file => $img_file_with_unrecognized_ext;

    for my $driver (@drivers) {
        note("----Test $driver for file $img_file");
        $cfg->ImageDriver($driver);
        MT::Image->error('');
        my $img = MT::Image->new( Filename => $img_file );
        note( MT::Image->errstr ) if MT::Image->errstr;
    SKIP: {
            skip( "no $driver for image $img_file", $TESTS_FOR_EACH )
                unless $img;
            $tested++;
            isa_ok( $img, 'MT::Image::' . $driver, "driver for $img_file" );
            ok( eval 'MT::Image::' . $driver . '->load_driver()',
                'Also can load driver via class method'
            );
            $img->_init_image_size;
            is( $img->{width}, $img_width,
                "$driver says $img_filename is $img_width px wide" );
            is( $img->{height}, $img_height,
                "$driver says $img_filename is $img_height px high" );
            my ( $w, $h ) = $img->get_dimensions();
            is( $w, $img_width,
                "${driver}'s get_dimensions says $img_filename is $img_width px wide"
            );
            is( $h, $img_height,
                "${driver}'s get_dimensions says $img_filename is $img_height px high"
            );

            ( $w, $h ) = $img->get_dimensions( Scale => 50 );
            my ( $x, $y ) = ( int( $img_width / 2 ), int( $img_height / 2 ) );
            is( $w, $x,
                "$driver says $img_filename at 50\% scale is $x px wide" );
            is( $h, $y,
                "$driver says $img_filename at 50\% scale is $y px high" );

            ( $w, $h ) = $img->get_dimensions();
            is( $w, $img_width,
                "${driver}'s get_dimensions says $img_filename is still $img_width px wide after theoretical scaling"
            );
            is( $h, $img_height,
                "${driver}'s get_dimensions says $img_filename is still $img_height px high after theoretical scaling"
            );

            ( $w, $h ) = $img->get_dimensions( Width => 50 );
            is( $w, 50,
                "$driver says $img_filename scaled to 50 px wide is 50 px wide"
            );

            ( $w, $h ) = $img->get_dimensions( Width => 50, Height => 100 );
            is( $w, 50,
                "$driver says $img_filename scaled to 50x100 is 50 px wide" );
            is( $h, 100,
                "$driver says $img_filename scaled to 50x100 is 100 px high"
            );

            my $blob;
            ( $blob, $w, $h ) = $img->scale( Scale => 50 );
            ok( $blob, "do scale" );
            ( $x, $y ) = ( int( $img_width / 2 ), int( $img_height / 2 ) );
            is( $w, $x,
                "result of scaling $img_filename to 50\% with $driver is $x px wide"
            );
            is( $h, $y,
                "result of scaling $img_filename to 50\% with $driver is $y px high"
            );

            undef $blob;
            ( $blob, $w, $h ) = $img->crop( Size => 50, X => 10, Y => 10 )
                or die $img->errstr;

            ok( $blob, "do crop" );

            ( $x, $y ) = ( 50, 50 );
            is( $w, $x,
                "result of cropping $img_filename to 50x50 with $driver is $x px wide"
            );
            is( $h, $y,
                "result of cropping $img_filename to 50x50 with $driver is $y px high"
            );

            undef $blob;
            ( $blob, $w, $h ) = $img->crop_rectangle(
                Width  => 20,
                Height => 30,
                X      => 10,
                Y      => 10
            ) or die $img->errstr;

            ok( $blob, "do crop_rectangle" );

            ( $x, $y ) = ( 20, 30 );
            is( $w, $x,
                "result of cropping $img_filename to 20x30 with $driver is $x px wide"
            );
            is( $h, $y,
                "result of cropping $img_filename to 20x30 with $driver is $y px high"
            );

            ( my $type = $img_file ) =~ s/.*\.//;
            for my $to (qw( JPG PNG GIF BMP )) {
                next if lc $to eq lc $type;
                if ($to eq 'BMP' && $driver =~ /GD|NetPBM/) {
                    skip "$driver does not fully support BMP", 1;
                    next;
                }
                my $blob = $img->convert( Type => $to );
                ok( $blob, "convert $img_filename to $to with $driver" );
            }

            open my $fh, '<', $img_file or die $!;
            binmode $fh;
            my $data = do { local $/; <$fh> };
            close $fh;
            $img = MT::Image->new( Data => $data, Type => $type );

            isa_ok( $img, 'MT::Image::' . $driver );
            note( MT::Image->errstr ) if MT::Image->errstr;
            $img->_init_image_size;
            is( $img->{width}, $img_width,
                "$driver says $img_filename from blob is $img_width px wide"
            );
            is( $img->{height}, $img_height,
                "$driver says $img_filename from blob is $img_height px high"
            );
            ( $w, $h ) = $img->get_dimensions;
            is( $w, $img_width,
                "${driver}'s get_dimensions says $img_filename from blob is $img_width px wide"
            );
            is( $h, $img_height,
                "${driver}'s get_dimensions says $img_filename from blob is $img_height px high"
            );

            SKIP: {
                skip "$driver does not support unrecognized_extension", 1 unless $driver =~ /Magick/;
                ok eval { my $img = MT::Image->new( Filename => $img_file_with_unrecognized_ext ) };
            }    # END SKIP
        }    # END SKIP
    }
}

ok( $tested > 0, 'At least one of image drivers should be tested' );

done_testing;
