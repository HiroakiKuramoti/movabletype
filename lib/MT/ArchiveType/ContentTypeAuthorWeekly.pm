# Movable Type (r) (C) 2001-2017 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::ArchiveType::ContentTypeAuthorWeekly;

use strict;
use base
    qw( MT::ArchiveType::ContentTypeAuthor MT::ArchiveType::ContentTypeWeekly MT::ArchiveType::AuthorWeekly );

use MT::Util qw( start_end_week week2ymd );

sub name {
    return 'ContentType-Author-Weekly';
}

sub archive_label {
    return MT->translate("CONTENTTYPE-AUTHOR-WEEKLY_ADV");
}

sub dynamic_template {
    return
        'author/<$MTContentAuthorID$>/week/<$MTArchiveDate format="%Y%m%d"$>';
}

sub default_archive_templates {
    return [
        {   label    => 'author/author-basename/yyyy/mm/day-week/index.html',
            template => 'author/%-a/%y/%m/%d-week/%f',
            default  => 1,
            required_fields => { date_and_time => 1 }
        },
        {   label    => 'author/author_basename/yyyy/mm/day-week/index.html',
            template => 'author/%a/%y/%m/%d-week/%f',
            required_fields => { date_and_time => 1 }
        },
    ];
}

sub template_params {
    return {
        archive_class                => "contenttype-author-weekly-archive",
        author_weekly_archive        => 1,
        archive_template             => 1,
        archive_listing              => 1,
        author_based_archive         => 1,
        datebased_archive            => 1,
        contenttype_archive_lisrting => 1,
        },
        ;
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

    my $tmpl  = $ctx->stash('template');
    my @data  = ();
    my $count = 0;

    my $ts    = $ctx->{current_timestamp};
    my $tsend = $ctx->{current_timestamp_end};

    my $author = $ctx->stash('author');

    my $map = $ctx->stash('template_map');
    my $dt_field_id = defined $map && $map ? $map->dt_field_id : '';
    require MT::ContentData;
    require MT::ContentFieldIndex;

    my $loop_sub = sub {
        my $auth       = shift;
        my $count_iter = MT::ContentData->count_group_by(
            {   blog_id   => $blog->id,
                author_id => $auth->id,
                status    => MT::Entry::RELEASE(),
                (         !$dt_field_id
                        && $ts
                        && $tsend ? ( authored_on => [ $ts, $tsend ] ) : ()
                ),
            },
            {   (   !$dt_field_id && $ts && $tsend
                    ? ( range_incl => { authored_on => 1 } )
                    : ()
                ),
                group => [
                    (   !$dt_field_id
                        ? "week_number"
                        : "cf_idx_value_integer"
                    )
                ],
                sort => [
                    {   column => (
                            !$dt_field_id
                            ? "week_number"
                            : "cf_idx_value_integer"
                        ),
                        desc => $order
                    }
                ],
                (   $dt_field_id
                    ? ( join => MT::ContentFieldIndex->join_on(
                            'content_data_id',
                            {   content_field_id => $dt_field_id,
                                (   $ts && $tsend
                                    ? ( value_datetime =>
                                            { op => '>=', value => $ts },
                                        value_datetime =>
                                            { op => '<=', value => $tsend }
                                        )
                                    : ()
                                ),
                            },
                            { alias => 'dt_cf_idx' }
                        )
                        )
                    : ()
                )
            }
        ) or return $ctx->error("Couldn't get weekly archive list");

        while ( my @row = $count_iter->() ) {
            my ( $year, $week ) = unpack 'A4A2', $row[1];
            my $hash = {
                year   => $year,
                week   => $week,
                author => $auth,
                count  => $row[0],
            };
            push( @data, $hash );
            return $count + 1
                if ( defined($limit) && ( $count + 1 ) == $limit );
            $count++;
        }
        return $count;
    };

    # Count content data by author
    if ($author) {
        $loop_sub->($author);
    }
    else {

        # load authors
        require MT::Author;
        my $iter;
        $iter = MT::Author->load_iter(
            undef,
            {   sort      => 'name',
                direction => $auth_order,
                join      => [
                    'MT::Entry',
                    'author_id',
                    { status => MT::Entry::RELEASE(), blog_id => $blog->id },
                    { unique => 1 }
                ]
            }
        );

        while ( my $a = $iter->() ) {
            $loop_sub->($a);
            last if ( defined($limit) && $count == $limit );
        }
    }

    my $loop = @data;
    my $curr = 0;

    return sub {
        if ( $curr < $loop ) {
            my $date = sprintf( "%04d%02d%02d000000",
                week2ymd( $data[$curr]->{year}, $data[$curr]->{week} ) );
            my ( $start, $end ) = start_end_week($date);
            my $count = $data[$curr]->{count};
            my %hash  = (
                author => $data[$curr]->{author},
                year   => $data[$curr]->{year},
                week   => $data[$curr]->{week},
                start  => $start,
                end    => $end
            );
            $curr++;
            return ( $count, %hash );
        }
        undef;
        }
}

sub archive_group_contents {
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $ts
        = $param{year}
        ? sprintf( "%04d%02d%02d000000",
        week2ymd( $param{year}, $param{week} ) )
        : $ctx->stash('current_timestamp');
    my $author = $param{author} || $ctx->stash('author');
    my $limit = $param{limit};
    $obj->dated_author_contents( $ctx, 'Author-Weekly', $author, $ts,
        $limit );
}

*date_range    = \&MT::ArchiveType::Weekly::date_range;
*archive_file  = \&MT::ArchiveType::AuthorWeekly::archive_file;
*archive_title = \&MT::ArchiveType::AuthorWeekly::archive_title;

1;
