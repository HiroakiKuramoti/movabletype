package MT::Theme::Common;
use strict;
use warnings;
use base 'Exporter';

use MT;

our @EXPORT_OK = qw( add_categories get_author_id );

sub add_categories {
    my ( $theme, $blog, $cat_data, $class, $category_set_id, $parent ) = @_;

    my $author_id = get_author_id($blog);
    unless ( defined $author_id ) {
        my $error;
        if ( $class eq 'folder' ) {
            $error = 'Failed to create theme default folders';
        }
        else {
            $error = 'Failed to create theme default categories';
        }
        die MT->translate($error);
    }

    for my $basename ( keys %$cat_data ) {
        my $datum = $cat_data->{$basename};
        my $cat   = MT->model($class)->load(
            {   blog_id  => $blog->id,
                basename => $basename,
                parent   => $parent ? $parent->id : 0,
                $category_set_id
                ? ( category_set_id => $category_set_id )
                : (),
            }
        );
        unless ($cat) {
            $cat = MT->model($class)->new;
            $cat->blog_id( $blog->id );
            $cat->category_set_id($category_set_id) if $category_set_id;
            $cat->basename($basename);
            for my $key (qw{ label description }) {
                my $val = $datum->{$key};
                if ( ref $val eq 'CODE' ) {
                    $val = $val->();
                }
                else {
                    $val = $theme->translate($val) if $val;
                }
                $cat->$key($val);
            }
            $cat->allow_pings( $datum->{allow_pings} || 0 );
            $cat->author_id($author_id);
            $cat->parent( $parent->id )
                if defined $parent;
            $cat->save;
        }
        if ( my $children = $datum->{children} ) {
            add_categories( $theme, $blog, $children, $class,
                $category_set_id, $cat );
        }
    }
    1;
}

sub get_author_id {
    my ($blog) = @_;
    my $author_id;

    if ( my $app = MT->instance ) {
        if ( $app->isa('MT::App') ) {
            my $author = $app->user;
            $author_id = $author->id if defined $author;
        }
    }
    unless ( defined $author_id ) {

        # Fallback 1: created_by from this blog.
        $author_id = $blog->created_by if defined $blog->created_by;
    }
    unless ( defined $author_id ) {

        # Fallback 2: One of this blog's administrator
        my $search_string
            = $blog->is_blog
            ? '%\'administer_blog\'%'
            : '%\'administer_website\'%';
        my $perm = MT->model('permission')->load(
            {   blog_id     => $blog->id,
                permissions => { like => $search_string },
            }
        );
        $author_id = $perm->author_id if $perm;
    }
    unless ( defined $author_id ) {

        # Fallback 3: One of system administrator
        my $perm = MT->model('permission')->load(
            {   blog_id     => 0,
                permissions => { like => '%administer%' },
            }
        );
        $author_id = $perm->author_id if $perm;
    }

    $author_id;
}

1;
