package Event;
use strict;
use warnings;

use overload '<=>' => \&three_way_comparison;

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

sub three_way_comparison {
	my ($self, $other, $inverted) = @_;
	return $self->{type} <=> $other->{type} if ($self->{timestamp} == $other->{timestamp});
	return $self->{timestamp} <=> $other->{timestamp};
}

1;

