package MT::ContentFieldType;
use strict;
use warnings;

sub core_content_field_types {
    {   content_type     => _content_type_registry(),
        single_line_text => _single_line_text_registry(),
        multi_line_text  => _multi_line_text_registry(),
        number           => _number_registry(),
        url              => _url_registry(),
        date_and_time    => _date_time_registry(),
        date_only        => _date_registry(),
        time_only        => _time_registry(),
        select_box       => _select_box_registry(),
        radio_button     => _radio_button_registry(),
        checkboxes       => _checkboxes_registry(),
        asset            => _asset_registry(),
        audio            => _audio_registry(),
        video            => _video_registry(),
        image            => _image_registry(),
        embedded_text    => _embedded_text_registry(),
        categories       => _categories_registry(),
        tags             => _tags_registry(),
        list             => _list_registry(),
        table            => _table_registry(),
    };
}

sub _content_type_registry {
    {   label     => 'Content Type',
        data_type => 'integer',
        order     => 10,
        data_load_handler =>
            '$Core::MT::ContentFieldType::Common::data_load_handler_multiple',
        field_html => 'field_html/field_html_content_type.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::ContentType::field_html_params',
        ss_validator =>
            '$Core::MT::ContentFieldType::ContentType::ss_validator',
        theme_import_handler =>
            '$Core::MT::ContentFieldType::ContentType::theme_import_handler',
        list_props => {
            content_type =>
                { html => '$Core::MT::ContentFieldType::ContentType::html' },
            id => {
                base    => '__virtual.integer',
                col     => 'value_integer',
                display => 'none',
                terms => '$Core::MT::ContentFieldType::ContentType::temrs_id',
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                multiple
                can_add
                max
                min
                content_type
                )
        ],
    };
}

sub _single_line_text_registry {
    {   label      => 'Single Line Text',
        data_type  => 'varchar',
        order      => 20,
        field_html => 'field_html/field_html_single_line_text.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::SingleLineText::field_html_params',
        ss_validator =>
            '$core::MT::ContentFieldType::SingleLineText::ss_validator',
        list_props => {
            single_line_text => {
                base  => '__virtual.string',
                col   => 'value_varchar',
                terms => '$Core::MT::ContentFieldType::Common::terms_text',
                use_blank => 1,
            },
        },
        options_html => 'content_field_type_options/single_line_text.tmpl',
        options => [
            qw(
                label
                description
                required
                display
                min_length
                max_length
                initial_value
                )
        ],
    };
}

sub _multi_line_text_registry {
    {   label     => 'Multi Line Text',
        data_type => 'blob',
        order     => 30,
        data_load_handler =>
            '$Core::MT::ContentFieldType::MultiLineText::data_load_handler',
        list_props => {
            multi_line_text => {
                base  => '__virtual.string',
                col   => 'value_blob',
                terms => '$Core::MT::ContentFieldType::Common::terms_text',
                use_blank => 1,
            },
        },
        theme_data_import_handler =>
            '$Core::MT::ContentFieldType::MultiLineText::theme_data_import_handler',
        options_html => 'content_field_type_options/multi_line_text.tmpl',
        options => [
            qw(
                label
                description
                required
                display
                initial_value
                input_format
                )
        ],
    };
}

sub _number_registry {
    {   label      => 'Number',
        data_type  => 'float',
        order      => 40,
        field_html => 'field_html/field_html_number.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Number::field_html_params',
        ss_validator => '$Core::MT::ContentFieldType::Number::ss_validator',
        list_props   => {
            float => {
                base  => '__virtual.float',
                col   => 'value_float',
                terms => '$Core::MT::ContentFieldType::Common::terms_text',
                use_blank => 1,
            },
        },
        options_html => 'content_field_type_options/number.tmpl',
        options => [
            qw(
                label
                description
                required
                display
                min_value
                max_value
                decimal_places
                initial_value
                )
        ],
    };
}

sub _url_registry {
    {   label        => 'URL',
        data_type    => 'blob',
        order        => 50,
        field_html   => 'field_html/field_html_url.tmpl',
        ss_validator => '$Core::MT::ContentFieldType::URL::ss_validator',
        list_props   => {
            url => {
                base  => '__virtual.string',
                col   => 'value_blob',
                terms => '$Core::MT::ContentFieldType::Common::terms_text',
                use_blank => 1,
            },
        },
        options_html => 'content_field_type_options/url.tmpl',
        options => [
            qw(
                label
                description
                required
                display
                initial_value
                )
        ],
    };
}

sub _date_time_registry {
    {   label      => 'Date and Time',
        data_type  => 'datetime',
        order      => 60,
        field_html => 'field_html/field_html_datetime.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::DateTime::field_html_params',
        data_load_handler =>
            '$Core::MT::ContentFieldType::DateTime::data_load_handler',
        ss_validator =>
            '$Core::MT::ContentFieldType::Common::ss_validator_datetime',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_datetime',
        list_props => {
            date_and_time => {
                base => '__virtual.date',
                col  => 'value_datetime',
                html => '$Core::MT::ContentFieldType::DateTime::html',
                terms =>
                    '$Core::MT::ContentFieldType::Common::terms_datetime',
                use_blank  => 1,
                use_future => 1,
            },
        },
        options_html => 'content_field_type_options/date_time.tmpl',
        options => [
            qw(
                label
                description
                required
                display
                initial_value
                )
        ],
    };
}

sub _date_registry {
    {   label      => 'Date',
        data_type  => 'datetime',
        order      => 70,
        field_html => 'field_html/field_html_date.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Date::field_html_params',
        data_load_handler =>
            '$Core::MT::ContentFieldType::Date::data_load_handler',
        ss_validator =>
            '$Core::MT::ContentFieldType::Common::ss_validator_datetime',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_datetime',
        list_props => {
            date => {
                base => '__virtual.date',
                col  => 'value_datetime',
                html => '$Core::MT::ContentFieldType::Date::html',
                terms =>
                    '$Core::MT::ContentFieldType::Common::terms_datetime',
                use_blank  => 1,
                use_future => 1,
            },
        },
        options_html => 'content_field_type_options/date.tmpl',
        options => [
            qw(
                label
                description
                required
                display
                initial_value
                )
        ],
    };
}

sub _time_registry {
    {   label      => 'Time',
        data_type  => 'datetime',
        order      => 80,
        field_html => 'field_html/field_html_time.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Time::field_html_params',
        data_load_handler =>
            '$Core::MT::ContentFieldType::Time::data_load_handler',
        ss_validator =>
            '$Core::MT::ContentFieldType::Common::ss_validator_datetime',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_datetime',
        list_props => {
            time => {
                filter_tmpl =>
                    '$Core::MT::ContentFieldType::Time::filter_tmpl',
                html      => '$Core::MT::ContentFieldType::Time::html',
                terms     => '$Core::MT::ContentFieldType::Time::terms',
                use_blank => 1,
            },
        },
        options_html => 'content_field_type_options/time.tmpl',
        options => [
            qw(
                label
                description
                required
                display
                initial_value
                )
        ],
    };
}

sub _select_box_registry {
    {   label     => 'Select Box',
        data_type => 'varchar',
        order     => 90,
        data_load_handler =>
            '$Core::MT::ContentFieldType::Common::data_load_handler_multiple',
        field_html => 'field_html/field_html_select_box.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::SelectBox::field_html_params',
        ss_validator =>
            '$Core::MT::ContentFieldType::Common::ss_validator_multiple',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_multiple',
        list_props => {
            select_box => {
                filter_tmpl =>
                    '$Core::MT::ContentFieldType::Common::filter_tmpl_multiple',
                html => '$Core::MT::ContentFieldType::Common::html_multiple',
                single_select_options =>
                    '$Core::MT::ContentFieldType::Common::single_select_options_multiple',
                terms =>
                    '$Core::MT::ContentFieldType::Common::terms_multiple',
            },
        },
        options_html => 'content_field_type_options/select_box.tmpl',
        options => [
            qw(
                label
                description
                required
                display
                multiple
                max
                min
                values
                initial_value
                )
        ],
    };
}

sub _radio_button_registry {
    {   label      => 'Radio Button',
        data_type  => 'varchar',
        order      => 100,
        field_html => 'field_html/field_html_radio_button.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::RadioButton::field_html_params',
        ss_validator =>
            '$Core::MT::ContentFieldType::Common::ss_validator_values',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_multiple',
        list_props => {
            radio_button => {
                filter_tmpl =>
                    '$Core::MT::ContentFieldType::Common::filter_tmpl_multiple',
                html => '$Core::MT::ContentFieldType::Common::html_multiple',
                single_select_options =>
                    '$Core::MT::ContentFieldType::Common::single_select_options_multiple',
                terms =>
                    '$Core::MT::ContentFieldType::Common::terms_multiple',
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                values
                initial_value
                )
        ],
    };
}

sub _checkboxes_registry {
    {   label     => 'Checkboxes',
        data_type => 'varchar',
        order     => 110,
        data_load_handler =>
            '$Core::MT::ContentFieldType::Common::data_load_handler_multiple',
        field_html => 'field_html/field_html_checkboxes.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Checkboxes::field_html_params',
        ss_validator =>
            '$Core::MT::ContentFieldType::Common::ss_validator_multiple',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_multiple',
        list_props => {
            checkboxes => {
                filter_tmpl =>
                    '$Core::MT::ContentFieldType::Common::filter_tmpl_multiple',
                html => '$Core::MT::ContentFieldType::Common::html_multiple',
                single_select_options =>
                    '$Core::MT::ContentFieldType::Common::single_select_options_multiple',
                terms =>
                    '$Core::MT::ContentFieldType::Common::terms_multiple',
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                multiple
                max
                min
                values
                initial_value
                )
        ],
    };
}

sub _asset_registry {
    {   label     => 'Asset',
        data_type => 'integer',
        order     => 120,
        data_load_handler =>
            '$Core::MT::ContentFieldType::Common::data_load_handler_asset',
        field_html => 'field_html/field_html_asset.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Asset::field_html_params',
        ss_validator => '$Core::MT::ContentFieldType::Asset::ss_validator',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_asset',
        list_props => {
            asset => {
                filter_tmpl =>
                    '$Core::MT::ContentFieldType::Common::filter_tmpl_multiple',
                html => '$Core::MT::ContentFieldType::Asset::html',
                single_select_options =>
                    '$Core::MT::ContentFieldType::Asset::single_select_options',
                terms =>
                    '$Core::MT::ContentFieldType::Common::terms_multiple',
            },
            author_name => {
                base    => '__virtual.author_name',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_author_name',
            },
            author_status => {
                base    => 'author.status',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_author_status',
            },
            date_created => {
                base    => '__virtual.date',
                col     => 'created_on',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_date',
            },
            date_modified => {
                base    => '__virtual.date',
                col     => 'modified_on',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_date',
            },
            description => {
                base      => '__virtual.string',
                col       => 'description',
                display   => 'none',
                terms     => '$Core::MT::ContentFieldType::Asset::terms_text',
                use_blank => 1,
            },
            file_extension => {
                base    => '__virtual.string',
                col     => 'file_ext',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_text',
            },
            filename => {
                base    => '__virtual.string',
                col     => 'file_name',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_text',
            },
            id => {
                base    => '__virtual.integer',
                col     => 'value_integer',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_id',
            },
            label => {
                base    => '__virtual.string',
                col     => 'label',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_text',
            },
            missing_file => {
                base    => 'asset.missing_file',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_missing_file',
            },
            tag => {
                base      => '__virtual.string',
                col       => 'name',
                display   => 'none',
                terms     => '$Core::MT::ContentFieldType::Asset::terms_tag',
                use_blank => 1,
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                multiple
                allow_upload
                max
                min
                )
        ],
    };
}

sub _audio_registry {
    {   label     => 'Audio',
        data_type => 'integer',
        order     => 130,
        data_load_handler =>
            '$Core::MT::ContentFieldType::Common::data_load_handler_asset',
        field_html => 'field_html/field_html_asset.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Asset::field_html_params',
        ss_validator => '$Core::MT::ContentFieldType::Asset::ss_validator',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_asset',
        list_props => {
            audio => {
                filter_tmpl =>
                    '$Core::MT::ContentFieldType::Common::filter_tmpl_multiple',
                html => '$Core::MT::ContentFieldType::Asset::html',
                single_select_options =>
                    '$Core::MT::ContentFieldType::Asset::single_select_options',
                terms =>
                    '$Core::MT::ContentFieldType::Common::terms_multiple',
            },
            author_name => {
                base    => '__virtual.author_name',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_author_name',
            },
            author_status => {
                base    => 'author.status',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_author_status',
            },
            date_created => {
                base    => '__virtual.date',
                col     => 'created_on',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_date',
            },
            date_modified => {
                base    => '__virtual.date',
                col     => 'modified_on',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_date',
            },
            description => {
                base      => '__virtual.string',
                col       => 'description',
                display   => 'none',
                terms     => '$Core::MT::ContentFieldType::Asset::terms_text',
                use_blank => 1,
            },
            file_extension => {
                base    => '__virtual.string',
                col     => 'file_ext',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_text',
            },
            filename => {
                base    => '__virtual.string',
                col     => 'file_name',
                display => 'none',
            },
            id => {
                base    => '__virtual.integer',
                col     => 'value_integer',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_id',
            },
            label => {
                base    => '__virtual.string',
                col     => 'label',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_text',
            },
            missing_file => {
                base    => 'asset.missing_file',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_missing_file',
            },
            tag => {
                base      => '__virtual.string',
                col       => 'name',
                display   => 'none',
                terms     => '$Core::MT::ContentFieldType::Asset::terms_tag',
                use_blank => 1,
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                multiple
                allow_upload
                max
                min
                )
        ],
    };
}

sub _video_registry {
    {   label     => 'Video',
        data_type => 'integer',
        order     => 140,
        data_load_handler =>
            '$Core::MT::ContentFieldType::Common::data_load_handler_asset',
        field_html => 'field_html/field_html_asset.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Asset::field_html_params',
        ss_validator => '$Core::MT::ContentFieldType::Asset::ss_validator',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_asset',
        list_props => {
            video => {
                filter_tmpl =>
                    '$Core::MT::ContentFieldType::Common::filter_tmpl_multiple',
                html => '$Core::MT::ContentFieldType::Asset::html',
                single_select_options =>
                    '$Core::MT::ContentFieldType::Asset::single_select_options',
                terms =>
                    '$Core::MT::ContentFieldType::Common::terms_multiple',
            },
            author_name => {
                base    => '__virtual.author_name',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_author_name',
            },
            author_status => {
                base    => 'author.status',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_author_status',
            },
            date_created => {
                base    => '__virtual.date',
                col     => 'created_on',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_date',
            },
            date_modified => {
                base    => '__virtual.date',
                col     => 'modified_on',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_date',
            },
            description => {
                base      => '__virtual.string',
                col       => 'description',
                display   => 'none',
                terms     => '$Core::MT::ContentFieldType::Asset::terms_text',
                use_blank => 1,
            },
            file_extension => {
                base    => '__virtual.string',
                col     => 'file_ext',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_text',
            },
            filename => {
                base    => '__virtual.string',
                col     => 'file_name',
                display => 'none',
            },
            id => {
                base    => '__virtual.integer',
                col     => 'value_integer',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_id',
            },
            label => {
                base    => '__virtual.string',
                col     => 'label',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_text',
            },
            missing_file => {
                base    => 'asset.missing_file',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_missing_file',
            },
            tag => {
                base      => '__virtual.string',
                col       => 'name',
                display   => 'none',
                terms     => '$Core::MT::ContentFieldType::Asset::terms_tag',
                use_blank => 1,
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                multiple
                allow_upload
                max
                min
                )
        ],
    };
}

sub _image_registry {
    {   label     => 'Image',
        data_type => 'integer',
        order     => 150,
        data_load_handler =>
            '$Core::MT::ContentFieldType::Common::data_load_handler_asset',
        field_html => 'field_html/field_html_asset.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Asset::field_html_params',
        ss_validator => '$Core::MT::ContentFieldType::Asset::ss_validator',
        tag_handler =>
            '$Core::MT::ContentFieldType::Common::tag_handler_asset',
        list_props => {
            image => {
                filter_tmpl =>
                    '$Core::MT::ContentFieldType::Common::filter_tmpl_multiple',
                html => '$Core::MT::ContentFieldType::Asset::html',
                single_select_options =>
                    '$Core::MT::ContentFieldType::Asset::single_select_options',
                sub_fields => [
                    {   class   => 'thumbnail',
                        label   => 'Thumbnail',
                        display => 'default',
                    },
                ],
                terms =>
                    '$Core::MT::ContentFieldType::Common::terms_multiple',
            },
            author_name => {
                base    => '__virtual.author_name',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_author_name',
            },
            author_status => {
                base    => 'author.status',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_author_status',
            },
            date_created => {
                base    => '__virtual.date',
                col     => 'created_on',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_date',
            },
            date_modified => {
                base    => '__virtual.date',
                col     => 'modified_on',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_date',
            },
            description => {
                base      => '__virtual.string',
                col       => 'description',
                display   => 'none',
                terms     => '$Core::MT::ContentFieldType::Asset::terms_text',
                use_blank => 1,
            },
            file_extension => {
                base    => '__virtual.string',
                col     => 'file_ext',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_text',
            },
            filename => {
                base    => '__virtual.string',
                col     => 'file_name',
                display => 'none',
            },
            id => {
                base    => '__virtual.integer',
                col     => 'value_integer',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_id',
            },
            label => {
                base    => '__virtual.string',
                col     => 'label',
                display => 'none',
                terms   => '$Core::MT::ContentFieldType::Asset::terms_text',
            },
            missing_file => {
                base    => 'asset.missing_file',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_missing_file',
            },
            pixel_height => {
                base    => 'asset.image_height',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_image_size',
            },
            pixel_width => {
                base    => 'asset.image_width',
                display => 'none',
                terms =>
                    '$Core::MT::ContentFieldType::Asset::terms_image_size',
            },
            tag => {
                base      => '__virtual.string',
                col       => 'name',
                display   => 'none',
                terms     => '$Core::MT::ContentFieldType::Asset::terms_tag',
                use_blank => 1,
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                multiple
                allow_upload
                max
                min
                )
        ],
    };
}

sub _embedded_text_registry {
    {   label      => 'Embedded Text',
        data_type  => 'blob',
        order      => 160,
        list_props => {
            embedded_text => {
                base  => '__virtual.string',
                col   => 'value_blob',
                terms => '$Core::MT::ContentFieldType::Common::terms_text',
                use_blank => 1,
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                initial_value
                )
        ],
    };
}

sub _categories_registry {
    {   label     => 'Categories',
        data_type => 'integer',
        order     => 170,
        data_load_handler =>
            '$Core::MT::ContentFieldType::Categories::data_load_handler',
        field_html => 'field_html/field_html_categories.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Categories::field_html_params',
        ss_validator =>
            '$Core::MT::ContentFieldType::Categories::ss_validator',
        tag_handler => '$Core::MT::ContentFieldType::Categories::tag_handler',
        theme_import_handler =>
            '$Core::MT::ContentFieldType::Categories::theme_import_handler',
        list_props => {
            categories => {
                base      => '__virtual.string',
                col       => 'label',
                html      => '$Core::MT::ContentFieldType::Categories::html',
                terms     => '$Core::MT::ContentFieldType::Categories::terms',
                use_blank => 1,
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                multiple
                can_add
                max
                min
                category_set
                )
        ],
    };
}

sub _tags_registry {
    {   label     => 'Tags',
        data_type => 'integer',
        order     => 180,

      # prototype
      # data_load_handler =>
      #     '$Core::MT::ContentFieldType::Common::data_load_handler_multiple',
        data_load_handler =>
            '$Core::MT::ContentFieldType::Tags::data_load_handler',
        field_html => 'field_html/field_html_tags.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Tags::field_html_params',
        ss_validator => '$Core::MT::ContentFieldType::Tags::ss_validator',
        tag_handler  => '$Core::MT::ContentFieldType::Tags::tag_handler',
        list_props   => {
            tags => {
                base      => '__virtual.string',
                col       => 'name',
                html      => '$Core::MT::ContentFieldType::Tags::html',
                terms     => '$Core::MT::ContentFieldType::Tags::terms',
                use_blank => 1,
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                multiple
                can_add
                max
                min
                initial_value
                )
        ],
    };
}

sub _list_registry {
    {   label     => 'list',
        data_type => 'varchar',
        order     => 190,
        data_load_handler =>
            '$Core::MT::ContentFieldType::Common::data_load_handler_multiple',
        field_html => 'field_html/field_html_list.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::List::field_html_params',
        tag_handler => '$Core::MT::ContentFieldType::List::tag_handler',
        list_props  => {
            list => {
                base    => '__virtual.string',
                col     => 'value_varchar',
                display => 'none',
                html    => '$Core::MT::ContentFieldType::List::html',
                terms   => '$Core::MT::ContentFieldType::List::terms',
            },
        },
        options => [
            qw(
                label
                description
                required
                display
                )
        ],
    };
}

sub _table_registry {
    {   label      => 'Table',
        data_type  => 'blob',
        order      => 200,
        field_html => 'field_html/field_html_table.tmpl',
        field_html_params =>
            '$Core::MT::ContentFieldType::Table::field_html_params',
        tag_handler => '$Core::MT::ContentFieldType::Table::tag_handler',
        list_props  => {
            table => {
                base    => '__virtual.string',
                col     => 'value_blob',
                display => 'none',
                html    => '$Core::MT::ContentFieldType::Table::html',
                terms   => '$Core::MT::ContentFieldType::Common::terms_text',
            },
        },
        options => [
            qw(
                label
                description
                display
                initial_rows
                row_heading
                increase_decrease_rows
                initial_columns
                column_heading
                increase_decrease_columns
                )
        ],
    };
}

1;
