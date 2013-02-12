use strict;
use warnings;

use Test::More;
use JSON;
use JSON::Pointer;

sub test_test {
    my ($desc, %specs) = @_;
    my ($input, $expect) = @specs{qw/input expect/};

    subtest $desc => sub {
        my ($document, $pointer, $value) = @$input{qw/document pointer value/};
        my $actual = JSON::Pointer->test($document, $pointer, $value);
        is(
            $actual, $expect, 
            sprintf("test - document: %s. pointer: %s. value: %s", encode_json($document), $pointer, $value)
        );
    };
}

subtest "JSON Patch Appendix A. Example" => sub {
    test_test "A.8. Testing a Value: Success (/0)" => (
        input => +{
            document => +{
                baz => "qux",
                foo => ["a", 2, "c"]
            },
            pointer => "/baz",
            value => "qux"
        },
        expect => 1,
    );

    test_test "A.8. Testing a Value: Success (/1)" => (
        input => +{
            document => +{
                baz => "qux",
                foo => ["a", 2, "c"]
            },
            pointer => "/foo/1",
            value   => 2,
        },
        expect => 1,
    );

    test_test "A.8. Testing a Value: Error" => (
        input => +{
            document => +{
                baz => "qux",
            },
            pointer => "/baz",
            value   => "bar",
        },
        expect => 0,
    );

    test_test "A.14. ~ Escape Ordering" => (
        input => +{
            document => +{
                "/" => 9,
                "~1" => 10,
            },
            pointer => "/~01",
            value   => 10,
        },
        expect => 1,
    );

    test_test "A.15. Comparing Strings and Numbers" => (
        input => +{
            document => +{
                "/" => 9,
                "~1" => 10,
            },
            pointer => "/~01",
            value   => "10",
        },
        expect => 0,
    );
};

done_testing;
