# Movable Type (r) (C) 2001-2017 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::ArchiveType::ContentTypeCategoryDaily;

use strict;
use base
    qw( MT::ArchiveType::ContentTypeCategory MT::ArchiveType::ContentTypeDaily MT::ArchiveType::CategoryDaily );

use MT::Util qw( dirify start_end_day );

sub name {
    return 'ContentType-Category-Daily';
}

sub archive_label {
    return MT->translate("CONTENTTYPE-CATEGORY-DAILY_ADV");
}

sub dynamic_template {
    return 'category/<$MTCategoryID$>/<$MTArchiveDate format="%Y%m%d"$>';
}

sub default_archive_templates {
    return [
        {   label           => 'category/sub-category/yyyy/mm/dd/index.html',
            template        => '%-c/%y/%m/%d/%i',
            default         => 1,
            required_fields => { category => 1, date_and_time => 1 }
        },
        {   label           => 'category/sub_category/yyyy/mm/dd/index.html',
            template        => '%c/%y/%m/%d/%i',
            required_fields => { category => 1, date_and_time => 1 }
        },
    ];
}

sub template_params {
    return {
        archive_class                => "contenttype-category-daily-archive",
        category_daily_archive       => 1,
        archive_template             => 1,
        archive_listing              => 1,
        datebased_archive            => 1,
        category_based_archive       => 1,
        contenttype_archive_lisrting => 1,
    };
}

sub archive_file {
    my $archiver = shift;
    my ( $ctx, %param ) = @_;
    my $timestamp    = $param{Timestamp};
    my $file_tmpl    = $param{Template};
    my $blog         = $ctx->{__stash}{blog};
    my $cat          = $ctx->{__stash}{cat} || $ctx->{__stash}{category};
    my $content_data = $ctx->{__stash}{content};
    my $file;

    my $this_cat = $archiver->_get_this_cat( $cat, $content_data );

    if ($file_tmpl) {
        ( $ctx->{current_timestamp}, $ctx->{current_timestamp_end} )
            = start_end_day( $timestamp, $blog );
        $ctx->stash( 'archive_category', $this_cat );
        $ctx->{inside_mt_categories} = 1;
        $ctx->{__stash}{category} = $this_cat;
    }
    else {
        if ( !$this_cat ) {
            return "";
        }
        my $label = '';
        $label = dirify( $this_cat->label );
        if ( $label !~ /\w/ ) {
            $label = $this_cat ? "cat" . $this_cat->id : "";
        }
        my $start = start_end_day( $timestamp, $blog );
        my ( $year, $month, $day ) = unpack 'A4A2A2', $start;
        $file = sprintf( "%s/%04d/%02d/%02d/index",
            $this_cat->category_path, $year, $month, $day );
    }
    $file;
}

sub archive_group_iter {
    my $obj = shift;
    my ( $ctx, $args ) = @_;
    my $blog = $ctx->stash('blog');
    my $sort_order
        = ( $args->{sort_order} || '' ) eq 'ascend' ? 'ascend' : 'descend';
    my $cat_order = $args->{sort_order} ? $args->{sort_order} : 'ascend';
    my $order = ( $sort_order eq 'ascend' ) ? 'asc'                 : 'desc';
    my $limit = exists $args->{lastn}       ? delete $args->{lastn} : undef;
    my $tmpl  = $ctx->stash('template');
    my $cat   = $ctx->stash('archive_category') || $ctx->stash('category');
    my @data  = ();
    my $count = 0;
    my $ts    = $ctx->{current_timestamp};
    my $tsend = $ctx->{current_timestamp_end};

    my $map          = $ctx->stash('template_map');
    my $cat_field_id = defined $map && $map ? $map->cat_field_id : '';
    my $dt_field_id  = defined $map && $map ? $map->dt_field_id : '';
    require MT::ContentData;
    require MT::ContentFieldIndex;
    my $loop_sub = sub {
        my $c          = shift;
        my $cd_iter = MT::ContentData->count_group_by(
            {   blog_id => $blog->id,
                status  => MT::Entry::RELEASE(),
                #( $ts && $tsend ? ( authored_on => [ $ts, $tsend ] ) : () ),
            },
            {   group => [
                    "extract(year from dt_cf_idx.cf_idx_value_datetime) AS year",
                    "extract(month from dt_cf_idx.cf_idx_value_datetime) AS month",
                    "extract(day from dt_cf_idx.cf_idx_value_datetime) as day"
                ],
                sort => [
                    {   column => "extract(year from dt_cf_idx.cf_idx_value_datetime)",
                        desc   => $order
                    },
                    {   column => "extract(month from dt_cf_idx.cf_idx_value_datetime)",
                        desc   => $order
                    },
                    {   column => "extract(day from dt_cf_idx.cf_idx_value_datetime)",
                        desc   => $order
                    },
                ],
                'joins'     => [
                    MT::ContentFieldIndex->join_on(
                        'content_data_id',
                        {   content_field_id => $dt_field_id,
                            ( $ts && $tsend ? ( value_datetime   => { op => '>=', value => $ts },
                            value_datetime   => { op => '<=', value => $tsend } ) : () ),
                        },
                        { alias => 'dt_cf_idx' }
                    ),
                    MT::ContentFieldIndex->join_on(
                        'content_data_id',
                        {   content_field_id => $cat_field_id,
                            value_integer    => $c->id
                        },
                        { alias => 'cat_cf_idx' }
                    )
                ],
            }
        ) or return $ctx->error("Couldn't get yearly archive list");
        while ( my @row = $cd_iter->() ) {
            my $hash = {
                year     => $row[1],
                month    => $row[2],
                day      => $row[3],
                category => $c,
                count    => $row[0],
            };
            push( @data, $hash );
            return $count + 1
                if ( defined($limit) && ( $count + 1 ) == $limit );
            $count++;
        }
    };

    if ($cat) {
        $loop_sub->($cat);
    }
    else {
        require MT::Category;
        my $iter = MT::Category->load_iter( { blog_id => $blog->id },
            { 'sort' => 'label', direction => $cat_order } );
        while ( my $category = $iter->() ) {
            $loop_sub->($category);
            last if ( defined($limit) && $count == $limit );
        }
    }

    my $loop = @data;
    my $curr = 0;

    return sub {
        if ( $curr < $loop ) {
            my $date = sprintf(
                "%04d%02d%02d000000",
                $data[$curr]->{year},
                $data[$curr]->{month},
                $data[$curr]->{day}
            );
            my ( $start, $end ) = start_end_day($date);
            my $count = $data[$curr]->{count};
            my %hash  = (
                category => $data[$curr]->{category},
                year     => $data[$curr]->{year},
                month    => $data[$curr]->{month},
                day      => $data[$curr]->{day},
                start    => $start,
                end      => $end,
            );
            $curr++;
            return ( $count, %hash );
        }
        undef;
        }
}

sub archive_group_contents{
    my $obj = shift;
    my ( $ctx, %param ) = @_;
    my $ts
        = $param{year}
        ? sprintf( "%04d%02d%02d000000",
        $param{year}, $param{month}, $param{day} )
        : $ctx->stash('current_timestamp');
    my $cat = $param{category} || $ctx->stash('archive_category');
    my $limit = $param{limit};
    $obj->dated_category_contents( $ctx, 'Category-Daily', $cat, $ts, $limit );
}

*date_range    = \&MT::ArchiveType::Daily::date_range;
*archive_title = \&MT::ArchiveType::CategoryDaily::archive_title;

1;
