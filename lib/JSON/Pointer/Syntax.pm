package JSON::Pointer::Syntax;

use strict;
use warnings;

use Exporter qw(import);
use JSON::Pointer::Context;
use JSON::Pointer::Exception qw(:all);

our $VERSION = '0.01';
our @EXPORT_OK = qw(
    escape_reference_token
    unescape_reference_token
    is_array_numeric_index
);

our $REGEX_ESCAPED         = qr{~[01]};
our $REGEX_UNESCAPED       = qr{[\x{00}-\x{2E}\x{30}-\x{7D}\x{7F}-\x{10FFFF}]};
our $REGEX_REFERENCE_TOKEN = qr{(?:$REGEX_ESCAPED|$REGEX_UNESCAPED)*};
our $REGEX_ARRAY_INDEX     = qr{(?:0|[1-9][0-9]*)};

sub escape_reference_token {
    my $escaped_reference_token = shift;

    $escaped_reference_token =~ s/~/~0/g;
    $escaped_reference_token =~ s/\x2F/~1/g;

    return $escaped_reference_token;
}

sub unescape_reference_token {
    my $unescaped_reference_token = shift;

    $unescaped_reference_token =~ s/~1/\x2F/g;
    $unescaped_reference_token =~ s/~0/~/g;

    return $unescaped_reference_token;
}

sub tokenize {
    my ($class, $pointer) = @_;
    my @tokens;

    my $orig_pointer = $pointer;

    while ($pointer =~ s{/($REGEX_REFERENCE_TOKEN)}{}) {
        my $token = $1;
        push @tokens => unescape_reference_token($token);
    }

    unless ($orig_pointer eq "" || $pointer eq "") {
        JSON::Pointer::Exception->throw(
            code    => ERROR_INVALID_POINTER_SYNTAX,
            context => JSON::Pointer::Context->new(
                pointer => $orig_pointer,
            ),
        );
    }

    return wantarray ? @tokens : [ @tokens ];
}

sub as_pointer {
    my ($class, $tokens) = @_;

    return "/" . join(
        "/", 
        map { escaped_reference_token($_) }
        @$tokens
    );

}

sub is_array_numeric_index {
    my $token = shift;
    return $token =~ m/^$REGEX_ARRAY_INDEX$/ ? 1 : 0;
}

1;
