use strict;
use warnings;

use Test::More;
use Test::Exception;

use Carp;
use JSON;
use JSON::Pointer;
use JSON::Pointer::Exception qw(:all);

my $document = decode_json(<< "JSON");
{
    "foo": ["bar", "baz"],
    "highly": {
        "nested": {
            "objects": true
        }
    }
}
JSON

sub test_get_relative {
    my ($desc, %specs) = @_;

    my ($input, $expect) = @specs{qw/input expect/};

    subtest $desc => sub {
        my $actual = JSON::Pointer->get_relative($document, @$input);
        is_deeply($actual, $expect, "target");
    };
}

subtest "Reletive JSON Pointer examples in 5.1" => sub {
    subtest "current pointer is /foo/1" => sub {
        my $current_pointer = "/foo/1";
        
        test_get_relative "0" => (
            input => [ $current_pointer, "0" ],
            expect => "baz",
        );

        test_get_relative "1/0" => (
            input => [ $current_pointer, "1/0" ],
            expect => "bar",
        );

        test_get_relative "2/highly/nested/objects" => (
            input => [ $current_pointer, "2/highly/nested/objects" ],
            expect => JSON::true,
        );

        test_get_relative "0#" => (
            input => [ $current_pointer, "0#" ],
            expect => 1,
        );

        test_get_relative "1#" => (
            input => [ $current_pointer, "1#" ],
            expect => "foo",
        );
    };

    subtest "current pointer is /highly/nested" => sub {
        my $current_pointer = "/highly/nested";
        
        test_get_relative "0/objects" => (
            input => [ $current_pointer, "0/objects" ],
            expect => JSON::true,
        );

        test_get_relative "1/nested/objects" => (
            input => [ $current_pointer, "1/nested/objects" ],
            expect => JSON::true,
        );

        test_get_relative "2/foo/0" => (
            input => [ $current_pointer, "2/foo/0" ],
            expect => "bar",
        );

        test_get_relative "0#" => (
            input => [ $current_pointer, "0#" ],
            expect => "nested",
        );

        test_get_relative "1#" => (
            input => [ $current_pointer, "1#" ],
            expect => "highly",
        );
    };
};

done_testing;
