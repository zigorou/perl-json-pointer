use strict;
use warnings;

use Test::More;
use JSON::Pointer;

sub test_remove {
    my ($desc, %specs) = @_;
    my ($input, $expect) = @specs{qw/input expect/};

    subtest $desc => sub {
        my ($document, $pointer) = @$input{qw/document pointer value/};
        my $actual = JSON::Pointer->remove($document, $pointer);
        is_deeply($actual, $expect->{target}, "target");
        is_deeply($document, $expect->{document}, "document");
    };
}

# https://github.com/json-patch/json-patch-tests

subtest "JSON Patch Appendix A. Example" => sub {
    test_remove "A.3 Removing an Object Member" => (
        input => +{
            document => +{
                baz => "qux",
                foo => "bar",
            },
            pointer => "/baz",
        },
        expect => +{
            target => "qux",
            document => +{
               foo => "bar"
            }
        },
    );

    test_remove "A.4 Removing an Array Element" => (
        input => +{
            document => +{
                foo => ["bar", "qux", "baz"],
            },
            pointer => "/foo/1",
        },
        expect => +{
            target => "qux",
            document => +{
               foo => ["bar", "baz"]
            }
        },
    );
};

done_testing;
