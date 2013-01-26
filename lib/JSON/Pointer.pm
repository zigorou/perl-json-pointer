package JSON::Pointer;

use strict;
use warnings;

use Carp qw(croak);
use JSON qw(encode_json decode_json);
use JSON::Pointer::Context;
use JSON::Pointer::Exception qw(:all);
use JSON::Pointer::Syntax qw(is_array_numeric_index);
use Scalar::Util qw(looks_like_number);

our $VERSION = '0.01';

sub traverse {
    my ($class, $document, $pointer, $use_strict) = @_;
    $use_strict = 1 unless defined $use_strict;

    my @tokens = JSON::Pointer::Syntax->tokenize($pointer);
    my $context = JSON::Pointer::Context->new(+{
        pointer => $pointer,
        tokens  => \@tokens,
        target  => $document,
        parent  => $document,
    });

    foreach my $token (@tokens) {
        $context->start_process($token);
        my $type = $context->parent_type;
        my $parent = $context->parent;

        if ($type eq "HASH") {
            unless (exists $parent->{$token}) {
                return _throw_or_return(ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE, $context, $use_strict);
            }

            $context->next_process($parent->{$token});
            next;
        }
        elsif ($type eq "ARRAY") {
            my $elements_length = $#{$parent} + 1;

            if (is_array_numeric_index($token) && $token <= $elements_length) {
                $context->next_process($parent->[$token]);
                next;
            }
            elsif ($token eq "-") {
                $context->next_process(undef);
                next;
            }
            else {
                return _throw_or_return(ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE, $context, $use_strict);
            }
        }
        else {
            return _throw_or_return(ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE, $context, $use_strict);
        }
    }

    $context->result(1);
    return $context;
}

sub get {
    my ($class, $document, $pointer) = @_;

    my $context;
    eval {
        $context = $class->traverse($document, $pointer, 1);
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
    my $context = $class->traverse($document, $pointer, 0);
    my $type = $context->parent_type;

    if ($type eq "HASH") {
        if (!$context->result && @{$context->processed_tokens} < @{$context->tokens} - 1) {
            ### Parent isn't object
            JSON::Pointer::Exception->throw(
                code    => ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE,
                context => $context,
            );
        }

        $context->parent->{$context->last_token} = $value;
        return 1;
    }
    else {
        unless ($context->result) {
            JSON::Pointer::Exception->throw(
                code    => ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE,
                context => $context,
            );
        }

        my $parent_array        = $context->parent;
        my $parent_array_length = $#{$parent_array} + 1;
        my $target_index        = ($context->last_token eq "-") ? 
            $parent_array_length : $context->last_token;

        splice(@$parent_array, $target_index, 0, $value);
        return 1;
    }
}

sub remove {
    my ($class, $document, $pointer) = @_;
    my $context = $class->traverse($document, $pointer, 1);
    my $type = $context->parent_type;

    if ($type eq "HASH") {
        my $parent_object = $context->parent;
        my $target_member = $context->last_token;
        my $old_value = delete $parent_object->{$target_member};
        return $old_value;
    }
    else {
        my $parent_array        = $context->parent;
        my $parent_array_length = $#{$parent_array} + 1;
        my $target_index        = ($context->last_token eq "-") ? 
            $parent_array_length : $context->last_token;

        my $old_value = splice(@$parent_array, $target_index, 1);
        return $old_value;
    }
}

sub replace {
    my ($class, $document, $pointer, $value) = @_;
    my $context = $class->traverse($document, $pointer, 1);
    my $type = $context->parent_type;

    if ($type eq "HASH") {
        my $old_value = $context->parent->{$context->last_token};
        $context->parent->{$context->last_token} = $value;
        return $old_value;
    }
    else {
        my $parent_array        = $context->parent;
        my $parent_array_length = $#{$parent_array} + 1;
        my $target_index        = ($context->last_token eq "-") ? 
            $parent_array_length : $context->last_token;

        my $old_value = $parent_array->[$target_index];
        $parent_array->[$target_index] = $value;
        return $old_value;
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

sub test {
    my ($class, $document, $pointer, $value) = @_;
    my $context = $class->traverse($document, $pointer, 1);
    my $target = $context->target;
    my $target_type = ref $target;

    if ($target_type eq "HASH" || $target_type eq "ARRAY") {
        return encode_json($context->target) eq encode_json($value) ? 1 : 0;
    }
    elsif (defined $target) {
        if (JSON::is_bool($target)) {
            return JSON::is_bool($value) && $target == $value ? 1 : 0;
        }
        elsif (looks_like_number($target)) {
            return $target == $value ? 1 : 0;
        }
        else {
            return $target eq $value ? 1 : 0;
        }
    }
    else {
        return !defined $value ? 1 : 0;
    }
}

sub _throw_or_return {
    my ($code, $context, $use_strict) = @_;

    if ($use_strict) {
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

This library implements JSON Pointer draft-05 (http://tools.ietf.org/html/draft-ietf-appsawg-json-pointer-05).
JSON Pointer can access by the way like XPath for JSON data format.
Please see the specification for details.

=head1 METHODS

=head2 contains($obj, $pointer) : Int

This method is checking which the value pointerd by json pointer is exists or not.
For example, $obj is same value in L<SYNOPSIS>.

    my $rv1 = JSON::Pointer->contains($obj, "/foo/0");
    my $rv2 = JSON::Pointer->contains($obj, "/foo/2");

In this situation, $orig_value equals 1 (true), $new_value equals 0 (false).

=head2 get($obj, $pointer) : Scalar

This method is retrieving value pointed by json pointer.

If you specified scalar context as left value, then this method will return only value pointed by json pointer.
For example, $obj is same value in L<SYNOPSIS>.

    my $target = JSON::Pointer->get($obj, "/foo/0");
    ### $target = "bar"

And if you specified array context as left value, this method will return value on first argument and parent value on second argument. For example,

    my ($target, $parent) = JSON::Pointer->get($obj, "/foo/0");
    ### $target = "bar"
    ### $parent = ["bar", "baz"]

=head2 set($obj, $pointer, $value) : Scalar

This method is replacing value pointed by json pointer.

For example, $obj is same value in L<SYNOPSIS>.

   my $orig_value = JSON::Pointer->set($obj, "/foo/0", "blah");
   my $new_value = JSON::Pointer->get($obj, "/foo/0");

In this situation, $orig_value equals "bar", $new_value equals "blah".

=head2 tokenize($pointer) : Array | ArrayRef

This method tokenize JSON Pointer string.
Return array contains each pathes.

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
