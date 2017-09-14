# Movable Type (r) (C) 2007-2017 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::CMS::ContentData;

use strict;
use warnings;

use MT::Blog;
use MT::CMS::ContentType;
use MT::ContentType;
use MT::Log;

sub edit {
    my ($app) = @_;
    my $blog  = $app->blog;
    my $cfg   = $app->config;
    my $param = {};
    my $data;

    my $blog_id = $app->param('blog_id')
        or return $app->errtrans("Invalid request.");
    my $content_type_id = $app->param('content_type_id')
        or return $app->errtrans("Invalid request.");
    my $content_type = MT::ContentType->load($content_type_id)
        or return $app->errtrans('Invalid request.');

    if ( $app->param('_recover') ) {
        $app->param( '_type', 'content_data' );
        my $sess_obj = $app->autosave_session_obj;
        if ($sess_obj) {
            my $autosave_data = $sess_obj->thaw_data;
            if ($autosave_data) {
                $app->param( $_, $autosave_data->{$_} )
                    for keys %$autosave_data;
                my $id = $app->param('id');
                $app->delete_param('id')
                    if defined $id && !$id;
                $data = $autosave_data->{data};
                $param->{'recovered_object'} = 1;
            }
            else {
                $param->{'recovered_failed'} = 1;
            }
        }
        else {
            $param->{'recovered_failed'} = 1;
        }
    }

    if ( !$app->param('reedit') ) {
        $app->param( '_type', 'content_data' );
        if ( my $sess_obj = $app->autosave_session_obj ) {
            $param->{autosaved_object_exists} = 1;
            $param->{autosaved_object_ts}
                = MT::Util::epoch2ts( $blog, $sess_obj->start );
        }
    }

    $param->{autosave_frequency} = $app->config->AutoSaveFrequency;
    $param->{name}               = $content_type->name;
    $param->{has_multi_line_text_field}
        = $content_type->has_multi_line_text_field;

    my $array           = $content_type->fields;
    my $ct_unique_id    = $content_type->unique_id;
    my $content_data_id = $app->param('id');

    $param->{use_revision} = $blog->use_revision ? 1 : 0;

    my $content_data;
    if ($content_data_id) {
        $content_data = MT::ContentData->load($content_data_id)
            or return $app->error(
            $app->translate(
                'Load failed: [_1]',
                MT::ContentData->errstr
                    || $app->translate('(no reason given)')
            )
            );

        if ( $blog->use_revision ) {

            my $original_revision = $content_data->revision;
            my $rn                = $app->param('r');
            if ( defined $rn && $rn != $content_data->current_revision ) {
                my $status_text
                    = MT::Entry::status_text( $content_data->status );
                $param->{current_status_text} = $status_text;
                $param->{current_status_label}
                    = $app->translate($status_text);
                my $rev
                    = $content_data->load_revision( { rev_number => $rn } );
                if ( $rev && @$rev ) {
                    $content_data = $rev->[0];
                    my $values = $content_data->get_values;
                    $param->{$_} = $values->{$_} for keys %$values;
                    $param->{loaded_revision} = 1;
                }
                $param->{rev_number} = $rn;
                $param->{no_snapshot} = 1 if $app->param('no_snapshot');
            }
            $param->{rev_date} = MT::Util::format_ts(
                '%Y-%m-%d %H:%M:%S',
                $content_data->modified_on,
                $blog, $app->user ? $app->user->preferred_language : undef
            );
        }

        $param->{title}      = $content_data->title;
        $param->{identifier} = $content_data->identifier;

        my $status = $app->param('status') || $content_data->status;
        $status =~ s/\D//g;
        $param->{status} = $status;
        $param->{ 'status_' . MT::Entry::status_text($status) } = 1;

        $param->{authored_on_date} = $app->param('authored_on_date')
            || MT::Util::format_ts( '%Y-%m-%d', $content_data->authored_on,
            $blog, $app->user ? $app->user->preferred_language : undef );
        $param->{authored_on_time} = $app->param('authored_on_time')
            || MT::Util::format_ts( '%H:%M:%S', $content_data->authored_on,
            $blog, $app->user ? $app->user->preferred_language : undef );
        $param->{unpublished_on_date} = $app->param('unpublished_on_date')
            || MT::Util::format_ts( '%Y-%m-%d', $content_data->unpublished_on,
            $blog, $app->user ? $app->user->preferred_language : undef );
        $param->{unpublished_on_time} = $app->param('unpublished_on_time')
            || MT::Util::format_ts( '%H:%M:%S', $content_data->unpublished_on,
            $blog, $app->user ? $app->user->preferred_language : undef );
    }
    else {
        $param->{title} = $app->param('title');

        my $def_status;
        if ( $def_status = $app->param('status') ) {
            $def_status =~ s/\D//g;
            $param->{status} = $def_status;
        }
        else {
            $def_status = $blog->status_default;
        }
        $param->{ "status_" . MT::Entry::status_text($def_status) } = 1;

        my @now = MT::Util::offset_time_list( time, $blog );
        $param->{authored_on_date} = $app->param('authored_on_date')
            || POSIX::strftime( '%Y-%m-%d', @now );
        $param->{authored_on_time} = $app->param('authored_on_time')
            || POSIX::strftime( '%H:%M:%S', @now );
        $param->{unpublished_on_date} = $app->param('unpublished_on_date');
        $param->{unpublished_on_time} = $app->param('unpublished_on_time');
    }

    $data = $content_data->data if $content_data && !$data;
    my $convert_breaks
        = $content_data
        ? MT::Serialize->unserialize( $content_data->convert_breaks )
        : undef;
    my $blockeditor_data
        = $content_data
        ? $content_data->block_editor_data()
        : undef;
    my $content_field_types = $app->registry('content_field_types');
    @$array = map {
        my $e_unique_id = $_->{unique_id};
        my $can_edit_field
            = $app->permissions->can_do( 'content_type:'
                . $ct_unique_id
                . '-content_field:'
                . $e_unique_id );
        if (   $can_edit_field
            || $app->permissions->can_do('edit_all_content_datas') )
        {
            $_->{can_edit} = 1;
        }
        $_->{content_field_id} = $_->{id};
        delete $_->{id};

        if ( $app->param( $_->{content_field_id} ) ) {
            $_->{value} = $app->param( $_->{content_field_id} );
        }
        elsif ( $content_data_id || $data ) {
            $_->{value} = $data->{ $_->{content_field_id} };
        }
        else {
            # TODO: fix after updating values option.
            if ( $_->{type} eq 'select_box' || $_->{type} eq 'checkboxes' ) {
                my $delimiter = quotemeta( $_->{options_delimiter} || ',' );
                my @values = split $delimiter, $_->{options}{initial_value};
                $_->{value} = \@values;
            }
            else {
                $_->{value} = $_->{options}{initial_value};
            }
        }

        my $content_field_type = $content_field_types->{ $_->{type} };

        if ( my $field_html_params
            = $content_field_type->{field_html_params} )
        {
            if ( !ref $field_html_params ) {
                $field_html_params
                    = MT->handler_to_coderef($field_html_params);
            }
            if ( 'CODE' eq ref $field_html_params ) {
                $field_html_params = $field_html_params->( $app, $_ );
            }

            if ( ref $field_html_params eq 'HASH' ) {
                for my $key ( keys %{$field_html_params} ) {
                    unless ( exists $_->{$key} ) {
                        $_->{$key} = $field_html_params->{$key};
                    }
                }
            }
        }

        if ( my $field_html = $content_field_type->{field_html} ) {
            if ( !ref $field_html ) {
                if ( $field_html =~ /\.tmpl$/ ) {
                    my $plugin = $content_field_type->{plugin};
                    $field_html
                        = $plugin->id eq 'core'
                        ? $app->load_tmpl($field_html)
                        : $plugin->load_tmpl($field_html);
                    $field_html = $field_html->text if $field_html;
                }
                else {
                    $field_html = MT->handler_to_coderef($field_html);
                }
            }
            if ( 'CODE' eq ref $field_html ) {
                $_->{field_html} = $field_html->( $app, $_ );
            }
            else {
                $_->{field_html} = $field_html;
            }
        }

        $_->{data_type} = $content_field_types->{ $_->{type} }{data_type};
        if ( $_->{type} eq 'multi_line_text' ) {
            if ( $convert_breaks
                && exists $$convert_breaks->{ $_->{content_field_id} } )
            {
                $_->{convert_breaks}
                    = $$convert_breaks->{ $_->{content_field_id} };
            }
            else {
                $_->{convert_breaks} = $_->{options}{input_format};
            }
        }
        $_;
    } @$array;

    $param->{fields} = $array;
    if ($blockeditor_data) {
        $param->{block_editor_data} = $blockeditor_data;
    }

    foreach my $name (qw( saved err_msg content_type_id id )) {
        $param->{$name} = $app->param($name) if $app->param($name);
    }

    $param->{new_object}          = $content_data_id ? 0 : 1;
    $param->{object_label}        = $content_type->name;
    $param->{sitepath_configured} = $blog && $blog->site_path ? 1 : 0;

    ## Load text filters if user displays them
    my $filters = MT->all_text_filters;
    $param->{text_filters} = [];
    for my $filter ( keys %$filters ) {
        if ( my $cond = $filters->{$filter}{condition} ) {
            $cond = MT->handler_to_coderef($cond) if !ref($cond);
            next unless $cond->('content-type');
        }
        push @{ $param->{text_filters} },
            {
            filter_key   => $filter,
            filter_label => $filters->{$filter}{label},
            filter_docs  => $filters->{$filter}{docs},
            };
    }
    $param->{text_filters} = [ sort { $a->{filter_key} cmp $b->{filter_key} }
            @{ $param->{text_filters} } ];
    unshift @{ $param->{text_filters} },
        {
        filter_key   => '0',
        filter_label => $app->translate('None'),
        };

    $app->setup_editor_param($param);

    $param->{basename_limit} = ( $blog ? $blog->basename_limit : 0 ) || 30;

    $app->build_page( $app->load_tmpl('edit_content_data.tmpl'), $param );
}

sub save {
    my ($app) = @_;
    my $blog  = $app->blog;
    my $cfg   = $app->config;
    my $param = {};

    $app->validate_magic
        or return $app->errtrans("Invalid request.");
    my $perms = $app->permissions;
    return $app->permission_denied()
        unless $app->user->is_superuser()
        || ( $perms
        && $perms->can_administer_blog );

    my $blog_id = $app->param('blog_id')
        or return $app->errtrans("Invalid request.");
    my $content_type_id = $app->param('content_type_id')
        or return $app->errtrans("Invalid request.");

    my $content_type = MT::ContentType->load($content_type_id);
    my $field_data   = $content_type->fields;

    my $content_data_id = $app->param('id');

    my $content_field_types = $app->registry('content_field_types');

    my $convert_breaks = {};
    my $data           = {};
    foreach my $f (@$field_data) {
        my $content_field_type = $content_field_types->{ $f->{type} };
        $data->{ $f->{id} }
            = _get_form_data( $app, $content_field_type, $f );
        if ( $f->{type} eq 'multi_line_text' ) {
            $convert_breaks->{ $f->{id} } = $app->param(
                'content-field-' . $f->{id} . '_convert_breaks' );
        }
    }

    if ( $app->param('_autosave') ) {
        return MT::CMS::ContentType::_autosave_content_data( $app, $data );
    }

    if ( my $errors = _validate_content_fields( $app, $content_type, $data ) )
    {

        # FIXME: this does not preserve content field values.
        return $app->redirect(
            $app->uri(
                mode => 'edit_content_data',
                args => {
                    blog_id         => $blog_id,
                    content_type_id => $content_type_id,
                    id              => $content_data_id,
                    err_msg         => $errors->[0]{error},
                },
            )
        );
    }

    my $content_data
        = $content_data_id
        ? MT::ContentData->load($content_data_id)
        : MT::ContentData->new();

    my $orig = $content_data->clone;
    my $status_old = $content_data_id ? $content_data->status : 0;

    if ( $content_data->id ) {
        $content_data->modified_by( $app->user->id );
    }
    else {
        $content_data->author_id( $app->user->id );
        $content_data->blog_id($blog_id);
    }
    $content_data->content_type_id($content_type_id);
    $content_data->data($data);

    $content_data->title( scalar $app->param('title') );
    $content_data->identifier( scalar $app->param('identifier') );

    if ( $app->param('scheduled') ) {
        $content_data->status( MT::Entry::FUTURE() );
    }
    else {
        my $status = $app->param('status');
        $content_data->status($status);
    }
    if ( ( $content_data->status || 0 ) != MT::Entry::HOLD() ) {
        if ( !$blog->site_path || !$blog->site_url ) {
            return $app->error(
                $app->translate(
                    "Your blog has not been configured with a site path and URL. You cannot publish entries until these are defined."
                )
            );
        }
    }

    my $ao_d = $app->param('authored_on_date');
    my $ao_t = $app->param('authored_on_time');
    my $uo_d = $app->param('unpublished_on_date');
    my $uo_t = $app->param('unpublished_on_time');

    # TODO: permission check
    if ($ao_d) {
        my %param = ();
        my $ao    = $ao_d . ' ' . $ao_t;
        unless ( $ao
            =~ m!^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$!
            )
        {
            $param{error} = $app->translate(
                "Invalid date '[_1]'; 'Published on' dates must be in the format YYYY-MM-DD HH:MM:SS.",
                $ao
            );
        }
        unless ( $param{error} ) {
            my $s = $6 || 0;
            $param{error} = $app->translate(
                "Invalid date '[_1]'; 'Published on' dates should be real dates.",
                $ao
                )
                if (
                   $s > 59
                || $s < 0
                || $5 > 59
                || $5 < 0
                || $4 > 23
                || $4 < 0
                || $2 > 12
                || $2 < 1
                || $3 < 1
                || ( MT::Util::days_in( $2, $1 ) < $3
                    && !MT::Util::leap_day( $1, $2, $3 ) )
                );
        }
        $param{return_args} = $app->param('return_args');
        return $app->forward( "view", \%param ) if $param{error};
        my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5,
            ( $6 || 0 );
        $content_data->authored_on($ts);
    }

    # TODO: permission check
    if ( $content_data->status != MT::Entry::UNPUBLISH() ) {
        if ( $uo_d || $uo_t ) {
            my %param = ();
            my $uo    = $uo_d . ' ' . $uo_t;
            $param{error} = $app->translate(
                "Invalid date '[_1]'; 'Unpublished on' dates must be in the format YYYY-MM-DD HH:MM:SS.",
                $uo
                )
                unless ( $uo
                =~ m!^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$!
                );
            unless ( $param{error} ) {
                my $s = $6 || 0;
                $param{error} = $app->translate(
                    "Invalid date '[_1]'; 'Unpublished on' dates should be real dates.",
                    $uo
                    )
                    if (
                       $s > 59
                    || $s < 0
                    || $5 > 59
                    || $5 < 0
                    || $4 > 23
                    || $4 < 0
                    || $2 > 12
                    || $2 < 1
                    || $3 < 1
                    || ( MT::Util::days_in( $2, $1 ) < $3
                        && !MT::Util::leap_day( $1, $2, $3 ) )
                    );
            }
            my $ts = sprintf "%04d%02d%02d%02d%02d%02d", $1, $2, $3, $4, $5,
                ( $6 || 0 );
            unless ( $param{error} ) {
                $param{error} = $app->translate(
                    "Invalid date '[_1]'; 'Unpublished on' dates should be dates in the future.",
                    $uo
                    )
                    if (
                    MT::DateTime->compare(
                        blog => $blog,
                        a    => { value => time(), type => 'epoch' },
                        b    => $ts
                    ) > 0
                    );
            }
            if ( !$param{error} && $content_data->authored_on ) {
                $param{error} = $app->translate(
                    "Invalid date '[_1]'; 'Unpublished on' dates should be later than the corresponding 'Published on' date.",
                    $uo
                    )
                    if (
                    MT::DateTime->compare(
                        blog => $blog,
                        a    => $content_data->authored_on,
                        b    => $ts
                    ) > 0
                    );
            }
            $param{show_input_unpublished_on} = 1 if $param{error};
            $param{return_args} = $app->param('return_args');
            return $app->forward( "view", \%param ) if $param{error};
            $content_data->unpublished_on($ts);
        }
        else {
            $content_data->unpublished_on(undef);
        }
    }
    $content_data->convert_breaks(
        MT::Serialize->serialize( \$convert_breaks ) );

    my $block_editor_data = $app->param('blockeditor-data');
    $content_data->block_editor_data($block_editor_data);

    $app->run_callbacks( 'cms_pre_save.cd', $app, $content_data, $orig );

    $content_data->save
        or return $app->error(
        $app->translate(
            "Saving [_1] failed: [_2]", $content_type->name,
            $content_data->errstr
        )
        );

    $app->run_callbacks( 'cms_post_save.content_data',
        $app, $content_data, $orig );

    return $app->redirect(
        $app->uri(
            'mode' => 'view',
            args   => {
                blog_id         => $blog_id,
                content_type_id => $content_type_id,
                _type           => 'content_data',
                type            => 'content_data_' . $content_type_id,
                id              => $content_data->id,
                saved           => 1,
            }
        )
    );
}

sub delete {
    my $app = shift;

    my $orig_type = $app->param('type');
    my ($content_type_id) = $orig_type =~ /^content_data_(\d+)$/;

    unless ( $app->param('content_type_id') ) {
        $app->param( 'content_type_id', $content_type_id );
    }

    MT::CMS::Common::delete($app);
}

sub post_save {
    my ( $eh, $app, $obj, $orig_obj ) = @_;

    if ( $app->can('autosave_session_obj') ) {
        my $sess_obj = $app->autosave_session_obj;
        $sess_obj->remove if $sess_obj;
    }

    my $ct = $obj->content_type or return;
    my $author = $app->user;
    my $message;
    if ( !$orig_obj->id ) {
        $message
            = $app->translate( "[_1] '[_2]' (ID:[_3]) added by user '[_4]'",
            $ct->name, $obj->title, $obj->id, $author->name );
    }
    elsif ( $orig_obj->status ne $obj->status ) {
        $message = $app->translate(
            "[_1] '[_2]' (ID:[_3]) edited and its status changed from [_4] to [_5] by user '[_6]'",
            $ct->name,
            $obj->title,
            $obj->id,
            $app->translate( MT::Entry::status_text( $orig_obj->status ) ),
            $app->translate( MT::Entry::status_text( $obj->status ) ),
            $author->name
        );

    }
    else {
        $message
            = $app->translate( "[_1] '[_2]' (ID:[_3]) edited by user '[_4]'",
            $ct->name, $obj->title, $obj->id, $author->name );
    }
    require MT::Log;
    $app->log(
        {   message => $message,
            level   => MT::Log::INFO(),
            class   => 'content_data_' . $ct->id,
            $orig_obj->id ? ( category => 'edit' ) : ( category => 'new' ),
            metadata => $obj->id
        }
    );

    1;
}

sub post_delete {
    my ( $eh, $app, $obj ) = @_;

    if ( $app->can('autosave_session_obj') ) {
        my $sess_obj = $app->autosave_session_obj;
        $sess_obj->remove if $sess_obj;
    }

    my $ct = $obj->content_type or return;
    my $author = $app->user;

    $app->log(
        {   message => $app->translate(
                "[_1] '[_2]' (ID:[_3]) deleted by '[_4]'",
                $ct->name, $obj->title, $obj->id, $author->name
            ),
            level    => MT::Log::INFO(),
            class    => 'content_data_' . $ct->id,
            category => 'delete'
        }
    );
}

sub data_convert_to_html {
    my $app     = shift;
    my $format  = $app->param('format') || '';
    my @formats = split /\s*,\s*/, $format;
    my $field   = $app->param('field') || return '';

    my $text = $app->param($field) || '';

    my $result = {
        $field => $app->apply_text_filters( $text, \@formats ),
        format => $formats[0],
        field  => $field,
    };
    return $app->json_result($result);
}

sub make_content_actions {
    my $iter            = MT::ContentType->load_iter;
    my $content_actions = {};
    while ( my $ct = $iter->() ) {
        my $key = 'content_data.content_data_' . $ct->id;
        $content_actions->{$key} = {
            new => {
                label => 'Create new ' . $ct->name,
                icon  => 'ic_add',
                order => 100,
                mode  => 'view',
                args  => {
                    blog_id         => $ct->blog_id,
                    content_type_id => $ct->id,
                },
                class => 'icon-create',
            }
        };
    }
    $content_actions;
}

sub make_list_actions {
    my $common_delete_action = {
        delete => {
            label      => 'Delete',
            order      => 100,
            code       => '$Core::MT::CMS::ContentData::delete',
            button     => 1,
            js_message => 'delete',
        }
    };
    my $iter         = MT::ContentType->load_iter;
    my $list_actions = {};
    while ( my $ct = $iter->() ) {
        my $key = 'content_data.content_data_' . $ct->id;
        $list_actions->{$key} = $common_delete_action;
    }
    $list_actions;
}

sub make_menus {
    my $menus         = {};
    my $blog_order    = 100;
    my $website_order = 100;
    my $iter = MT::ContentType->load_iter( undef, { sort => 'name' } );
    while ( my $ct = $iter->() ) {
        my $blog = MT::Blog->load( $ct->blog_id ) or next;
        my $key = 'content_data:' . $ct->id;
        $menus->{$key} = {
            label => $ct->name,
            mode  => 'list',
            args  => {
                _type   => 'content_data',
                type    => 'content_data_' . $ct->id,
                blog_id => $ct->blog_id,
            },
            order => $blog->is_blog ? $blog_order : $website_order,
            view  => $blog->is_blog ? 'blog'      : 'website',
            condition => sub {
                $ct->blog_id == MT->app->blog->id;
            },
        };
        if ( $blog->is_blog ) {
            $blog_order += 100;
        }
        else {
            $website_order += 100;
        }
    }
    $menus;
}

sub _validate_content_fields {
    my $app = shift;
    my ( $content_type, $data ) = @_;
    my $content_field_types = $app->registry('content_field_types');

    my @errors;

    foreach my $f ( @{ $content_type->fields } ) {
        my $content_field_type = $content_field_types->{ $f->{type} };
        my $param_name         = 'content-field-' . $f->{id};
        my $d                  = $data->{ $f->{id} };

        if ( exists $f->{options}{required}
            && $f->{options}{required} )
        {
            my $has_data;
            if ( ref $d eq 'ARRAY' ) {
                $has_data = @{$d} ? 1 : 0;
            }
            else {
                $has_data = ( defined $d && $d ne '' ) ? 1 : 0;
            }
            unless ($has_data) {
                my $label = $f->{options}{label};
                push @errors,
                    {
                    field_id => $f->{id},
                    error =>
                        $app->translate(qq{"${label}" field is required.}),
                    };
                next;
            }
        }

        if ( my $ss_validator = $content_field_type->{ss_validator} ) {
            if ( !ref $ss_validator ) {
                $ss_validator = MT->handler_to_coderef($ss_validator);
            }
            if ( 'CODE' eq ref $ss_validator ) {
                if ( my $error = $ss_validator->( $app, $f, $d ) ) {
                    push @errors,
                        {
                        field_id => $f->{id},
                        error    => $error,
                        };
                }
            }
        }
    }

    @errors ? \@errors : undef;
}

sub validate_content_fields {
    my $app = shift;

    # TODO: permission check

    my $blog_id = $app->blog ? $app->blog->id : undef;
    my $content_type_id = $app->param('content_type_id') || 0;
    my $content_type = MT::ContentType->load(
        { id => $content_type_id, blog_id => $blog_id } );

    return $app->json_error( $app->translate('Invalid request.') )
        unless $blog_id && $content_type;

    my $content_field_types = $app->registry('content_field_types');
    my $data                = {};
    foreach my $f ( @{ $content_type->fields } ) {
        my $content_field_type = $content_field_types->{ $f->{type} };
        $data->{ $f->{id} }
            = _get_form_data( $app, $content_field_type, $f );
    }

    my $invalid_count = 0;
    my %invalid_fields;
    if ( my $errors = _validate_content_fields( $app, $content_type, $data ) )
    {
        $invalid_count = scalar @{$errors};
        %invalid_fields = map { $_->{field_id} => $_->{error} } @{$errors};
    }

    $app->json_result(
        { invalidCount => $invalid_count, invalidFields => \%invalid_fields }
    );
}

sub _get_form_data {
    my ( $app, $content_field_type, $form_data ) = @_;

    if ( my $data_load_handler = $content_field_type->{data_load_handler} ) {
        if ( !ref $data_load_handler ) {
            $data_load_handler = MT->handler_to_coderef($data_load_handler);
        }
        if ( 'CODE' eq ref $data_load_handler ) {
            return $data_load_handler->( $app, $form_data );
        }
        else {
            return $data_load_handler;
        }
    }
    else {
        my $value = $app->param( 'content-field-' . $form_data->{id} );
        if ( defined $value && $value ne '' ) {
            $value;
        }
        else {
            undef;
        }
    }
}

sub cms_pre_load_filtered_list {
    my ( $cb, $app, $filter, $load_options, $cols ) = @_;

    my $object_ds = $filter->object_ds;
    $object_ds =~ /content_data_(\d+)/;
    my $content_type_id = $1;
    $load_options->{terms}{content_type_id} = $content_type_id;
}

sub start_import {
    my $app = shift;
    my $param = { page_title => $app->translate('Import Site Content'), };
    $app->load_tmpl( 'not_implemented_yet.tmpl', $param );
}

sub start_export {
    my $app = shift;
    my $param = { page_title => $app->translate('Export Site Content'), };
    $app->load_tmpl( 'not_implemented_yet.tmpl', $param );
}

1;
