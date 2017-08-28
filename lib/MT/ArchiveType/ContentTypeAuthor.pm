# Movable Type (r) (C) 2001-2017 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::ArchiveType::ContentTypeAuthor;

use strict;
use base qw( MT::ArchiveType::Author );

use MT::Util qw( remove_html encode_html );

sub name {
    return 'ContentType-Author';
}

sub archive_label {
    return MT->translate("CONTENTTYPE-AUTHOR_ADV");
}

sub dynamic_template {
    return 'author/<$MTContentAuthorID$>/<$MTContentID$>';
}

sub default_archive_templates {
    return [
        {   label    => 'author/author-basename/index.html',
            template => 'author/%-a/%f',
            default  => 1
        },
        {   label    => 'author/author_basename/index.html',
            template => 'author/%a/%f'
        },
    ];
}

sub template_params {
    return { archive_class => "contenttype-author-archive" };
}

sub archive_group_iter {
    my $obj = shift;
    my ( $ctx, $args ) = @_;
    my $blog = $ctx->stash('blog');
    my $sort_order
        = ( $args->{sort_order} || '' ) eq 'ascend' ? 'ascend' : 'descend';
    my $auth_order = $args->{sort_order} ? $args->{sort_order} : 'ascend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc' : 'desc';
    my $limit = exists $args->{lastn} ? delete $args->{lastn} : undef;
    require MT::ContentData;
    require MT::Author;
    my $auth_iter = MT::Author->load_iter(
        undef,
        {   sort      => 'name',
            direction => $auth_order,
            join      => [
                'MT::ContentData', 'author_id',
                { status => MT::Entry::RELEASE(), blog_id => $blog->id },
                { unique => 1 }
            ]
        }
    );
    my $i = 0;
    return sub {

        while ( my $a = $auth_iter->() ) {
            last if defined($limit) && $i == $limit;
            my $count = MT::ContentData->count(
                {   blog_id   => $blog->id,
                    status    => MT::Entry::RELEASE(),
                    author_id => $a->id
                }
            );
            next if $count == 0 && !$args->{show_empty};
            $i++;
            return ( $count, author => $a );
        }
        undef;
    };
}

sub archive_contents_count {
    my $obj = shift;
    my ( $blog, $at, $content_data ) = @_;
    return $obj->SUPER::archive_contents_count(
        {   Blog        => $blog,
            ArchiveType => $at,
        }
    ) unless $content_data;
    my $auth = $content_data->author;
    return $obj->SUPER::archive_contents_count(
        {   Blog        => $blog,
            ArchiveType => $at,
            Author      => $auth,
        }
    );
}

sub archive_group_contents {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $blog  = $ctx->stash('blog');
    my $a     = $param{author} || $ctx->stash('author');
    my $limit = $param{limit};
    if ( $limit && ( $limit eq 'auto' ) ) {
        my $blog = $ctx->stash('blog');
        $limit = $blog->entries_on_index if $blog;
    }
    return [] unless $a;
    require MT::ContentData;
    my @contents = MT::ContentData->load(
        {   blog_id   => $blog->id,
            author_id => $a->id,
            status    => MT::Entry::RELEASE()
        },
        {   'sort'      => 'authored_on',
            'direction' => 'descend',
            ( $limit ? ( 'limit' => $limit ) : () ),
        }
    );
    \@contents;
}

sub does_publish_file {
    my $obj    = shift;
    my %params = %{ shift() };

    if ( !$params{Author} && $params{ContentData} ) {
        $params{Author} = $params{ContentData}->author;
    }
    return 0 unless $params{Author};

    MT::ArchiveType::archive_contents_count( $obj, \%params );
}

sub get_content {
    my ( $archiver, $ctx ) = @_;
    return $ctx->{__stash}{content};
}

sub contenttype_group_based {
    return 1;
}

1;

