package MT::Test::Fixture;

use strict;
use warnings;
use Carp;
use MT::Test::Permission;
use MT::Serialize;
use MT::Association;
use Data::Visitor::Tiny;
use List::Util qw(uniq);

sub prepare {
    my ($class, $spec) = @_;

    local $ENV{MT_TEST_ROOT} = $ENV{MT_TEST_ROOT} || "$ENV{MT_HOME}/t";

    visit(
        $spec,
        sub {
            my ($key, $valueref) = @_;
            $$valueref =~ s/TEST_ROOT/$ENV{MT_TEST_ROOT}/g;
            $$valueref =~ s/MT_HOME/$ENV{MT_HOME}/g;
        });

    my %objs;
    $class->prepare_author($spec, \%objs);
    $class->prepare_website($spec, \%objs);
    $class->prepare_blog($spec, \%objs);
    $class->prepare_asset($spec, \%objs);
    $class->prepare_image($spec, \%objs);
    $class->prepare_tag($spec, \%objs);
    $class->prepare_category($spec, \%objs);
    $class->prepare_customfield($spec, \%objs);
    $class->prepare_entry($spec, \%objs);
    $class->prepare_folder($spec, \%objs);
    $class->prepare_page($spec, \%objs);
    $class->prepare_category_set($spec, \%objs);
    $class->prepare_content_type($spec, \%objs);
    $class->prepare_content_data($spec, \%objs);
    $class->prepare_role($spec, \%objs);
    $class->prepare_template($spec, \%objs);

    \%objs;
}

# TODO: support more variations

sub prepare_author {
    my ($class, $spec, $objs) = @_;
    if (!$spec->{author}) {
        my $author = MT::Author->load(1) or croak "No author";
        $objs->{author_id} = $author->id;
        return;
    }

    my @author_names;
    if (ref $spec->{author} eq 'ARRAY') {
        for my $item (@{ $spec->{author} }) {
            my %arg = ref $item eq 'HASH' ? %$item : (name => $item);
            $arg{nickname} ||= $arg{name};
            delete $arg{roles};    ## not for now
            my $permissions = delete $arg{permissions};
            my $author      = MT::Test::Permission->make_author(%arg);
            if (!defined $arg{is_superuser} or $arg{is_superuser}) {
                $author->is_superuser(1);
                $author->save;
            }
            $objs->{author}{ $author->name } = $author;
            push @author_names, $author->name;

            if ($permissions) {
                my $perm = $author->permissions(0);
                $perm->set_these_permissions($permissions);
                $perm->save;
            }
        }
    }
    if (@author_names == 1) {
        $objs->{author_id} = $objs->{author}{ $author_names[0] }->id;
    }
}

sub prepare_website {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{website};

    my @site_names;
    if (ref $spec->{website} eq 'ARRAY') {
        for my $item (@{ $spec->{website} }) {
            my %arg     = ref $item eq 'HASH' ? %$item : (name => $item);
            my $authors = delete $arg{authors};

            my $site = MT::Test::Permission->make_website(%arg);
            $objs->{website}{ $site->name } = $site;
            push @site_names, $site->name;

            if ($authors) {
                for my $author_name (@$authors) {
                    my $author = $objs->{author}{$author_name} or croak "unknown author: $author_name";
                    MT::Association->link($site, $author);
                }
            }
        }
    }
    if (@site_names == 1) {
        $objs->{blog_id} = $objs->{website}{ $site_names[0] }->id;
    }
}

sub prepare_blog {
    my ($class, $spec, $objs) = @_;
    if (!$spec->{blog}) {
        if (my $blog_id = $spec->{blog_id}) {
            $objs->{blog_id} = $blog_id;
        }
        return;
    }

    my @blog_names;
    if (ref $spec->{blog} eq 'ARRAY') {
        for my $item (@{ $spec->{blog} }) {
            my %arg     = ref $item eq 'HASH' ? %$item : (name => $item);
            my $authors = delete $arg{authors};

            if (my $parent_name = delete $arg{parent}) {
                my $parent = $objs->{website}{$parent_name} or croak "unknown parent: $parent_name";
                $arg{parent_id} = $parent->id;
            }

            my $blog = MT::Test::Permission->make_blog(%arg);
            $objs->{blog}{ $blog->name } = $blog;
            push @blog_names, $blog->name;

            if ($authors) {
                for my $author_name (@$authors) {
                    my $author = $objs->{author}{$author_name} or croak "unknown author: $author_name";
                    MT::Association->link($blog, $author);
                }
            }
        }
    }
    if ($objs->{blog_id} && @blog_names) {
        delete $objs->{blog_id};
    } elsif (@blog_names == 1) {
        $objs->{blog_id} = $objs->{blog}{ $blog_names[0] }->id;
    }
}

sub prepare_image {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{image};

    require MT::Test::Image;
    require Image::ExifTool;
    require File::Path;
    require File::Basename;

    my $image_dir = "$ENV{MT_TEST_ROOT}/images";
    File::Path::mkpath($image_dir) unless -d $image_dir;

    if (ref $spec->{image} eq 'HASH') {
        for my $name (sort keys %{ $spec->{image} }) {
            my $item = $spec->{image}{$name};
            if (ref $item eq 'HASH') {
                my $blog_id = _find_blog_id($objs, $item);
                my $file = "$image_dir/$name";
                my $dir  = File::Basename::dirname($file);
                File::Path::mkpath($dir) unless -d $dir;
                MT::Test::Image->write(file => $file);
                my $info = Image::ExifTool::ImageInfo($file);
                my %args = (
                    class        => 'image',
                    blog_id      => $blog_id,
                    url          => "%s/images/$name",
                    file_path    => $file,
                    file_ext     => $info->{FileTypeExtension},
                    image_width  => $info->{ImageWidth},
                    image_height => $info->{ImageHeight},
                    mime_type    => $info->{MIMEType},
                    %$item,
                );

                if (my $parent_name = delete $args{parent}) {
                    my $parent = $objs->{image}{$parent_name}
                        or croak "unknown parent image: $parent_name";
                    $args{parent} = $parent->id;
                }
                my $image = MT::Test::Permission->make_asset(%args);
                $objs->{image}{$name} = $image;
            }
        }
    }
}

sub prepare_asset {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{asset};

    require File::Path;

    my $asset_dir = "$ENV{MT_TEST_ROOT}/assets";
    File::Path::mkpath($asset_dir) unless -d $asset_dir;

    if (ref $spec->{asset} eq 'ARRAY') {
        $spec->{asset} = { map { $_ => {} } @{ $spec->{asset} } };
    }
    if (ref $spec->{asset} eq 'HASH') {
        for my $name (sort keys %{ $spec->{asset} }) {
            my $item = $spec->{asset}{$name};
            if (ref $item eq 'HASH') {
                my $blog_id = _find_blog_id($objs, $item)
                    or croak "blog_id is required: asset";
                my $asset_class = delete $item->{class} || _get_asset_class($name);
                my $file        = "$asset_dir/$name";
                my ($ext)       = $name =~ /(\.[^.]*)\z/;
                if ($asset_class eq 'image' && !$item->{body}) {
                    require MT::Test::Image;
                    MT::Test::Image->write(file => $file);
                } else {
                    my $body = delete $item->{body} || $name;
                    open my $fh, '>', $file;
                    print $fh $body;
                    close $fh;
                }
                my %args = (
                    class     => $asset_class,
                    blog_id   => $blog_id,
                    url       => "%s/assets/$name",
                    file_path => $file,
                    file_ext  => $ext,
                    %$item,
                );

                if (my $parent_name = delete $args{parent}) {
                    my $parent = $objs->{$asset_class}{$parent_name}
                        or croak "unknown parent asset: $parent_name";
                    $args{parent} = $parent->id;
                }
                my $asset = MT::Test::Permission->make_asset(%args);
                $objs->{$asset_class}{$name} = $asset;
            }
        }
    }
}

sub _get_asset_class {
    my $name = shift;
    my ($class) = MT::Asset->handler_for_file($name) =~ /(\w+)$/;
    lc($class || 'asset');
}

sub prepare_tag {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{tag};

    if (ref $spec->{tag} eq 'ARRAY') {
        for my $item (@{ $spec->{tag} }) {
            my %arg;
            if (ref $item eq 'HASH') {
                %arg = %$item;
            } else {
                %arg = (name => $item);
            }
            my $tag = MT::Test::Permission->make_tag(%arg);
            $objs->{tag}{ $tag->name } = $tag;
        }
    }
}

sub prepare_category {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{category};

    if (ref $spec->{category} eq 'ARRAY') {
        for my $item (@{ $spec->{category} }) {
            my %arg;
            if (ref $item eq 'HASH') {
                %arg = %$item;
            } else {
                %arg = (label => $item);
            }
            my $blog_id = $arg{blog_id} ||= _find_blog_id($objs, \%arg)
                or croak "blog_id is required: category";
            if (my $parent_name = $arg{parent}) {
                my $parent = $objs->{category}{$parent_name}{$blog_id}
                    or croak "unknown parent category: $parent_name";
                $arg{parent} = $parent->id;
            }
            my $cat = MT::Test::Permission->make_category(%arg);
            $objs->{category}{ $cat->label }{$blog_id} = $cat;
        }
    }
}

sub prepare_folder {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{folder};

    if (ref $spec->{folder} eq 'ARRAY') {
        for my $item (@{ $spec->{folder} }) {
            my %arg;
            if (ref $item eq 'HASH') {
                %arg = %$item;
            } else {
                %arg = (label => $item);
            }
            my $blog_id = $arg{blog_id} ||= _find_blog_id($objs, \%arg)
                or croak "blog_id is required: folder";
            if (my $parent_name = $arg{parent}) {
                my $parent = $objs->{folder}{$parent_name}{$blog_id}
                    or croak "unknown parent folder: $parent_name";
                $arg{parent} = $parent->id;
            }
            my $folder = MT::Test::Permission->make_folder(%arg);
            $objs->{folder}{ $folder->label }{$blog_id} = $folder;
        }
    }
}

sub prepare_customfield {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{customfield};

    if (ref $spec->{customfield} eq 'ARRAY') {
        for my $item (@{ $spec->{customfield} }) {
            my %arg;
            if (ref $item eq 'HASH') {
                %arg = %$item;
            } else {
                %arg = (
                    name     => $item,
                    obj_type => 'entry',
                    type     => 'text',
                    basename => $item,
                    tag      => $item,
                );
            }
            $arg{blog_id} ||= _find_blog_id($objs, \%arg)
                or croak "blog_id is required: customfield";
            my $field = MT::Test::Permission->make_field(%arg);
            $objs->{customfield}{ $field->name } = $field;
        }
    }
}

sub prepare_entry {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{entry};

    if (ref $spec->{entry} eq 'ARRAY') {
        for my $item (@{ $spec->{entry} }) {
            my %arg;
            if (ref $item eq 'HASH') {
                %arg = %$item;
                my $status = $arg{status} || 'publish';
                if ($status =~ /\w+/) {
                    require MT::Entry;
                    $arg{status} = MT::Entry::status_int($status);
                }
            } else {
                %arg = (title => $item);
            }
            my $title     = $arg{title} || '(no title)';
            my @cat_names = @{ delete $arg{categories} || [] };
            my @tag_names = @{ delete $arg{tags}       || [] };

            my $blog_id = _find_blog_id($objs, \%arg)
                or croak "blog_id is required: entry: $title";
            my $author_id = _find_author_id($objs, \%arg)
                or croak "author_id is required: entry: $title";

            my $entry = MT::Test::Permission->make_entry(
                blog_id   => $blog_id,
                author_id => $author_id,
                %arg,
            );
            $objs->{entry}{ $entry->basename } = $entry;

            for my $cat_name (@cat_names) {
                my $category = $objs->{category}{$cat_name}{$blog_id}
                    or croak "unknown category: $cat_name entry: $title";
                MT::Test::Permission->make_placement(
                    blog_id     => $blog_id,
                    entry_id    => $entry->id,
                    category_id => $category->id,
                );
            }
            for my $tag_name (@tag_names) {
                my $tag = $objs->{tag}{$tag_name}
                    or croak "unknown tag: $tag_name entry: $title";
                MT::Test::Permission->make_objecttag(
                    blog_id           => $blog_id,
                    object_id         => $entry->id,
                    object_datasource => 'entry',
                    tag_id            => $tag->id,
                );
            }
        }
    }
}

sub prepare_page {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{page};

    if (ref $spec->{page} eq 'ARRAY') {
        for my $item (@{ $spec->{page} }) {
            my %arg;
            if (ref $item eq 'HASH') {
                %arg = %$item;
                my $status = $arg{status} || 'publish';
                if ($status =~ /\w+/) {
                    require MT::Entry;
                    $arg{status} = MT::Entry::status_int($status);
                }
            } else {
                %arg = (title => $item);
            }
            my $title       = $arg{title} || '(no title)';
            my $folder_name = delete $arg{folder};
            my @tag_names   = @{ delete $arg{tags} || [] };

            my $blog_id = _find_blog_id($objs, \%arg)
                or croak "blog_id is required: page: $title";
            my $author_id = _find_author_id($objs, \%arg)
                or croak "author_id is required: page: $title";

            my $page = MT::Test::Permission->make_page(
                blog_id   => $blog_id,
                author_id => $author_id,
                %arg,
            );
            $objs->{page}{ $page->basename } = $page;

            if ($folder_name) {
                my $folder = $objs->{folder}{$folder_name}{$blog_id}
                    or croak "unknown folder: $folder_name entry: $title";
                MT::Test::Permission->make_placement(
                    blog_id     => $blog_id,
                    entry_id    => $page->id,
                    category_id => $folder->id,
                );
            }
            for my $tag_name (@tag_names) {
                my $tag = $objs->{tag}{$tag_name}
                    or croak "unknown tag: $tag_name entry: $title";
                MT::Test::Permission->make_objecttag(
                    blog_id           => $blog_id,
                    object_id         => $page->id,
                    object_datasource => 'page',
                    tag_id            => $tag->id,
                );
            }
        }
    }
}

sub prepare_category_set {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{category_set};

    if (ref $spec->{category_set} eq 'HASH') {
        for my $name (sort keys %{ $spec->{category_set} }) {
            my $items = $spec->{category_set}{$name};
            if (ref $items eq 'ARRAY') {
                my $blog_id = $objs->{blog_id}
                    or croak "blog_id is required: category_set: $name";
                my $set = MT::Test::Permission->make_category_set(
                    blog_id => $blog_id,
                    name    => $name,
                );
                $objs->{category_set}{$name}{category_set} = $set;

                my %categories;
                for my $item (@$items) {
                    my %arg;
                    if (ref $item eq 'HASH') {
                        %arg = %$item;
                        if (my $parent_name = $arg{parent}) {
                            my $parent = $categories{$parent_name}
                                or croak "unknown parent category: $parent_name";
                            $arg{parent} = $parent->id;
                        }
                    } else {
                        %arg = (label => $item);
                    }
                    my $cat = MT::Test::Permission->make_category(
                        blog_id         => $blog_id,
                        category_set_id => $set->id,
                        %arg,
                    );
                    $categories{ $cat->label } = $cat;
                }
                $objs->{category_set}{ $set->name }{category} = \%categories;
            }
        }
    }
}

sub prepare_content_type {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{content_type};

    if (ref $spec->{content_type} eq 'HASH') {
        my @names = sort keys %{ $spec->{content_type} };
    CT:
        while (my $ct_name = shift @names) {
            my $item = $spec->{content_type}{$ct_name};

            my %ct_arg;
            my @field_spec;
            if (ref $item eq 'ARRAY') {
                @field_spec = @$item;
            } else {
                %ct_arg     = %$item;
                @field_spec = @{ delete $ct_arg{fields} || [] };
            }

            my $blog_id = _find_blog_id($objs, \%ct_arg)
                or croak "blog_id is required: content_type: $ct_name";

            my $ct = $objs->{content_type}{$ct_name}{content_type};
            if (!$ct) {
                $ct = MT::Test::Permission->make_content_type(
                    name    => $ct_name,
                    blog_id => $blog_id,
                    %ct_arg,
                );
                $objs->{content_type}{$ct_name}{content_type} = $ct;
            }

            my @field_spec_copy = @field_spec;
            my %cfs;
            my @fields;
            while (my ($cf_name, $cf_spec) = splice @field_spec_copy, 0, 2) {
                my %cf_arg;
                if (ref $cf_spec eq 'HASH') {
                    %cf_arg = %$cf_spec;
                } else {
                    $cf_arg{type} = $cf_spec;
                }

                my $cf_type  = $cf_arg{type};
                my $registry = MT->registry('content_field_types')->{$cf_type};

                my %options = (
                    label => $cf_arg{label} || $cf_arg{name} || $cf_name,
                    %{ delete $cf_arg{options} || {} },
                );
                if ($cf_type eq 'categories') {
                    my $set_name = delete $cf_arg{category_set};
                    my $set      = $objs->{category_set}{$set_name}{category_set}
                        or croak "category_set is required: content_field: $set_name";
                    $cf_arg{related_cat_set_id} = $set->id;
                    $options{category_set}      = $set->id;
                } elsif ($cf_type eq 'content_type') {
                    my $source_name = delete $cf_arg{source};
                    my $source      = $objs->{content_type}{$source_name}{content_type};
                    if (!$source) {
                        if (@names) {
                            push @names, $ct_name;
                            next CT;
                        }
                        croak "unknown content_type: $source_name";
                    }
                    $options{source} = $source->id;
                }
                my %known_options;
                for my $key (@{ $registry->{options} || [] }) {
                    $known_options{$key}++;
                    next unless defined $cf_arg{$key};
                    $options{$key} = delete $cf_arg{$key};
                }
                $options{display} ||= 'default' if $known_options{display};
                for my $key (sort keys %options) {
                    croak "unknown option: $key for $cf_name" unless $known_options{$key};
                }
                my $cf = $objs->{content_type}{$ct_name}{content_field}{$cf_name};
                if (!$cf) {
                    $cf = MT::Test::Permission->make_content_field(
                        blog_id         => $blog_id,
                        content_type_id => $ct->id,
                        name            => $cf_arg{name}        || $cf_name,
                        description     => $cf_arg{description} || $cf_name,
                        %cf_arg,
                    );
                    $objs->{content_type}{$ct_name}{content_field}{$cf_name} = $cf;
                }

                push @fields,
                    {
                    id        => $cf->id,
                    label     => 1,
                    name      => $cf->name,
                    type      => $cf_type,
                    order     => @fields + 1,
                    options   => \%options,
                    unique_id => $cf->unique_id,
                    };
            }
            $ct->fields(\@fields);
            $ct->save;
        }
    }
}

sub prepare_content_data {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{content_data};

    if (ref $spec->{content_data} eq 'HASH') {
        my @names = sort keys %{ $spec->{content_data} };
    CD:
        while (my $name = shift @names) {
            my $item = $spec->{content_data}{$name};
            if (ref $item eq 'HASH') {
                my %arg     = %$item;
                my $ct_name = delete $arg{content_type};
                my $ct      = $objs->{content_type}{$ct_name}{content_type}
                    or croak "content_type is required: content_data: $name";
                $arg{content_type_id} = $ct->id;

                $arg{author_id} ||= _find_author_id($objs, \%arg)
                    or croak "author_id is required: content_data: $name";
                my $blog_id = $arg{blog_id} ||= _find_blog_id($objs, \%arg)
                    or croak "blog_id is required: content_data: $name";
                $arg{label} = $name unless defined $arg{label};

                my %data;
                for my $cf_name (keys %{ $arg{data} }) {
                    my $cf = $objs->{content_type}{$ct_name}{content_field}{$cf_name}
                        or croak "unknown content_field: $cf_name: content_data: $name";
                    my $cf_type = $cf->type;
                    my $cf_arg  = $arg{data}{$cf_name};
                    if ($cf_type eq 'categories') {
                        my $set_id = $cf->related_cat_set_id;
                        my @sets   = values %{ $objs->{category_set} };
                        my ($set)  = grep { $_->{category_set}->id == $set_id } @sets;

                        my @cat_ids;
                        for my $cat_name (@$cf_arg) {
                            if (ref $cat_name eq 'SCALAR') {
                                push @cat_ids, $$cat_name;
                            } else {
                                my $cat = $set->{category}{$cat_name}
                                    or croak "unknown category: $cat_name: content_data: $name";
                                push @cat_ids, $cat->id;
                            }
                        }
                        $data{ $cf->id } = \@cat_ids;
                    } elsif ($cf_type eq 'content_type') {
                        my @cd_ids;
                        for my $cd_name (@$cf_arg) {
                            if (ref $cd_name eq 'SCALAR') {
                                push @cd_ids, $$cd_name;
                            } else {
                                my $cd = $objs->{content_data}{$cd_name};
                                if (!$cd) {
                                    if (@names) {
                                        push @names, $name;
                                        next CD;
                                    }
                                    croak "unknown content_data: $cd_name: content_data: $name";
                                }
                                push @cd_ids, $cd->id;
                            }
                        }
                        $data{ $cf->id } = \@cd_ids;
                    } elsif ($cf_type eq 'tags') {
                        my @tag_ids;
                        for my $tag_name (@$cf_arg) {
                            if (ref $tag_name eq 'SCALAR') {
                                push @tag_ids, $$tag_name;
                            } else {
                                my $tag = $objs->{tag}{$tag_name}
                                    or croak "unknown tag: $tag_name: content_data: $name";
                                push @tag_ids, $tag->id;
                            }
                        }
                        $data{ $cf->id } = \@tag_ids;
                    } elsif ($cf_type eq 'asset_image') {
                        my @asset_ids;
                        for my $asset_name (@$cf_arg) {
                            if (ref $asset_name eq 'SCALAR') {
                                push @asset_ids, $$asset_name;
                            } else {
                                my $asset = $objs->{image}{$asset_name}
                                    or croak "unknown asset: $asset_name: content_data: $name";
                                push @asset_ids, $asset->id;
                            }
                        }
                        $data{ $cf->id } = \@asset_ids;
                    }
                    elsif ( $cf_type eq 'multi_line_text' ) {
                        $arg{convert_breaks}{$cf_name} ||= '__default__';
                        $data{ $cf->id } = $cf_arg;
                    } else {
                        $data{ $cf->id } = $cf_arg;
                    }
                }
                $arg{data} = \%data;

                if ($arg{convert_breaks}) {
                    my %convert_breaks;
                    for my $cf_name (keys %{ $arg{convert_breaks} }) {
                        my $cf = $objs->{content_type}{$ct_name}{content_field}{$cf_name}
                            or croak "unknown content_field: $cf_name: content_data: $name";
                        $convert_breaks{ $cf->id } = $arg{convert_breaks}{$cf_name};
                    }
                    $arg{convert_breaks} = MT::Serialize->serialize(\{%convert_breaks});
                }

                my $status = $arg{status} || 'publish';
                if ($status =~ /\w+/) {
                    require MT::ContentStatus;
                    $arg{status} = MT::ContentStatus::status_int($status);
                }

                my $cd = MT::Test::Permission->make_content_data(%arg);
                $objs->{content_data}{ $cd->label } = $cd;
            }
        }
    }
}

sub prepare_role {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{role};
    if (ref $spec->{role} eq 'HASH') {
        for my $name (keys %{ $spec->{role} }) {
            my @perms;
            my @role_perms;
            if (ref $spec->{role}{$name} eq 'HASH') {
                @role_perms = @{ $spec->{role}{$name}{permissions} || [] };
            } else {
                @role_perms = @{ $spec->{role}{$name} || [] };
            }
            for my $role_perm (@role_perms) {
                my $reftype = ref $role_perm;
                if ($reftype eq 'HASH') {    # for content type
                    my $ct_name = $role_perm->{content_type};
                    my $cf_name = $role_perm->{content_field};
                    my $ct_perm = $role_perm->{permissions};
                    if ($ct_name) {
                        my $ct = $objs->{content_type}{$ct_name}{content_type}
                            or croak "unknown content type: $ct_name";
                        if ($cf_name) {
                            my $cf = $objs->{content_type}{$ct_name}{content_field}{$cf_name}
                                or croak "unknown content field: $ct_name $cf_name";
                            push @perms, "content_type:" . $ct->unique_id . "-content_field:" . $cf->unique_id;
                        } else {
                            croak "content_type role permissions are missing: $name" unless $ct_perm;
                            for my $perm (@$ct_perm) {
                                push @perms, "$perm:" . $ct->unique_id;
                                if ($perm eq 'manage_content_data') {
                                    push @perms, "create_content_data:" . $ct->unique_id;
                                    push @perms, "publish_content_data:" . $ct->unique_id;
                                    push @perms, "edit_all_content_data:" . $ct->unique_id;
                                    for my $cf_name (keys %{ $objs->{content_type}{$ct_name}{content_field} || {} }) {
                                        my $cf = $objs->{content_type}{$ct_name}{content_field}{$cf_name};
                                        push @perms, "content_type:" . $ct->unique_id . "-content_field:" . $cf->unique_id;
                                    }
                                }
                            }
                        }
                    }
                } elsif (!$reftype) {
                    push @perms, $role_perm;
                } else {
                    croak "unknown role type: $name $reftype";
                }
            }
            my $role = MT::Test::Permission->make_role(
                name        => $name,
                permissions => join ",", map { qq{'$_'} } uniq @perms,
            );
            $objs->{role}{$name} = $role;
        }
    }

    # prepare association
    for my $target (qw/author group/) {
        if ($spec->{$target} && ref $spec->{$target} eq 'ARRAY') {
            for my $item (@{ $spec->{$target} }) {
                my %target_arg = ref $item eq 'HASH' ? %$item : (name => $item);
                next unless @{ $target_arg{roles} || [] };
                my $target_obj = $objs->{$target}{ $target_arg{name} };
                for my $role (@{ $target_arg{roles} }) {
                    my %role_arg;
                    if (ref $role eq 'HASH') {
                        %role_arg = %$role;
                    } else {
                        %role_arg = (role => $role);
                    }
                    my $role_name = $role_arg{role}           or croak "role is required";
                    my $role_obj  = $objs->{role}{$role_name} or croak "unknown role: $role_name";

                    my $site_obj;
                    if (my $website_name = delete $role_arg{website}) {
                        $site_obj = $objs->{website}{$website_name} or croak "unknown website: $website_name";
                    }
                    if (my $blog_name = delete $role_arg{blog}) {
                        $site_obj = $objs->{blog}{$blog_name} or croak "unknown blog: $blog_name";
                    }
                    if (!$site_obj) {
                        my @sites = (values(%{ $objs->{website} || {} }), values(%{ $objs->{blog} || {} }));
                        if (@sites == 1) {
                            $site_obj = $sites[0];
                        } else {
                            croak "blog/website is required: $role_name";
                        }
                    }

                    MT::Association->link($target_obj, $role_obj, $site_obj);
                }
            }
        }
    }
}

sub prepare_template {
    my ($class, $spec, $objs) = @_;
    return unless $spec->{template};

    if (ref $spec->{template} eq 'ARRAY') {
        for my $item (@{ $spec->{template} }) {
            my %arg          = ref $item eq 'HASH' ? %$item : (archive_type => $item);
            my $archive_type = delete $arg{archive_type};
            my $archiver;
            if ($archive_type) {
                $archiver = MT->publisher->archiver($archive_type)
                    or croak "unknown archive_type: $archive_type";
                $arg{type} = _template_type($archive_type);
            }
            my $blog_id = _find_blog_id($objs, \%arg)
                or croak "blog_id is required: template: $arg{type}";

            my $ct;
            if (my $ct_name = delete $arg{content_type}) {
                $ct = $objs->{content_type}{$ct_name}{content_type}
                    or croak "content_type is not found: $ct_name";
                $arg{content_type_id} = $ct->id;
            }
            if (!$arg{name}) {
                (my $archive_type_name = $archive_type) =~ tr/A-Z-/a-z_/;
                $arg{name} = "tmpl_$archive_type_name";
            }

            my $mapping = delete $arg{mapping};

            ## Remove (to replace) if a template identifier is specified
            if ($arg{identifier}) {
                MT::Template->remove(
                    { blog_id => $blog_id, identifier => $arg{identifier} },
                    { nofetch => 1 });
            }

            my $tmpl = MT::Test::Permission->make_template(
                blog_id => $blog_id,
                %arg,
            );

            $objs->{template}{ $tmpl->name } = $tmpl;

            next unless $archive_type && $mapping;

            my $preferred = 1;
            $mapping = [$mapping] if ref $mapping eq 'HASH';
            for my $map (@$mapping) {
                $map->{file_template} ||= _file_template($archiver);
                $map->{build_type}    ||= 1;
                $map->{is_preferred} = $preferred;
                $map->{template_id}  = $tmpl->id;
                $map->{blog_id}      = $blog_id;
                $map->{archive_type} = $archive_type;

                if (my $cat_field_name = delete $map->{cat_field}) {
                    my @cat_fields = grep { $_->{type} eq 'categories' } @{ $ct->fields };
                    my ($cat) = grep { $_->{name} eq $cat_field_name } @cat_fields;

                    $map->{cat_field_id} = $cat->{id} if $cat;
                }

                if (my $dt_field_name = delete $map->{dt_field}) {
                    my @dt_fields = grep { $_->{type} =~ /date/ } @{ $ct->fields };
                    my ($dt) = grep { $_->{name} eq $dt_field_name } @dt_fields;

                    $map->{dt_field_id} = $dt->{id} if $dt;
                }

                my $tmpl_map = MT::Test::Permission->make_templatemap(%$map);

                $objs->{templatemap}{ $tmpl_map->file_template } = $tmpl_map;

                $preferred = 0;
            }
        }
    }
}

sub _template_type {
    my $archive_type = shift;
    return 'individual' if $archive_type eq 'Individual';
    return 'page'       if $archive_type eq 'Page';
    return 'ct'         if $archive_type eq 'ContentType';
    return 'ct_archive' if $archive_type =~ /^ContentType/;
    return 'archive';    # and custom?
}

sub _file_template {
    my $archiver = shift;
    my $prefix   = $archiver->name =~ /^ContentType/ ? "ct/" : "";
    for my $archive_template (@{ $archiver->default_archive_templates }) {
        next unless $archive_template->{default};
        return $prefix . $archive_template->{template};
    }
}

sub _find_blog_id {
    my ($objs, $arg) = @_;
    if (my $website_name = delete $arg->{website}) {
        my $site = $objs->{website}{$website_name} or croak "unknown website: $website_name";
        return $site->id;
    }
    if (my $blog_name = delete $arg->{blog}) {
        my $site = $objs->{blog}{$blog_name} or croak "unknown blog: $blog_name";
        return $site->id;
    }
    $arg->{blog_id} // $objs->{blog_id};
}

sub _find_author_id {
    my ($objs, $arg) = @_;
    if (my $author_name = delete $arg->{author}) {
        my $author = $objs->{author}{$author_name} or croak "unknown author: $author_name";
        return $author->id;
    }
    $arg->{author_id} || $objs->{author_id};
}

1;
