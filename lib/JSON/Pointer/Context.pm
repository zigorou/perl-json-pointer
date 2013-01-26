package JSON::Pointer::Context;

use strict;
use warnings;
use Class::Accessor::Lite (
    new => 0,
    rw  => [
        qw/
              pointer
              tokens
              processed_tokens
              last_token
              last_error
              result
              target
              parent
          /
      ],
);

sub new {
    my $class = shift;
    my $args = ref $_[0] ? $_[0] : +{ @_ };
    %$args = (
        tokens           => [],
        processed_tokens => [],
        last_token       => undef,
        last_error       => undef,
        result           => 0,
        target           => undef,
        parent           => undef,
        %$args,
    );
    bless $args => $class;
}

sub start_process {
    my ($self, $token) = @_;
    $self->{last_token} = $token;
    ### assign before target into parent
    $self->{parent} = $self->{target};
}

sub next_process {
    my ($self, $target) = @_;
    $self->{target} = $target;
    push(@{$self->{processed_tokens}}, $self->{last_token});
}

sub parent_type {
    my $self = shift;
    return ref $self->{parent};
}

1;
