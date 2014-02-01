use strict;
use warnings;

use Test::More;
use JSON;
use JSON::Pointer;

my $json = JSON->new->allow_nonref;

sub test_remove {
    my ($desc, %specs) = @_;
    my ($input, $expect) = @specs{qw/input expect/};

    subtest $desc => sub {
        my ($document, $pointer) = @$input{qw/document pointer/};
        my ($patched_document, $removed) = JSON::Pointer->remove($document, $pointer);
        is_deeply(
            $patched_document,
            $expect->{document},
            sprintf(
                "removed document (actual: %s. expect: %s)",
                $json->encode($patched_document),
                $json->encode($expect->{document}),
            )
        );
        is_deeply(
            $removed,
            $expect->{removed},
            sprintf(
                "removed element (actual: %s. expect: %s)",
                $json->encode($removed),
                $json->encode($expect->{removed}),
            )
        );
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
            removed => "qux",
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
            removed => "qux",
            document => +{
               foo => ["bar", "baz"]
            }
        },
    );
};

subtest "https://github.com/json-patch/json-patch-tests/blob/master/tests.json" => sub {
    test_remove "remove toplevel object field" => (
        input => +{
            document => +{
                foo => 1,
                bar => [1, 2, 3, 4],
            },
            pointer => "/bar",
        },
        expect => +{
            removed => [1, 2, 3, 4],
            document => +{
                foo => 1,
            },
        },
    );

    test_remove "remove nested object field" => (
        input => +{
            document => +{
                foo => 1,
                baz => [ +{ qux => "hello" } ],
            },
            pointer => "/baz/0/qux",
        },
        expect => +{
            removed => "hello",
            document => +{
                foo => 1,
                baz => [ +{} ],
            },
        },
    );
};

subtest "misc" => sub {
    test_remove "remove whole document (object)" => (
        input => +{
            document => +{},
            pointer => "",
        },
        expect => +{
            removed => +{},
            document => undef,
        },
    );

    test_remove "remove whole document (array)" => (
        input => +{
            document => [],
            pointer => "",
        },
        expect => +{
            removed => [],
            document => undef,
        },
    );

    test_remove "remove whole document (string)" => (
        input => +{
            document => "foo",
            pointer => "",
        },
        expect => +{
            removed => "foo",
            document => undef,
        },
    );

    test_remove "remove specified element from array" => (
        input => +{
            document => [0, 1, 2, 3],
            pointer => "/2",
        },
        expect => +{
            removed => 2,
            document => [0, 1, 3],
        },
    );
};

done_testing;
