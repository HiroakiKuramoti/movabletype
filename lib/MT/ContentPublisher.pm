# Movable Type (r) (C) 2001-2017 Six Apart, Ltd. All Rights Reserved.
# This code cannot be redistributed without permission from www.sixapart.com.
# For more information, consult your Movable Type license.
#
# $Id$

package MT::ContentPublisher;

use strict;
use base qw( MT::WeblogPublisher );
our @EXPORT = qw(ArchiveFileTemplate ArchiveType);

use MT::ArchiveType;
use File::Basename;

our %ArchiveTypes;

sub init_archive_types {
    my $types = MT->registry("archive_types") || {};
    my $mt = MT->instance;
    while ( my ( $type, $typedata ) = each %$types ) {
        if ( 'HASH' eq ref $typedata ) {
            $typedata = MT::ArchiveType->new(%$typedata);
        }
        $ArchiveTypes{$type} = $typedata;
    }
}

sub archive_types {
    init_archive_types(@_) unless %ArchiveTypes;
    keys %ArchiveTypes;
}

sub archiver {
    my $mt = shift;
    my ($at) = @_;
    init_archive_types() unless %ArchiveTypes;
    my $archiver = $at ? $ArchiveTypes{$at} : undef;
    if ( $archiver && !ref($archiver) ) {

        # A package name-- load package and instantiate Archiver object
        if ( $archiver =~ m/::/ ) {
            eval("require $archiver; 1;");
            die "Invalid archive type package '$archiver': $@"
                if $@;    # fatal error here
            my $inst = $archiver->new();
            $archiver = $ArchiveTypes{$at} = $inst;
        }
    }
    return $archiver;
}

sub core_archive_types {
    return {
        'Yearly'              => 'MT::ArchiveType::Yearly',
        'Monthly'             => 'MT::ArchiveType::Monthly',
        'Weekly'              => 'MT::ArchiveType::Weekly',
        'Individual'          => 'MT::ArchiveType::Individual',
        'Page'                => 'MT::ArchiveType::Page',
        'Daily'               => 'MT::ArchiveType::Daily',
        'Category'            => 'MT::ArchiveType::Category',
        'Author'              => 'MT::ArchiveType::Author',
        'Author-Yearly'       => 'MT::ArchiveType::AuthorYearly',
        'Author-Monthly'      => 'MT::ArchiveType::AuthorMonthly',
        'Author-Weekly'       => 'MT::ArchiveType::AuthorWeekly',
        'Author-Daily'        => 'MT::ArchiveType::AuthorDaily',
        'Category-Yearly'     => 'MT::ArchiveType::CategoryYearly',
        'Category-Monthly'    => 'MT::ArchiveType::CategoryMonthly',
        'Category-Daily'      => 'MT::ArchiveType::CategoryDaily',
        'Category-Weekly'     => 'MT::ArchiveType::CategoryWeekly',
        'ContentType'         => 'MT::ArchiveType::ContentType',
        'ContentType-Yearly'  => 'MT::ArchiveType::ContentTypeYearly',
        'ContentType-Monthly' => 'MT::ArchiveType::ContentTypeMonthly',
        'ContentType-Weekly'  => 'MT::ArchiveType::ContentTypeWeekly',
        'ContentType-Daily'   => 'MT::ArchiveType::ContentTypeDaily',
        'ContentType_Author'  => 'MT::ArchiveType::ContentTypeAuthor',
        'ContentType_Author-Yearly' =>
            'MT::ArchiveType::ContentTypeAuthorYearly',
        'ContentType_Author-Monthly' =>
            'MT::ArchiveType::ContentTypeAuthorMonthly',
        'ContentType_Author-Weekly' =>
            'MT::ArchiveType::ContentTypeAuthorWeekly',
        'ContentType_Author-Daily' =>
            'MT::ArchiveType::ContentTypeAuthorDaily',
        'ContentType_Category' => 'MT::ArchiveType::ContentTypeCategory',
        'ContentType_Category-Yearly' =>
            'MT::ArchiveType::ContentTypeCategoryYearly',
        'ContentType_Category-Monthly' =>
            'MT::ArchiveType::ContentTypeCategoryMonthly',
        'ContentType_Category-Weekly' =>
            'MT::ArchiveType::ContentTypeCategoryWeekly',
        'ContentType_Category-Daily' =>
            'MT::ArchiveType::ContentTypeCategoryDaily',
    };

}

sub rebuild {
    my $mt    = shift;
    my %param = @_;
    my $blog;
    unless ( $blog = $param{Blog} ) {
        my $blog_id = $param{BlogID};
        $blog = MT::Blog->load($blog_id)
            or return $mt->error(
            MT->translate(
                "Loading of blog '[_1]' failed: [_2]", $blog_id,
                MT::Blog->errstr
            )
            );
    }
    return 1 if $blog->is_dynamic;

    require MT::Util::Log;
    MT::Util::Log::init();

    MT::Util::Log->info('--- Start rebuild.');

    my $at = $blog->archive_type || '';
    my @at = split /,/, $at;
    my $entry_class;
    if ( my $set_at = $param{ArchiveType} ) {
        my %at = map { $_ => 1 } @at;
        return $mt->error(
            MT->translate(
                "Archive type '[_1]' is not a chosen archive type", $set_at
            )
        ) unless $at{$set_at};

        @at = ($set_at);
        my $archiver = $mt->archiver($set_at);
        $entry_class = $archiver->entry_class || "entry";
    }
    else {
        $entry_class = '*';
    }

    if (   $param{ArchiveType}
        && ( !$param{Entry} )
        && ( $param{ArchiveType} eq 'Category' ) )
    {

        # Pass to full category rebuild
        return $mt->rebuild_categories(%param);
    }

    if (   $param{ArchiveType}
        && ( !$param{Author} )
        && ( $param{ArchiveType} eq 'Author' ) )
    {
        return $mt->rebuild_authors(%param);
    }

    my @entry_at = grep { $_ !~ /^ContentType/ } @at;
    my @ct_at    = grep { $_ =~ /^ContentType/ } @at;
    if (@entry_at) {
        require MT::Entry;
        my %arg = ( 'sort' => 'authored_on', direction => 'descend' );
        $arg{offset} = $param{Offset} if $param{Offset};
        $arg{limit}  = $param{Limit}  if $param{Limit};
        my $pre_iter = MT::Entry->load_iter(
            {   blog_id => $blog->id,
                class   => $entry_class,
                status  => MT::Entry::RELEASE()
            },
            \%arg
        );
        my ( $next, $curr );
        my $prev = $pre_iter->();
        my $iter = sub {
            ( $next, $curr ) = ( $curr, $prev );
            if ($curr) {
                $prev = $pre_iter->();
            }
            $curr;
        };
        my $cb  = $param{EntryCallback};
        my $fcb = $param{FilterCallback};
        while ( my $entry = $iter->() ) {
            if ($cb) {
                $cb->($entry)
                    or $mt->log(
                    {   message  => $cb->errstr(),
                        category => 'callback',
                    }
                    );
            }
            if ($fcb) {
                $fcb->($entry) or last;
            }
            for my $at (@entry_at) {
                my $archiver = $mt->archiver($at);

                # Skip this archive type if the archive type doesn't
                # match the kind of entry we've loaded
                next unless $archiver;
                next if $entry->class ne $archiver->entry_class;
                if ( $archiver->category_based ) {
                    my $cats = $entry->categories;
                CATEGORY: for my $cat (@$cats) {
                        next CATEGORY
                            if $archiver->category_class ne $cat->class_type;
                        $mt->_rebuild_entry_archive_type(
                            Entry       => $entry,
                            Blog        => $blog,
                            Category    => $cat,
                            ArchiveType => $at,
                            NoStatic    => $param{NoStatic},
                            Force       => ( $param{Force} ? 1 : 0 ),
                            $param{TemplateMap}
                            ? ( TemplateMap => $param{TemplateMap} )
                            : (),
                            $param{TemplateID}
                            ? ( TemplateID =>
                                    $param{TemplateID} )
                            : (),
                        ) or return;
                    }
                }
                elsif ( $archiver->author_based ) {
                    if ( $entry->author ) {
                        $mt->_rebuild_entry_archive_type(
                            Entry       => $entry,
                            Blog        => $blog,
                            ArchiveType => $at,
                            $param{TemplateMap}
                            ? ( TemplateMap => $param{TemplateMap} )
                            : (),
                            $param{TemplateID}
                            ? ( TemplateID =>
                                    $param{TemplateID} )
                            : (),
                            NoStatic => $param{NoStatic},
                            Force    => ( $param{Force} ? 1 : 0 ),
                            Author   => $entry->author,
                        ) or return;
                    }
                }
                else {
                    $mt->_rebuild_entry_archive_type(
                        Entry       => $entry,
                        Blog        => $blog,
                        ArchiveType => $at,
                        $param{TemplateMap}
                        ? ( TemplateMap => $param{TemplateMap} )
                        : (),
                        $param{TemplateID}
                        ? ( TemplateID =>
                                $param{TemplateID} )
                        : (),
                        NoStatic => $param{NoStatic},
                        Force    => ( $param{Force} ? 1 : 0 ),
                    ) or return;
                }
            }
        }
    }
    if (@ct_at) {
        require MT::ContentData;
        my %arg = ( 'sort' => 'authored_on', direction => 'descend' );
        $arg{offset} = $param{Offset} if $param{Offset};
        $arg{limit}  = $param{Limit}  if $param{Limit};
        my $pre_iter = MT::ContentData->load_iter(
            {   blog_id => $blog->id,
                status  => MT::Entry::RELEASE()
            },
            \%arg
        );
        my ( $next, $curr );
        my $prev = $pre_iter->();
        my $iter = sub {
            ( $next, $curr ) = ( $curr, $prev );
            if ($curr) {
                $prev = $pre_iter->();
            }
            $curr;
        };
        my $cb  = $param{ContentCallback};
        my $fcb = $param{FilterCallback};
        while ( my $content_data = $iter->() ) {
            if ($cb) {
                $cb->($content_data)
                    or $mt->log(
                    {   message  => $cb->errstr(),
                        category => 'callback',
                    }
                    );
            }
            if ($fcb) {
                $fcb->($content_data) or last;
            }
            for my $at (@ct_at) {
                my $archiver = $mt->archiver($at);

                # Skip this archive type if the archive type doesn't
                # match the kind of entry we've loaded
                next unless $archiver;

                if ( $archiver->contenttype_category_based ) {
                    my @cat_cfs = MT::ContentField->load(
                        {   type            => 'categories',
                            content_type_id => $content_data->content_type_id,
                        }
                    );
                    foreach my $cat_cf (@cat_cfs) {
                        my @obj_cats = MT::ObjectCategory->load(
                            {   object_ds => 'content_field',
                                object_id => $cat_cf->id,
                            }
                        );
                        foreach my $obj_cat (@obj_cats) {
                            my ($cat)
                                = MT::Category->load( $obj_cat->category_id );
                            $mt->_rebuild_content_archive_type(
                                ContentData => $content_data,
                                Blog        => $blog,
                                Category    => $cat,
                                ArchiveType => $at,
                                NoStatic    => $param{NoStatic},
                                Force       => ( $param{Force} ? 1 : 0 ),
                                $param{TemplateMap}
                                ? ( TemplateMap => $param{TemplateMap} )
                                : (),
                                $param{TemplateID}
                                ? ( TemplateID =>
                                        $param{TemplateID} )
                                : (),
                            ) or return;
                        }
                    }
                }
                elsif ( $archiver->contenttype_author_based ) {
                    $mt->_rebuild_content_archive_type(
                        ContentData => $content_data,
                        Blog        => $blog,
                        ArchiveType => $at,
                        $param{TemplateMap}
                        ? ( TemplateMap => $param{TemplateMap} )
                        : (),
                        $param{TemplateID}
                        ? ( TemplateID =>
                                $param{TemplateID} )
                        : (),
                        NoStatic => $param{NoStatic},
                        Force    => ( $param{Force} ? 1 : 0 ),
                        Author   => $content_data->author,
                    ) or return;
                }
                else {
                    $mt->_rebuild_content_archive_type(
                        ContentData => $content_data,
                        Blog        => $blog,
                        ArchiveType => $at,
                        $param{TemplateMap}
                        ? ( TemplateMap => $param{TemplateMap} )
                        : (),
                        $param{TemplateID}
                        ? ( TemplateID =>
                                $param{TemplateID} )
                        : (),
                        NoStatic => $param{NoStatic},
                        Force    => ( $param{Force} ? 1 : 0 ),
                    ) or return;
                }
            }
        }
    }
    unless ( $param{NoIndexes} ) {
        $mt->rebuild_indexes( Blog => $blog, NoStatic => $param{NoStatic}, )
            or return;
    }
    MT::Util::Log->info('--- End   rebuild.');
    1;
}

sub rebuild_categories {
    my $mt = shift;
    $mt->SUPER::rebuild_categories(@_);
}

sub rebuild_authors {
    my $mt = shift;
    $mt->SUPER::rebuild_authors(@_);
}

sub rebuild_deleted_entry {
    my $mt = shift;
    $mt->SUPER::rebuild_deleted_entry(@_);
}

sub rebuild_entry {
    my $mt = shift;
    $mt->SUPER::rebuild_entry(@_);
}

sub rebuild_archives {
    my $mt = shift;
    $mt->SUPER::rebuild_archives(@_);
}

sub rebuild_file {
    my $mt = shift;
    my ( $blog, $root_path, $map, $at, $ctx, $cond, $build_static, %args )
        = @_;
    my $finfo;
    my $archiver = $mt->archiver($at);
    my ( $entry, $start, $end, $category, $author, $content_data );

    if ( $finfo = $args{FileInfo} ) {
        $args{Author}   = $finfo->author_id   if $finfo->author_id;
        $args{Category} = $finfo->category_id if $finfo->category_id;
        $args{Entry}    = $finfo->entry_id    if $finfo->entry_id;
        $map ||= MT::TemplateMap->load( $finfo->templatemap_id );
        $at  ||= $finfo->archive_type;
        if ( $finfo->startdate ) {
            if ( ( $start, $end )
                = $archiver->date_range( $finfo->startdate ) )
            {
                $args{StartDate} = $start;
                $args{EndDate}   = $end;
            }
        }
    }

    # Calculate file path and URL for the new entry.
    my $file = File::Spec->catfile( $root_path, $map->{__saved_output_file} );

    ## Untaint. We have to assume that we can trust the user's setting of
    ## the archive_path, and nothing else is based on user input.
    ($file) = $file =~ /(.+)/s;

    # compare file modification time to start of build process. if it
    # is greater than the start_time, then we shouldn't need to build this
    # file again
    my $fmgr = $blog->file_mgr;
    if ( UNIVERSAL::isa( MT->instance, 'MT::App' ) ) {
        my $mod_time = $fmgr->file_mod_time($file);
        return 1 if $mod_time && $mod_time >= $mt->start_time;
    }

    if ( $archiver->category_based || $archiver->contenttype_category_based )
    {
        $category = $args{Category};
        die "Category archive type requires Category parameter"
            unless $args{Category};
        $category = MT::Category->load($category)
            unless ref $category;
        $ctx->var( 'category_archive', 1 );
        $ctx->{__stash}{archive_category} = $category;
    }
    if ( $archiver->entry_based ) {
        $entry = $args{Entry};
        die "$at archive type requires Entry parameter"
            unless $entry;
        require MT::Entry;
        $entry = MT::Entry->load($entry) if !ref $entry;
        $ctx->var( 'entry_archive', 1 );
        $ctx->{__stash}{entry} = $entry;
    }
    if ( $archiver->date_based ) {

        # Date-based archive type
        $start = $args{StartDate};
        $end   = $args{EndDate};
        Carp::confess("Date-based archive types require StartDate parameter")
            unless $args{StartDate};
        $ctx->var( 'datebased_archive', 1 );
    }
    if ( $archiver->author_based ) {

        # author based archive type
        $author = $args{Author};
        die "Author-based archive type requires Author parameter"
            unless $args{Author};
        require MT::Author;
        $author = MT::Author->load($author)
            unless ref $author;
        $ctx->var( 'author_archive', 1 );
        $ctx->{__stash}{author} = $author;
    }
    if ( $archiver->contenttype_based ) {
        $content_data = $args{ContentData};
        die "$at archive type requires ContentData parameter"
            unless $content_data;
        require MT::ContentData;
        $content_data = MT::ContentData->load($content_data)
            if !ref $content_data;
        $ctx->var( 'content_archive', 1 );
        $ctx->{__stash}{content} = $content_data;
    }
    local $ctx->{current_timestamp}     = $start if $start;
    local $ctx->{current_timestamp_end} = $end   if $end;

    $ctx->{__stash}{blog}          = $blog;
    $ctx->{__stash}{local_blog_id} = $blog->id;

    require MT::FileInfo;

# This kind of testing should be done at the time we save a post,
# not during publishing!!!
# if ($archiver->entry_based) {
#     my $fcount = MT::FileInfo->count({
#         blog_id => $blog->id,
#         entry_id => $entry->id,
#         file_path => $file},
#         { not => { entry_id => 1 } });
#     die MT->translate('The same archive file exists. You should change the basename or the archive path. ([_1])', $file) if $fcount > 0;
# }

    my $base_url = $blog->archive_url;
    $base_url = $blog->site_url
        if $archiver->entry_based && $archiver->entry_class eq 'page';
    $base_url .= '/' unless $base_url =~ m|/$|;
    my $url = $base_url . $map->{__saved_output_file};
    $url =~ s{(?<!:)//+}{/}g;

    my $tmpl_id = $map->template_id;

    # template specific for this entry (or page, as the case may be)
    if ( $entry && $entry->template_id ) {

        # allow entry to override *if* we're publishing an individual
        # page, and this is the 'preferred' one...
        if ( $archiver->entry_based ) {
            if ( $map->is_preferred ) {
                $tmpl_id = $entry->template_id;
            }
        }
    }

    my $tmpl = MT::Template->load($tmpl_id);
    return 1 if $tmpl->type eq 'backup';
    $tmpl->context($ctx);

    # From Here
    if ( my $tmpl_param = $archiver->template_params ) {
        $tmpl->param($tmpl_param);
    }

    my ($rel_url) = ( $url =~ m|^(?:[^:]*\:\/\/)?[^/]*(.*)| );

    # Clear out all the FileInfo records that might point at the page
    # we're about to create
    # FYI: if it's an individual entry, we don't use the date as a
    #      criterion, since this could actually have changed since
    #      the FileInfo was last built. When the date does change,
    #      the old date-based archive doesn't necessarily get fixed,
    #      but if another comes along it will get corrected
    unless ($finfo) {
        my %terms;
        $terms{blog_id}     = $blog->id;
        $terms{category_id} = $category->id if $archiver->category_based;
        $terms{author_id}   = $author->id if $archiver->author_based;
        $terms{entry_id}    = $entry->id if $archiver->entry_based;
        $terms{startdate}   = $start
            if $archiver->date_based && ( !$archiver->entry_based );
        $terms{archive_type}   = $at;
        $terms{templatemap_id} = $map->id;
        my @finfos = MT::FileInfo->load( \%terms );

        if (   ( scalar @finfos == 1 )
            && ( $finfos[0]->file_path eq $file )
            && ( ( $finfos[0]->url || '' ) eq $rel_url )
            && ( $finfos[0]->template_id == $tmpl_id ) )
        {

            # if the shoe fits, wear it
            $finfo = $finfos[0];
        }
        else {

         # if the shoe don't fit, remove all shoes and create the perfect shoe
            foreach (@finfos) { $_->remove(); }

            $finfo = MT::FileInfo->set_info_for_url(
                $rel_url, $file, $at,
                {   Blog        => $blog->id,
                    TemplateMap => $map->id,
                    Template    => $tmpl_id,
                    ( $archiver->entry_based && $entry )
                    ? ( Entry => $entry->id )
                    : (),
                    StartDate => $start,
                    ( $archiver->category_based && $category )
                    ? ( Category => $category->id )
                    : (),
                    ( $archiver->author_based ) ? ( Author => $author->id )
                    : (),
                }
                )
                || die "Couldn't create FileInfo because "
                . MT::FileInfo->errstr();
        }
    }

    if (!$archiver->does_publish_file(
            {   Blog        => $blog,
                ArchiveType => $at,
                Entry       => $entry,
                Category    => $category,
                Author      => $author,
                Timestamp   => $start,
            }
        )
        )
    {
        $finfo->remove();
        if ( MT->config->DeleteFilesAtRebuild ) {
            $mt->_delete_archive_file(
                Blog        => $blog,
                File        => $finfo->file_path,
                ArchiveType => $at
            );
        }

        return 1;
    }

    # If you rebuild when you've just switched to dynamic pages,
    # we move the file that might be there so that the custom
    # 404 will be triggered.
    require MT::PublishOption;
    if ( $map->build_type == MT::PublishOption::DYNAMIC() ) {
        MT->run_callbacks(
            'build_dynamic',
            Context      => $ctx,
            context      => $ctx,
            ArchiveType  => $at,
            archive_type => $at,
            TemplateMap  => $map,
            template_map => $map,
            Blog         => $blog,
            blog         => $blog,
            Entry        => $entry,
            entry        => $entry,
            FileInfo     => $finfo,
            file_info    => $finfo,
            File         => $file,
            file         => $file,
            Template     => $tmpl,
            template     => $tmpl,
            PeriodStart  => $start,
            period_start => $start,
            Category     => $category,
            category     => $category,
        );

        rename(
            $finfo->file_path,    # is this just $file ?
            $finfo->file_path . '.static'
        );

        ## If the FileInfo is set to static, flip it to virtual.
        if ( !$finfo->virtual ) {
            $finfo->virtual(1);
            $finfo->save();
        }
    }

    return 1 if ( $map->build_type == MT::PublishOption::DYNAMIC() );
    return 1 if ( $entry && $entry->status != MT::Entry::RELEASE() );
    return 1 unless ( $map->build_type );

    my $timer = MT->get_timer;
    if ($timer) {
        $timer->pause_partial;
    }
    local $timer->{elapsed} = 0 if $timer;

    if ($build_static
        && MT->run_callbacks(
            'build_file_filter',
            Context      => $ctx,
            context      => $ctx,
            ArchiveType  => $at,
            archive_type => $at,
            TemplateMap  => $map,
            template_map => $map,
            Blog         => $blog,
            blog         => $blog,
            Entry        => $entry,
            entry        => $entry,
            FileInfo     => $finfo,
            file_info    => $finfo,
            File         => $file,
            file         => $file,
            Template     => $tmpl,
            template     => $tmpl,
            PeriodStart  => $start,
            period_start => $start,
            Category     => $category,
            category     => $category,
            force        => ( $args{Force} ? 1 : 0 ),
        )
        )
    {

        if ( $archiver->group_based ) {
            require MT::Promise;
            my $entries = sub { $archiver->archive_group_entries($ctx) };
            $ctx->stash( 'entries', MT::Promise::delay($entries) );
        }

        my $html = undef;
        $ctx->stash( 'blog', $blog );
        $ctx->stash( 'entry', $entry ) if $entry;
        $ctx->stash( '_basename',
            fileparse( $map->{__saved_output_file}, qr/\.[^.]*/ ) );
        $ctx->stash( 'current_mapping_url', $url );

        if ( !$map->is_preferred ) {
            my $category = $ctx->{__stash}{archive_category};
            my $author   = $ctx->{__stash}{author};
            $ctx->stash(
                'preferred_mapping_url',
                sub {
                    my $file = $mt->archive_file_for( $entry, $blog, $at,
                        $category, undef, $start, $author );
                    my $url = $base_url . $file;
                    $url =~ s{(?<!:)//+}{/}g;
                    $url;
                }
            );
        }

        require MT::Request;
        MT::Request->instance->cache( 'build_template', $tmpl );

        $html = $tmpl->build( $ctx, $cond );
        unless ( defined($html) ) {
            $timer->unpause if $timer;
            return $mt->error(
                (   $category ? MT->translate(
                        "An error occurred publishing [_1] '[_2]': [_3]",
                        lc( $category->class_label ),
                        $category->label,
                        $tmpl->errstr
                        )
                    : $entry ? MT->translate(
                        "An error occurred publishing [_1] '[_2]': [_3]",
                        lc( $entry->class_label ),
                        $entry->title,
                        $tmpl->errstr
                        )
                    : MT->translate(
                        "An error occurred publishing date-based archive '[_1]': [_2]",
                        $at . $start,
                        $tmpl->errstr
                    )
                )
            );
        }

        # Some browsers throw you to quirks mode if the doctype isn't
        # up front and leading whitespace makes a feed invalid.
        $html =~ s/\A\s+(<(?:\?xml|!DOCTYPE))/$1/s;

        my $orig_html = $html;
        MT->run_callbacks(
            'build_page',
            Context      => $ctx,
            context      => $ctx,
            ArchiveType  => $at,
            archive_type => $at,
            TemplateMap  => $map,
            template_map => $map,
            Blog         => $blog,
            blog         => $blog,
            Entry        => $entry,
            entry        => $entry,
            FileInfo     => $finfo,
            file_info    => $finfo,
            PeriodStart  => $start,
            period_start => $start,
            Category     => $category,
            category     => $category,
            RawContent   => \$orig_html,
            raw_content  => \$orig_html,
            Content      => \$html,
            content      => \$html,
            BuildResult  => \$orig_html,
            build_result => \$orig_html,
            Template     => $tmpl,
            template     => $tmpl,
            File         => $file,
            file         => $file
        );
        ## First check whether the content is actually
        ## changed. If not, we won't update the published
        ## file, so as not to modify the mtime.
        unless ( $fmgr->content_is_updated( $file, \$html ) ) {
            $timer->unpause if $timer;
            return 1;
        }

        ## Determine if we need to build directory structure,
        ## and build it if we do. DirUmask determines
        ## directory permissions.
        require File::Spec;
        my $path = dirname($file);
        $path =~ s!/$!!
            unless $path eq '/'; ## OS X doesn't like / at the end in mkdir().
        unless ( $fmgr->exists($path) ) {
            if ( !$fmgr->mkpath($path) ) {
                $timer->unpause if $timer;
                return $mt->trans_error( "Error making path '[_1]': [_2]",
                    $path, $fmgr->errstr );
            }
        }

        ## By default we write all data to temp files, then rename
        ## the temp files to the real files (an atomic
        ## operation). Some users don't like this (requires too
        ## liberal directory permissions). So we have a config
        ## option to turn it off (NoTempFiles).
        my $use_temp_files = !$mt->{NoTempFiles};
        my $temp_file = $use_temp_files ? "$file.new" : $file;
        unless ( defined $fmgr->put_data( $html, $temp_file ) ) {
            $timer->unpause if $timer;
            return $mt->trans_error( "Writing to '[_1]' failed: [_2]",
                $temp_file, $fmgr->errstr );
        }
        if ($use_temp_files) {
            if ( !$fmgr->rename( $temp_file, $file ) ) {
                $timer->unpause if $timer;
                return $mt->trans_error(
                    "Renaming tempfile '[_1]' failed: [_2]",
                    $temp_file, $fmgr->errstr );
            }
        }
        MT->run_callbacks(
            'build_file',
            Context      => $ctx,
            context      => $ctx,
            ArchiveType  => $at,
            archive_type => $at,
            TemplateMap  => $map,
            template_map => $map,
            FileInfo     => $finfo,
            file_info    => $finfo,
            Blog         => $blog,
            blog         => $blog,
            Entry        => $entry,
            entry        => $entry,
            PeriodStart  => $start,
            period_start => $start,
            RawContent   => \$orig_html,
            raw_content  => \$orig_html,
            Content      => \$html,
            content      => \$html,
            BuildResult  => \$orig_html,
            build_result => \$orig_html,
            Template     => $tmpl,
            template     => $tmpl,
            Category     => $category,
            category     => $category,
            File         => $file,
            file         => $file
        );
    }
    $timer->mark( "total:rebuild_file[template_id:" . $tmpl->id . "]" )
        if $timer;

    require MT::Util::Log;
    MT::Util::Log::init();

    MT::Util::Log->info( ' Rebuilded ' . $file );

    1;
}

sub rebuild_indexes {
    my $mt = shift;
    $mt->SUPER::rebuild_indexes(@_);
}

sub rebuild_from_fileinfo {
    my $mt = shift;
    $mt->SUPER::rebuild_from_fileinfo(@_);
}

sub _rebuild_content_archive_type {
    my $mt    = shift;
    my %param = @_;

    my $at = $param{ArchiveType}
        or return $mt->error(
        MT->translate( "Parameter '[_1]' is required", 'ArchiveType' ) );
    return 1 if $at eq 'None';
    my $content_data
        = (    $param{ArchiveType} ne 'Content-Category'
            && $param{ArchiveType} ne 'Content-Author'
            && !exists $param{Start}
            && !exists $param{End} )
        ? (
        $param{ContentData}
            or return $mt->error(
            MT->translate( "Parameter '[_1]' is required", 'ContentData' )
            )
        )
        : undef;

    my $blog;
    unless ( $blog = $param{Blog} ) {
        my $blog_id = $content_data->blog_id;
        $blog = MT::Blog->load($blog_id)
            or return $mt->error(
            MT->translate(
                "Load of blog '[_1]' failed: [_2]", $blog_id,
                MT::Blog->errstr
            )
            );
    }

    ## Load the template-archive-type map entries for this blog and
    ## archive type. We do this before we load the list of entries, because
    ## we will run through the files and check if we even need to rebuild
    ## anything. If there is nothing to rebuild at all for this entry,
    ## we save some time by not loading the list of entries.
    require MT::TemplateMap;
    my @map;
    if ( $param{TemplateMap} ) {
        @map = ( $param{TemplateMap} );
    }
    else {
        my $cached_maps = MT->instance->request('__cached_maps')
            || MT->instance->request( '__cached_maps', {} );
        if ( my $maps = $cached_maps->{ $at . $blog->id } ) {
            @map = @$maps;
        }
        else {
            @map = MT::TemplateMap->load(
                {   archive_type => $at,
                    blog_id      => $blog->id,
                    $param{TemplateID} ? ( template_id => $param{TemplateID} )
                    : (),
                    $content_data
                    ? ( content_type_id => $content_data->content_type_id )
                    : (),
                }
            );
            $cached_maps->{ $at . $blog->id } = \@map;
        }
    }
    return 1 unless @map;

    my @map_build;
    my $done = MT->instance->request( '__published:' . $blog->id )
        || MT->instance->request( '__published:' . $blog->id, {} );
    for my $map (@map) {
        my $ts;
        my $dt_field_id = $map->dt_field_id;
        if ($dt_field_id) {
            my $data = $content_data->data;
            $ts = $data->{$dt_field_id};
        }

        my $file
            = exists $param{File}
            ? $param{File}
            : $mt->archive_file_for( $content_data, $blog, $at,
            $param{Category}, $map, $ts, $param{Author} );
        if ( $file eq '' ) {

            # np
        }
        elsif ( !defined($file) ) {
            return $mt->error( MT->translate( $blog->errstr() ) );
        }
        else {
            push @map_build, $map unless $done->{$file};
            $map->{__saved_output_file} = $file;
        }
    }
    return 1 unless @map_build;
    @map = @map_build;

    $at ||= "";

    my $archiver = $mt->archiver($at);
    return unless $archiver;

    # Special handling for pages-- they are always published to the
    # 'site' path instead of the 'archive' path, which is reserved for blog
    # content.
    my $arch_root
        = ( $at eq 'Page' ) ? $blog->site_path : $blog->archive_path;
    return $mt->error(
        MT->translate("You did not set your blog publishing path") )
        unless $arch_root;

    my ( $start, $end );
    if ( exists $param{Start} && exists $param{End} ) {
        $start = $param{Start};
        $end   = $param{End};
    }
    else {
        if ( $archiver->date_based() && $archiver->can('date_range') ) {
            ( $start, $end )
                = $archiver->date_range( $content_data->authored_on );
        }
    }

    ## For each mapping, we need to rebuild the entries we loaded above in
    ## the particular template map, and write it to the specified archive
    ## file template.
    require MT::Template;
    require MT::Template::Context;
    require MT::PublishOption;

    my $force = $param{Force};
    for my $map (@map) {
        next unless $map->build_type;    # ignore disabled template maps
        next if $map->build_type == MT::PublishOption::MANUALLY() && !$force;

        my $ctx = MT::Template::Context->new;
        $ctx->{current_archive_type} = $at;
        $ctx->{archive_type}         = $at;
        $mt->rebuild_file(
            $blog, $arch_root, $map, $at, $ctx, \my %cond,
            !$param{NoStatic},
            Category    => $param{Category},
            ContentData => $content_data,
            Author      => $param{Author},
            StartDate   => $start,
            EndDate     => $end,
            Force       => $param{Force} ? 1 : 0,
        ) or return;
        $done->{ $map->{__saved_output_file} }++;
    }
    1;
}

{
    my %tokens_cache;

    sub archive_file_cache_key {
        my $mt = shift;
        my ( $obj, $blog, $at, $cat, $map, $timestamp, $author ) = @_;

        return join ':',
            (
            $obj       ? $obj->id    : '0',
            $blog      ? $blog->id   : '0',
            $at        ? $at         : 'None',
            $cat       ? $cat->id    : '0',
            $map       ? $map->id    : '0',
            $timestamp ? $timestamp  : '0',
            $author    ? $author->id : '0'
            );
    }

    sub archive_file_for {
        my $mt = shift;
        init_archive_types() unless %ArchiveTypes;

        my ( $obj, $blog, $at, $cat, $map, $timestamp, $author ) = @_;
        return if $at eq 'None';
        my $archiver = $mt->archiver($at);
        return '' unless $archiver;

        my $file;
        my $cache_file = MT::Request->instance->cache('file');
        unless ($cache_file) {
            MT::Request->instance->cache( 'file', $cache_file = {} );
        }
        my $cache_key = $mt->archive_file_cache_key(@_);
        if ( $file = $cache_file->{$cache_key} ) {
            return $file;
        }

        if ( $blog->is_dynamic ) {
            require MT::TemplateMap;
            $map = MT::TemplateMap->new;
            $map->file_template( $archiver->dynamic_template );
        }
        unless ($map) {
            my $cache_map = MT::Request->instance->cache('maps');
            unless ($cache_map) {
                MT::Request->instance->cache( 'maps', $cache_map = {} );
            }
            unless ( $map = $cache_map->{ $blog->id . $at } ) {
                require MT::TemplateMap;
                $map = MT::TemplateMap->load(
                    {   blog_id      => $blog->id,
                        archive_type => $at,
                        is_preferred => 1
                    }
                );
                $cache_map->{ $blog->id . $at } = $map if $map;
            }
        }
        my $file_tmpl;
        $file_tmpl = $map->file_template if $map;
        unless ($file_tmpl) {
            if ( my $tmpls = $archiver->default_archive_templates ) {
                my ($default) = grep { $_->{default} } @$tmpls;
                $file_tmpl = $default->{template} if $default;
            }
        }
        $file_tmpl ||= '';
        my ($ctx);
        if ( $file_tmpl =~ m/\%[_-]?[A-Za-z]/ ) {
            if ( $file_tmpl =~ m/<\$?MT/i ) {
                $file_tmpl
                    =~ s!(<\$?MT[^>]+?>)|(%[_-]?[A-Za-z])!$1 ? $1 : '<MTFileTemplate format="'. $2 . '">'!gie;
            }
            else {
                $file_tmpl = qq{<MTFileTemplate format="$file_tmpl">};
            }
        }
        if ($file_tmpl) {
            require MT::Template::Context;
            $ctx = MT::Template::Context->new;
            $ctx->stash( 'blog', $blog );
        }
        local $ctx->{__stash}{category}         = $cat if $cat;
        local $ctx->{__stash}{archive_category} = $cat if $cat;
        $timestamp = $obj->authored_on() if $obj && !$timestamp;
        local $ctx->{__stash}{entry} = $obj
            if $obj && ref $obj eq 'MT::Entry';
        local $ctx->{__stash}{content} = $obj
            if $obj && ref $obj eq 'MT::ContentData';
        local $ctx->{__stash}{author}
            = $author ? $author : $obj ? $obj->author : undef;

        my %blog_at = map { $_ => 1 } split /,/, $blog->archive_type;
        return '' unless $blog_at{$at};

        $file = $archiver->archive_file(
            $ctx,
            Timestamp => $timestamp,
            Template  => $file_tmpl
        );
        if ( $file_tmpl && !$file ) {
            local $ctx->{archive_type} = $at;
            require MT::Builder;
            my $build  = MT::Builder->new;
            my $tokens = $tokens_cache{$file_tmpl}
                ||= $build->compile( $ctx, $file_tmpl )
                or return $blog->error( $build->errstr() );
            defined( $file = $build->build( $ctx, $tokens ) )
                or return $blog->error( $build->errstr() );
        }
        else {
            my $ext = $blog->file_extension;
            $file .= '.' . $ext if $ext;
        }
        $cache_file->{$cache_key} = $file;
        $file;
    }
}

1;
