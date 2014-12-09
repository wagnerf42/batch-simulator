package Event;
use strict;
use warnings;

use overload '<' => \&is_less_than;

sub new {
	my $class = shift;

	my $self = {
		type => shift,
		timestamp => shift,
		payload => shift
	};

	bless $self, $class;
	return $self;
}

sub type {
	my ($self, $type) = @_;
	$self->{type} = $type if defined $type;
	return $self->{type};
}

sub timestamp {
	my ($self, $timestamp) = @_;
	$self->{timestamp} = $timestamp if defined $timestamp;
	return $self->{timestamp};
}

sub payload {
	my ($self, $payload) = @_;
	$self->{payload} = $payload if defined $payload;
	return $self->{payload};
}

sub is_less_than {
	my ($a, $b) = @_;
	return $a->{timestamp} < $b->{timestamp};
}

1;

