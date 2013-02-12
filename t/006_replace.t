use strict;
use warnings;

use Test::More;
use JSON::Pointer;

sub test_replace {
    my ($desc, %specs) = @_;
    my ($input, $expect) = @specs{qw/input expect/};

    subtest $desc => sub {
        my ($document, $pointer, $value) = @$input{qw/document pointer value/};
        my $actual = JSON::Pointer->replace($document, $pointer, $value);
        is_deeply($actual, $expect->{target}, "target");
        is_deeply($document, $expect->{document}, "document");
    };
}

# https://github.com/json-patch/json-patch-tests

subtest "JSON Patch Appendix A. Example" => sub {
    test_replace "A.5 Replacing a Value" => (
        input => +{
            document => +{
                baz => "qux",
                foo => "bar",
            },
            pointer => "/baz",
            value => "boo",
        },
        expect => +{
            target => "qux",
            document => +{
                baz => "boo",
                foo => "bar"
            }
        },
    );
};

done_testing;
