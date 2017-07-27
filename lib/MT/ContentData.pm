# Movable Type (r) (C) 2006-2016 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::ContentData;

use strict;
use base qw( MT::Object MT::Revisable );

use JSON  ();
use POSIX ();

use MT;
use MT::Asset;
use MT::Author;
use MT::ContentData;
use MT::ContentField;
use MT::ContentFieldIndex;
use MT::ContentFieldType::Common
    qw( get_cd_ids_by_inner_join get_cd_ids_by_left_join );
use MT::ContentType;
use MT::ContentType::UniqueID;
use MT::ObjectAsset;
use MT::ObjectCategory;
use MT::ObjectTag;
use MT::Tag;
use MT::Util;

use constant TAG_CACHE_TIME => 7 * 24 * 60 * 60;    ## 1 week

__PACKAGE__->install_properties(
    {   column_defs => {
            'id'      => 'integer not null auto_increment',
            'blog_id' => 'integer not null',
            'title'   => {
                type       => 'string',
                size       => 255,
                label      => 'Title',
                revisioned => 1,
            },
            'status' => {
                type       => 'smallint',
                not_null   => 1,
                label      => 'Status',
                revisioned => 1,
            },
            'author_id' => {
                type       => 'integer',
                not_null   => 1,
                label      => 'Author',
                revisioned => 1,
            },
            'content_type_id' => 'integer not null',
            'unique_id'       => 'string(40) not null',
            'ct_unique_id'    => 'string(40) not null',
            'data'            => {
                type       => 'blob',
                label      => 'Data',
                revisioned => 1,
            },
            'identifier' => {
                type       => 'string',
                size       => 255,
                label      => 'Identifier',
                revisioned => 1,
            },
            'authored_on' => {
                type       => 'datetime',
                label      => 'Publish Date',
                revisioned => 1,
            },
            'unpublished_on' => {
                type       => 'datetime',
                label      => 'Unpublished Date',
                revisioned => 1,
            },
            'revision'       => 'integer meta',
            'convert_breaks' => 'string meta',
        },
        indexes => {
            content_type_id => 1,
            ct_unique_id    => 1,
            unique_id       => { unique => 1 },
        },
        defaults    => { status => 0 },
        datasource  => 'cd',
        primary_key => 'id',
        audit       => 1,
        meta        => 1,
        child_of    => ['MT::ContentType'],
    }
);

sub class_label {
    MT->translate("Content Data");
}

sub class_label_plural {
    MT->translate("Content Data");
}

sub to_hash {
    my $self = shift;
    my $hash = $self->SUPER::to_hash();
    $hash->{'cd.text_html'}
        = $self->_generate_text_html || $self->column('data');
    $hash;
}

sub _generate_text_html {
    my $self      = shift;
    my $data_hash = {};
    for my $field_id ( keys %{ $self->data } ) {
        my $field = MT::ContentField->load( $field_id || 0 );
        my $hash_key = $field ? $field->name : "field_id_${field_id}";
        $data_hash->{$hash_key} = $self->data->{$field_id};
    }
    eval { JSON::to_json( $data_hash, { canonical => 1, utf8 => 1 } ) };
}

sub unique_id {
    my $self = shift;
    $self->column('unique_id');
}

sub ct_unique_id {
    my $self = shift;
    $self->column('ct_unique_id');
}

sub save {
    my $self = shift;

    my $content_field_types = MT->registry('content_field_types');
    my $content_type        = $self->content_type
        or return $self->error( MT->translate('Invalid content type') );

    unless ( $self->id ) {
        my $unique_id
            = MT::ContentType::UniqueID::generate_unique_id( $self->title );
        $self->column( 'unique_id', $unique_id );

        $self->column( 'ct_unique_id', $content_type->unique_id );
    }

    ## If there's no identifier specified, create a unique identifier.
    if ( !defined( $self->identifier ) || ( $self->identifier eq '' ) ) {
        my $name = MT::Util::make_unique_basename($self);
        $self->identifier($name);
    }

    $self->SUPER::save(@_) or return;

    my $data = $self->data;

    foreach my $f ( @{ $content_type->fields } ) {
        my $idx_type  = $f->{type};
        my $data_type = $content_field_types->{$idx_type}{data_type};
        my $value     = $data->{ $f->{id} };
        $value = [$value] unless ref $value eq 'ARRAY';

        $value = [ grep { defined $_ && $_ ne '' } @$value ];

        if ( $idx_type eq 'asset' ) {
            $self->_update_object_assets( $content_type, $f, $value );
        }
        elsif ( $idx_type eq 'tag' ) {
            $self->_update_object_tags( $content_type, $f, $value );
        }
        elsif ( $idx_type eq 'categories' ) {
            $self->_update_object_categories( $content_type, $f, $value );
        }

        MT::ContentFieldIndex->remove(
            {   content_type_id  => $content_type->id,
                content_data_id  => $self->id,
                content_field_id => $f->{id},
            }
        );

        for my $v (@$value) {
            my $cf_idx = MT::ContentFieldIndex->new;
            $cf_idx->set_values(
                {   content_type_id  => $content_type->id,
                    content_data_id  => $self->id,
                    content_field_id => $f->{id},
                }
            );

            $cf_idx->set_value( $data_type, $v )
                or return $self->error(
                MT->translate(
                    'Saving content field index failed: Invalid field type "[_1]"',
                    $data_type
                )
                );

            $cf_idx->save
                or return $self->error(
                MT->translate(
                    "Saving content field index failed: [_1]",
                    $cf_idx->errstr
                )
                );
        }
    }

    1;
}

sub _update_object_assets {
    my $self = shift;
    my ( $content_type, $field_data, $values ) = @_;

    MT::ObjectAsset->remove(
        {   object_ds => 'content_field',
            object_id => $field_data->{id},
        }
    );

    for my $asset_id (@$values) {
        my $obj_asset = MT::ObjectAsset->new;
        $obj_asset->set_values(
            {   blog_id   => $self->blog_id,
                asset_id  => $asset_id,
                object_ds => 'content_field',
                object_id => $field_data->{id},
            }
        );
        $obj_asset->save or die $obj_asset->errstr;
    }
}

sub _update_object_tags {
    my $self = shift;
    my ( $content_type, $field_data, $values ) = @_;

    MT::ObjectTag->remove(
        {   blog_id           => $self->blog_id,
            object_datasource => 'content_field',
            object_id         => $field_data->{id},
        }
    );

    for my $tag_id (@$values) {
        my $obj_tag = MT::ObjectTag->new;
        $obj_tag->set_values(
            {   blog_id           => $self->blog_id,
                tag_id            => $tag_id,
                object_datasource => 'content_field',
                object_id         => $field_data->{id},
            }
        );
        $obj_tag->save or die $obj_tag->errstr;
    }
}

sub _update_object_categories {
    my $self = shift;
    my ( $content_type, $field_data, $values ) = @_;

    MT::ObjectCategory->remove(
        {   blog_id   => $self->blog_id,
            object_ds => 'content_field',
            object_id => $field_data->{id},
        }
    );

    my $is_primary = 1;
    for my $cat_id (@$values) {
        my $obj_cat = MT::ObjectCategory->new;
        $obj_cat->set_values(
            {   blog_id     => $self->blog_id,
                category_id => $cat_id,
                object_ds   => 'content_field',
                object_id   => $field_data->{id},
                is_primary  => $is_primary,
            }
        );
        $obj_cat->save or die $obj_cat->errstr;
        $is_primary = 0;
    }
}

sub data {
    my $obj = shift;
    if (@_) {
        my $json;
        if ( ref $_[0] ) {
            $json = eval { JSON::encode_json( $_[0] ) } || '{}';
        }
        else {
            $json = $_[0];
        }
        $obj->column( 'data', $json );
    }
    else {
        eval { JSON::decode_json( $obj->column('data') ) } || {};
    }
}

sub content_type {
    my $self = shift;
    $self->cache_property(
        'content_type',
        sub {
            MT::ContentType->load( $self->content_type_id || 0 );
        },
    );
}

sub blog {
    my ($ct_data) = @_;
    $ct_data->cache_property(
        'blog',
        sub {
            my $blog_id = $ct_data->blog_id;
            require MT::Blog;
            MT::Blog->load( $blog_id || 0 )
                or $ct_data->error(
                MT->translate(
                    "Loading blog '[_1]' failed: [_2]",
                    $blog_id,
                    MT::Blog->errstr
                        || MT->translate("record does not exist.")
                )
                );
        }
    );
}

sub author {
    my $self = shift;
    $self->cache_property(
        'author',
        sub {
            scalar MT::Author->load( $self->author_id || 0 );
        },
    );
}

sub terms_for_tags {
    return {};
}

sub get_tag_objects {
    my $obj = shift;
    $obj->__load_tags;
    return $obj->{__tag_objects};
}

sub __load_tags {
    my $obj = shift;
    my $t   = MT->get_timer;
    $t->pause_partial if $t;

    if ( !$obj->id ) {
        $obj->{__tags} = [];
        return $obj->{__tag_objects} = [];
    }
    return if exists $obj->{__tag_objects};

    require MT::Memcached;
    my $cache  = MT::Memcached->instance;
    my $memkey = $obj->tag_cache_key;
    my @tags;
    if ( my $tag_ids = $cache->get($memkey) ) {
        @tags = grep {defined} @{ MT::Tag->lookup_multi($tag_ids) };
    }
    else {
        my @field_ids;
        my $cf_iter
            = MT::ContentField->load_iter(
            { content_type_id => $obj->content_type_id },
            { fetchonly       => { id => 1 } } );
        while ( my $cf = $cf_iter->() ) {
            push @field_ids, $cf->id;
        }

        my $tag_iter = MT::Tag->load_iter(
            undef,
            {   sort => 'name',
                join => [
                    'MT::ObjectTag',
                    'tag_id',
                    {   blog_id           => $obj->blog_id,
                        object_id         => \@field_ids,
                        object_datasource => 'content_field',
                    },
                    { unique => 1 }
                ],
            }
        );
        while ( my $tag = $tag_iter->() ) {
            push @tags, $tag;
        }
        $cache->set( $memkey, [ map { $_->id } @tags ], TAG_CACHE_TIME );
    }
    $obj->{__tags} = [ map { $_->name } @tags ];
    $t->mark('MT::Tag::__load_tags') if $t;
    $obj->{__tag_objects} = \@tags;
}

sub tag_cache_key {
    my $obj = shift;
    return undef unless $obj->id;
    return sprintf "%stags-%d", $obj->datasource, $obj->id;
}

sub edit_link {
    my ( $self, $app ) = @_;
    $app->uri(
        mode => 'edit_content_data',
        args => {
            id              => $self->id,
            blog_id         => $self->blog_id,
            content_type_id => $self->content_type_id,
        },
    );
}

sub next {
    my $self = shift;
    my ($opt) = @_;
    my $terms;
    if ( ref $opt ) {
        $terms = $opt;
    }
    else {
        $terms = $opt ? { status => MT::Entry::RELEASE() } : {};
    }
    $self->_nextprev( 'next', $terms );
}

sub previous {
    my $self = shift;
    my ($opt) = @_;
    my $terms;
    if ( ref $opt ) {
        $terms = $opt;
    }
    else {
        $terms = $opt ? { status => MT::Entry::RELEASE() } : {};
    }
    $self->_nextprev( 'previous', $terms );
}

sub _nextprev {
    my $obj   = shift;
    my $class = ref($obj);
    my ( $direction, $terms ) = @_;
    return undef unless ( $direction eq 'next' || $direction eq 'previous' );
    my $next = $direction eq 'next';

    $terms->{author_id} = $obj->author_id if delete $terms->{by_author};

    my ( $content_field_id, $category_id );
    if ( my $by_category = delete $terms->{by_category} ) {
        if ( ref $by_category eq 'HASH' ) {
            $content_field_id = $by_category->{content_field_id};
            $category_id      = $by_category->{category_id};
        }
        $content_field_id ||= $obj->content_type->get_first_category_field_id
            or return undef;
        $category_id ||= ${ $obj->data->{$content_field_id} || [] }[0] || 0;
    }

    my $label = '__' . $direction;
    $label .= ':author=' . $terms->{author_id} if exists $terms->{author_id};
    $label
        .= ":content_field_id=${content_field_id}:category_id=${category_id}"
        if $content_field_id;
    $label .= ':by_modified_on' if $terms->{by_modified_on};
    return $obj->{$label} if $obj->{$label};

    my $args = {};

    if ($content_field_id) {
        my $join;
        if ($category_id) {
            $join = MT::ContentFieldIndex->join_on(
                'content_data_id',
                {   content_field_id => $content_field_id,
                    value_integer    => $category_id,
                },
                { unique => 1 }
            );
        }
        else {
            $join = MT::ContentFieldIndex->join_on(
                undef, undef,
                {   type      => 'left',
                    condition => {
                        content_data_id  => \'= cd_id',
                        content_field_id => $content_field_id,
                        value_integer    => \'IS NULL',
                    },
                    unique => 1,
                }
            );
        }
        $args->{join} = $join;
    }

    my $by = delete $terms->{by_modified_on} ? 'modified_on' : 'authored_on';

    my $o;
    if ( $args->{join} ) {
        my $desc = $next ? 'ASC' : 'DESC';
        my $op   = $next ? '>'   : '<';

        $terms->{blog_id}         = $obj->blog_id;
        $terms->{content_type_id} = $obj->content_type_id;

        $args->{sort} = [
            { column => $by,  desc => $desc },
            { column => 'id', desc => $desc },
        ];

        $o = MT::ContentData->load(
            { %{$terms}, $by => { $op => $obj->$by } }, $args );
        $o
            ||= MT::ContentData->load(
            { %{$terms}, $by => $obj->$by, id => { $op => $obj->id } },
            $args );
    }
    else {
        $o = $obj->nextprev(
            direction => $direction,
            terms     => {
                blog_id         => $obj->blog_id,
                content_type_id => $obj->content_type_id,
                %$terms,
            },
            args => $args,
            by   => $by,
        );
    }
    MT::Util::weaken( $obj->{$label} = $o ) if $o;
    return $o;
}

sub is_in_category {
    my $self         = shift;
    my ($cat)        = @_;
    my $content_type = $self->content_type or return;
    my @category_field_data
        = grep { $_->{type} eq 'categories' } @{ $content_type->fields }
        or return;
    for my $f (@category_field_data) {
        my $category_ids = $self->data->{ $f->{id} } || [];
        if ( grep { $_ == $cat->id } @{$category_ids} ) {
            return 1;
        }
    }
    0;
}

sub make_list_props {
    my $props = {};

    my $iter = MT::ContentType->load_iter;
    while ( my $content_type = $iter->() ) {
        my $key   = 'content_data_' . $content_type->id;
        my $order = 1000;
        my $field_list_props
            = _make_field_list_props( $content_type, $order );

        if ( $order < 2000 ) {
            $order = 2000;
        }
        else {
            $order = ( POSIX::floor( $order / 100 ) + 1 ) * 100;
        }

        $props->{$key} = {
            id => {
                base  => '__virtual.id',
                order => 100,
            },
            title => {
                base    => '__virtual.title',
                label   => 'Title',
                display => 'force',
                order   => 200,
                html    => \&_make_content_data_title_html,
            },
            modified_on => {
                base    => '__virtual.modified_on',
                display => 'force',
                order   => $order,
            },
            author_name => {
                base    => '__virtual.author_name',
                order   => $order + 100,
                display => 'optional',
            },
            status     => { base => 'entry.status' },
            created_on => {
                base    => '__virtual.created_on',
                display => 'none',
            },
            author_status => { base => 'entry.author_status' },
            %{$field_list_props},
        };
    }

    return $props;
}

sub _make_content_data_title_html {
    my $prop = shift;
    my ( $obj, $app ) = @_;
    my $col       = $prop->col;
    my $alt_label = $prop->alternative_label;
    my $id        = $obj->id;
    my $label     = $obj->$col;
    $label = '' if !defined $label;
    $label =~ s/^\s+|\s+$//g;
    my $blog_id           = $app->blog ? $app->blog->id : 0;
    my $datasource        = $app->param('datasource');
    my ($content_type_id) = $datasource =~ /(\d+)$/;
    my $edit_link         = $app->uri(
        mode => 'edit_content_data',
        args => {
            id              => $id,
            blog_id         => $blog_id,
            content_type_id => $content_type_id,
        },
    );

    if ( defined $label && $label ne '' ) {
        my $can_double_encode = 1;
        $label = MT::Util::encode_html( $label, $can_double_encode );
        return qq{<a href="$edit_link">$label</a>};
    }
    else {
        return MT->translate(
            qq{[_1] (<a href="[_2]">id:[_3]</a>)},
            $alt_label ? $alt_label : 'No ' . $label,
            $edit_link, $id,
        );
    }
}

sub _make_field_list_props {
    my ( $content_type, $order, $parent_field_data ) = @_;
    my $props               = {};
    my $content_field_types = MT->registry('content_field_types');

    for my $field_data ( @{ $content_type->fields } ) {
        my $idx_type   = $field_data->{type};
        my $field_key  = 'content_field_' . $field_data->{id};
        my $field_type = $content_field_types->{$idx_type} or next;

        for my $prop_name ( keys %{ $field_type->{list_props} || {} } ) {

            next
                if $parent_field_data
                && $prop_name ne $idx_type
                && !( $idx_type eq 'content_type' && $prop_name eq 'id' );

            my $label;
            if ( $prop_name eq $idx_type ) {
                $label = $field_data->{options}{label};
            }
            else {
                $label = $prop_name;
                if ( $label eq 'id' ) {
                    $label = 'ID';
                }
                else {
                    $label =~ s/^([a-z])/\u$1/g;
                    $label =~ s/_([a-z])/ \u$1/g;
                }
                $label = $field_data->{options}{label} . " ${label}";
            }
            if ($parent_field_data) {
                $label = $parent_field_data->{options}{label} . " ${label}";
            }
            $label = MT->translate($label);

            my $prop_key;
            if ( $prop_name eq $idx_type ) {
                $prop_key = $field_key;
            }
            else {
                $prop_key = "${field_key}_${prop_name}";
            }
            if ($parent_field_data) {
                my $parent_field_key
                    = 'content_field_' . $parent_field_data->{id};
                $prop_key = "${parent_field_key}_${prop_key}";
            }

            my $display
                = $parent_field_data
                ? 'none'
                : $field_data->{options}{display};

            $props->{$prop_key} = {
                (   content_field_id   => $field_data->{id},
                    data_type          => $field_type->{data_type},
                    default_sort_order => 'ascend',
                    display            => $display,
                    filter_label       => $label,
                    html               => \&_make_title_html,
                    idx_type           => $idx_type,
                    label              => $label,
                    order              => $order,
                    sort               => \&_default_sort,
                ),
                %{ $field_type->{list_props}{$prop_name} },
            };

            if ($parent_field_data) {
                my $terms = $props->{$prop_key}{terms};
                if ( $terms && !ref $terms && $terms =~ /^(sub|\$)/ ) {
                    $terms = MT->handler_to_coderef($terms);
                    $props->{$prop_key}{terms} = sub {
                        my $prop = shift;
                        my ( $args, $db_terms, $db_args ) = @_;

                        my $child_ret;
                        {
                            local $db_terms->{content_type_id}
                                = $content_type->id;
                            $child_ret = $terms->( $prop, @_ );
                        }
                        return $child_ret
                            unless $child_ret && $child_ret->{id};

                        local $prop->{content_field_id}
                            = $parent_field_data->{id};

                        my $option = $args->{option} || '';
                        if (   $option eq 'not_contains'
                            || $option eq 'not_equal' )
                        {
                            my $cd_terms;
                            if ( ref $child_ret->{id} eq 'HASH'
                                && $child_ret->{id}{not} )
                            {
                                $cd_terms = { id => $child_ret->{id}{not} };
                            }
                            else {
                                $cd_terms
                                    = { id => { not => $child_ret->{id} } };
                            }
                            my @child_contains_cd_ids
                                = map { $_->id }
                                MT::ContentData->load( $cd_terms,
                                { fetchonly => { id => 1 } } );
                            my $join_terms = { value_integer =>
                                    [ \'IS NULL', @child_contains_cd_ids ] };
                            my $cd_ids = get_cd_ids_by_left_join( $prop,
                                $join_terms, undef, @_ );
                            $cd_ids ? { id => { not => $cd_ids } } : ();
                        }
                        else {
                            my $join_terms
                                = { value_integer => $child_ret->{id} };
                            my $cd_ids = get_cd_ids_by_inner_join( $prop,
                                $join_terms, undef, @_ );
                            { id => $cd_ids };
                        }
                    };
                }
            }

            $order++;
        }

        if ( !$parent_field_data && $idx_type eq 'content_type' ) {
            my $cf = MT::ContentField->load( $field_data->{id} ) or next;
            my $related_ct = $cf->related_content_type or next;
            my $child_props
                = _make_field_list_props( $related_ct, $order, $field_data );
            $props = { %{$props}, %{$child_props} };
        }
    }

    $_[1] = $order;

    $props;
}

sub _default_sort {
    my $prop = shift;
    my ( $terms, $args ) = @_;

    my $cf_idx_join = MT::ContentFieldIndex->join_on(
        undef, undef,
        {   type      => 'left',
            condition => {
                content_data_id  => \'= cd_id',
                content_field_id => $prop->content_field_id,
            },
            sort      => 'value_' . $prop->data_type,
            direction => delete $args->{direction},
            unique    => 1,
        },
    );

    $args->{joins} ||= [];
    push @{ $args->{joins} }, $cf_idx_join;

    return;
}

sub _make_title_html {
    my ( $prop, $content_data, $app ) = @_;

    my $label = $content_data->data->{ $prop->content_field_id };
    if ( $label && ref $label eq 'ARRAY' ) {
        my $delimiter = $app->registry('content_field_types')
            ->{ $prop->{idx_type} }{options_delimiter} || ',';
        $label = join "${delimiter} ", @$label;
    }

    $label = '' unless defined $label;

    return qq{<span class="label">$label</span>};
}

1;

