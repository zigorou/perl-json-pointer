package JSON::Pointer;

use 5.008_001;
use strict;
use warnings;

use B;
use Carp qw(croak);
use Data::Clone qw(clone);
use JSON qw(encode_json decode_json);
use JSON::Pointer::Context;
use JSON::Pointer::Exception qw(:all);
use JSON::Pointer::Syntax qw(is_array_numeric_index);
use URI::Escape qw(uri_unescape);

our $VERSION = '0.01';

sub traverse {
    my ($class, $document, $pointer, $strict) = @_;
    $strict = 1 unless defined $strict;
    $pointer = uri_unescape($pointer);

    my @tokens  = JSON::Pointer::Syntax->tokenize($pointer);
    my $context = JSON::Pointer::Context->new(+{
        pointer => $pointer,
        tokens  => \@tokens,
        target  => $document,
        parent  => $document,
    });

    foreach my $token (@tokens) {
        $context->begin($token);

        my $parent = $context->parent;
        my $type   = ref $parent;

        if ($type eq "HASH") {
            unless (exists $parent->{$token}) {
                return _throw_or_return(ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE, $context, $strict);
            }

            $context->next($parent->{$token});
            next;
        }
        elsif ($type eq "ARRAY") {
            my $elements_length = $#{$parent} + 1;

            if (is_array_numeric_index($token) && $token <= $elements_length) {
                $context->next($parent->[$token]);
                next;
            }
            elsif ($token eq "-") {
                $context->next(undef);
                next;
            }
            else {
                return _throw_or_return(ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE, $context, $strict);
            }
        }
        else {
            return _throw_or_return(ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE, $context, $strict);
        }
    }

    $context->result(1);
    return $context;
}

sub get {
    my ($class, $document, $pointer, $strict) = @_;
    $strict = 0 unless defined $strict;

    my $context;
    eval {
        $context = $class->traverse($document, $pointer, $strict);
    };
    if (my $e = $@) {
        croak $e;
    }

    return $context->result ? $context->target : undef;
}

sub contains {
    my ($class, $document, $pointer) = @_;
    my $context = $class->traverse($document, $pointer, 0);
    return $context->result;
}

sub add {
    my ($class, $document, $pointer, $value) = @_;

    my $patched_document = clone($document);

    my $context = $class->traverse($patched_document, $pointer, 0);
    my $parent  = $context->parent;
    my $type    = ref $parent;

    if ($type eq "HASH") {
        if (!$context->result && @{$context->processed_tokens} < @{$context->tokens} - 1) {
            ### Parent isn't object
            JSON::Pointer::Exception->throw(
                code    => ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE,
                context => $context,
            );
        }

        if (defined $context->last_token) {
            $parent->{$context->last_token} = $value;
        }
        else {
            ### pointer is empty string (whole document)
            $patched_document = $value;
        }

        return $patched_document;
    }
    elsif ($type eq "ARRAY") {
        unless ($context->result) {
            JSON::Pointer::Exception->throw(
                code    => ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE,
                context => $context,
            );
        }

        if (defined $context->last_token) {
            my $parent_array_length = $#{$parent} + 1;
            my $target_index        = ($context->last_token eq "-") ? 
                $parent_array_length : $context->last_token;

            splice(@$parent, $target_index, 0, $value);
        }
        else {
            $patched_document = $value;
        }

        return $patched_document;
    }
    else {
        unless ($context->result) {
            JSON::Pointer::Exception->throw(
                code    => ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE,
                context => $context,
            );
        }

        return $value;
    }
}

sub remove {
    my ($class, $document, $pointer) = @_;

    my $patched_document = clone($document);

    my $context = $class->traverse($patched_document, $pointer, 1);
    my $parent  = $context->parent;
    my $type    = ref $parent;

    if ($type eq "HASH") {
        my $target_member = $context->last_token;
        if (defined $target_member) {
            my $removed = delete $parent->{$target_member};
            return wantarray ? ($patched_document, $removed) : $patched_document;
        }
        else {
            ### pointer is empty string (whole document)
            return wantarray ? (undef, $patched_document) : undef;
        }
    }
    elsif ($type eq "ARRAY") {
        my $target_index = $context->last_token;
        if (defined $target_index) {
            my $parent_array_length = $#{$parent} + 1;
            $target_index = $parent_array_length if ($target_index eq "-");
            my $removed = splice(@$parent, $target_index, 1);
            return wantarray ? ($patched_document, $removed) : $patched_document;
        }
        else {
            ### pointer is empty string (whole document)
            return wantarray ? (undef, $patched_document) : undef;
        }
    }
    else {
        unless ($context->result) {
            JSON::Pointer::Exception->throw(
                code    => ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE,
                context => $context,
            );
        }

        return wantarray ? (undef, $patched_document) : undef;
    }
}

sub replace {
    my ($class, $document, $pointer, $value) = @_;

    my $patched_document = clone($document);
    my $context = $class->traverse($patched_document, $pointer, 1);
    my $parent  = $context->parent;
    my $type    = ref $parent;

    if ($type eq "HASH") {
        my $target_member = $context->last_token;
        if (defined $target_member) {
            my $replaced = $parent->{$context->last_token};
            $parent->{$context->last_token} = $value;
            return wantarray ? ($patched_document, $replaced) : $patched_document;
        }
        else {
            ### pointer is empty string (whole document)
            return wantarray ? ($value, $patched_document) : $value;
        }
    }
    else {
        my $target_index = $context->last_token;
        if (defined $target_index) {
            my $parent_array_length = $#{$parent} + 1;
            $target_index = $parent_array_length if ($target_index eq "-");
            my $replaced = $parent->[$target_index];
            $parent->[$target_index] = $value;
            return wantarray ? ($patched_document, $replaced) : $patched_document;
        }
        else {
            ### pointer is empty string (whole document)
            return wantarray ? ($value, $patched_document) : $value;
        }
    }
}

sub set {
    shift->replace(@_);
}

sub copy {
    my ($class, $document, $from_pointer, $to_pointer) = @_;
    my $context = $class->traverse($document, $from_pointer, 1);
    return $class->add($document, $to_pointer, $context->target);
}

sub move {
    my ($class, $document, $from_pointer, $to_pointer) = @_;
    my ($patched_document, $removed) = $class->remove($document, $from_pointer);
    $class->add($patched_document, $to_pointer, $removed);
}

sub test {
    my ($class, $document, $pointer, $value) = @_;

    my $context = $class->traverse($document, $pointer, 0);

    return 0 unless $context->result;

    my $target      = $context->target;
    my $target_type = ref $target;

    if ($target_type eq "HASH" || $target_type eq "ARRAY") {
        return encode_json($target) eq encode_json($value) ? 1 : 0;
    }
    elsif (defined $target) {
        if (JSON::is_bool($target)) {
            return JSON::is_bool($value) && $target == $value ? 1 : 0;
        }
        elsif (_is_iv_or_nv($target) && _is_iv_or_nv($value)) {
            return $target == $value ? 1 : 0;
        }
        elsif (_is_pv($target) && _is_pv($value)) {
            return $target eq $value ? 1 : 0;
        }
        else {
            return 0;
        }
    }
    else {
        ### null
        return !defined $value ? 1 : 0;
    }
}

sub _throw_or_return {
    my ($code, $context, $strict) = @_;

    if ($strict) {
        JSON::Pointer::Exception->throw(
            code    => $code,
            context => $context,
        );
    }
    else {
        $context->last_error($code);
        return $context;
    }
}

sub _is_iv_or_nv {
    my $value = shift;
    my $flags = B::svref_2object(\$value)->FLAGS;
    return ($flags & ( B::SVp_IOK | B::SVp_NOK )) and !($flags & B::SVp_POK);
}

sub _is_pv {
    my $value = shift;
    my $flags = B::svref_2object(\$value)->FLAGS;
    return !($flags & ( B::SVp_IOK | B::SVp_NOK )) and ($flags & B::SVp_POK);
}

1;

__END__

=head1 NAME

JSON::Pointer - A Perl implementation of JSON Pointer

=head1 VERSION

This document describes JSON::Pointer version 0.01.

=head1 SYNOPSIS

  use JSON::Pointer;

  my $obj = {
    "foo"  => [ "bar", "baz" ],
    ""     => 0,
    "a/b"  => 1,
    "c\%d" => 2,
    "e^f"  => 3,
    "g|h"  => 4,
    "i\\j" => 5,
    "k\"l" => 6,
    " "    => 7,
    "m~n"  => 8
  };

  JSON::Pointer->get($obj, "/foo");   ### $obj->{foo}
  JSON::Pointer->get($obj, "/foo/0"); ### $obj->{foo}[0]
  JSON::Pointer->get($obj, "");       ### $obj
  JSON::Pointer->get($obj, "/a~1b");  ### $obj->{"a/b"}
  JSON::Pointer->get($obj, "/m~0n");  ### $obj->{"m~n}

=head1 DESCRIPTION

This library is implemented JSON Pointer draft-09 (http://tools.ietf.org/html/draft-ietf-appsawg-json-pointer-09) and 
some useful operator from JSON Patch draft-10 (http://tools.ietf.org/html/draft-ietf-appsawg-json-patch-10).

JSON Pointer is available to identify a specified value, and it is simillar to XPath.
Please see the both of specifications for details.

=head1 METHODS

=head2 traverse($document, $pointer, $strict) : JSON::Pointer::Context

=head2 get($document, $pointer, $strict) : Scalar

=head2 contains($document, $pointer) : Int

=head2 add($document, $pointer, $value) : Scalar

=head2 remove($document, $pointer) : Array or Scalar

=head2 replace($document, $pointer, $value) : Arrary or Scalar

=head2 set($document, $pointer, $value) : Array or Scalar

This method is alias of replace.

=head2 copy($document, $from_pointer, $to_pointer) : Scalar

=head2 move($document, $from_pointer, $to_pointer) : Scalar

=head2 test($document, $pointer, $value) : Int

=head1 DEPENDENCIES

Perl 5.8.1 or later.

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 SEE ALSO

=over

=item L<perl>

=item L<Mojo::JSON::Pointer>

Many codes in this module is inspired by the module.

=item L<http://tools.ietf.org/html/draft-ietf-appsawg-json-pointer-05>

=back

=head1 AUTHOR

Toru Yamaguchi E<lt>zigorou at cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2012, <<YOUR NAME HERE>>. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
