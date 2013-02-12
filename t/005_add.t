use strict;
use warnings;

use Test::More;
use Test::Exception;

use Carp;
use JSON::Pointer;
use JSON::Pointer::Exception qw(:all);

sub test_add {
    my ($desc, %specs) = @_;
    my ($input, $expect) = @specs{qw/input expect/};

    subtest $desc => sub {
        my ($document, $pointer, $value) = @$input{qw/document pointer value/};
        my $rv = JSON::Pointer->add($document, $pointer, $value);
        is($rv, $expect->{rv}, "rv");
        is_deeply($document, $expect->{patched}, "patched");
    };
}

sub test_add_exception {
    my ($desc, %specs) = @_;
    my ($input, $expect) = @specs{qw/input expect/};

    subtest $desc => sub {
        my ($document, $pointer, $value) = @$input{qw/document pointer value/};
        throws_ok {
            eval {
                my $rv = JSON::Pointer->add($document, $pointer, $value);
            };
            if (my $e = $@) {
                is($e->code, ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE, "code");
                croak $e;
            }
        } "JSON::Pointer::Exception" => "throws_ok";
    };
}

# https://github.com/json-patch/json-patch-tests

subtest "JSON Patch Section 4.1" => sub {
    test_add "add with existing object field" => (
        input => +{
            document => +{ a => +{ foo => 1 } }, 
            pointer  => "/a/b", 
            value    => "qux"
        },
        expect => +{
            rv      => 1,
            patched => +{ 
                a => +{ foo => 1, b => "qux" }
            }
        }
    );

    test_add_exception "add with missing object" => (
        input => +{
            document => +{ q => +{ bar => 2 } },
            pointer  => "/a/b",
            value    => "qux",
        },
        expect => +{
            code => ERROR_POINTER_REFERENCES_NON_EXISTENT_VALUE
        },
    );
};

subtest "JSON Patch Appendix A. Example" => sub {
    test_add "A1. Adding an Object Member" => (
        input => +{
            document => { foo => "bar" }, 
            pointer  => "/baz", 
            value    => "qux"
        },
        expect => +{
            rv      => 1,
            patched => +{ 
                foo => "bar", baz => "qux",
            }
        }
    );

    test_add "A2. Adding an Array Element" => (
        input => +{
            document => { foo => ["bar", "baz"] }, 
            pointer  => "/foo/1", 
            value    => "qux"
        },
        expect => +{
            rv      => 1,
            patched => +{ 
                foo => ["bar", "qux", "baz"]
            }
        }
    );
};

done_testing;
