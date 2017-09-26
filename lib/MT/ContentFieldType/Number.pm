package MT::ContentFieldType::Number;
use strict;
use warnings;

sub MAX_VALUE() {2147483647}
sub MIN_VALUE() {-2147483648}

sub field_html_params {
    my ( $app, $field_data ) = @_;

    my $options        = $field_data->{options};
    my $decimal_places = $options->{decimal_places} || 0;
    my $max_value      = $options->{max_value};
    my $min_value      = $options->{min_value};

    my $max
        = ( defined $max_value && $max_value ne '' )
        ? qq{max="${max_value}"}
        : '';
    my $min
        = ( defined $min_value && $min_value ne '' )
        ? qq{min="${min_value}"}
        : '';
    my $required = $options->{required} ? 'required' : '';
    my $step = 1 / 10**$decimal_places;

    {   max      => $max,
        min      => $min,
        required => $required,
        step     => $step,
    };
}

sub ss_validator {
    my ( $app, $field_data, $data ) = @_;
    return undef
        unless defined $data
        && $data ne '';    # Do not check empty value here.

    my $options = $field_data->{options} || {};

    my $decimal_places = $options->{decimal_places} || 0;
    my $field_label    = $options->{label};
    my $max_value      = $options->{max_value};
    my $min_value      = $options->{min_value};

    if ( $data !~ /^[+\-]?\d+(\.\d+)?$/ ) {
        return $app->translate( '"[_1]" field value must be number.',
            $field_label );
    }

    if ($decimal_places) {
        my ( $int, $frac ) = split /\./, $data;
        if ( length $frac > $decimal_places ) {
            my $trimmed_frac = substr $frac, 0, $decimal_places;
            my $trimmed_value = "${int}.${trimmed_frac}";
            if ( $trimmed_value != $data ) {
                return $app->translate(
                    '"[_1]" field value has invalid precision.',
                    $field_label );
            }
        }
    }
    else {
        if ( $data =~ /\./ ) {
            return $app->translate(
                '"[_1]" field value has invalid precision.', $field_label );
        }
    }

    if ( defined $max_value && $max_value ne '' ) {
        if ( $data > $max_value ) {
            return $app->translate(
                '"[_1]" field value must be less than or equal to [_2].',
                $field_label, $max_value );
        }
    }
    if ( defined $min_value && $min_value ne '' ) {
        if ( $data < $min_value ) {
            return $app->translate(
                '"[_1]" field value must be greater than or equal to [_2]',
                $field_label, $min_value );
        }
    }
}

sub options_validation_handler {
    my ( $app, $type, $label, $field_label, $options ) = @_;

    my $decimal_places = $options->{decimal_places};
    if ($decimal_places) {
        return $app->translate("A decimal places must be a positive integer.")
            unless $decimal_places =~ /^\d+$/;
    }

    my $min_value = $options->{min_value};
    if ($min_value) {
        $min_value =~ /^[+\-]?\d+(\.\d+)?$/;

        return $app->translate(
            "A minimun value must be an integer, or must be set decimal places to use decimal value."
        ) if !$decimal_places and defined $1;

        return $app->translate(
            "A minimun value must be an integer and between [_1] and [_2]",
            MIN_VALUE(), MAX_VALUE() )
            if $min_value < MIN_VALUE() || $min_value > MAX_VALUE();
    }

    my $max_value = $options->{max_value};
    if ($max_value) {
        $max_value =~ /^[+\-]?\d+(\.\d+)?$/;

        return $app->translate(
            "A maximum value must be an integer, or must be set decimal places to use decimal value."
        ) if !$decimal_places and defined $1;

        return $app->translate(
            "A maximum value must be an integer and between [_1] and [_2]",
            MIN_VALUE(), MAX_VALUE() )
            if $max_value < MIN_VALUE() || $max_value > MAX_VALUE();
    }

    my $initial_value = $options->{initial_value};
    if ($initial_value) {
        $initial_value =~ /^[+\-]?\d+(\.\d+)?$/;

        return $app->translate(
            "An initial value must be an integer, or must be set decimal places to use decimal value."
        ) if !$decimal_places and defined $1;

        my $min = '' ne $min_value ? $min_value : MIN_VALUE();
        my $max = '' ne $max_value ? $max_value : MAX_VALUE();

        return $app->translate(
            "An initial value must be an integer and between [_1] and [_2]",
            $min, $max )
            if $initial_value < $min || $initial_value > $max;
    }

    return;
}

1;

