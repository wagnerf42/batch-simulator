package Event;
use strict;
use warnings;

use overload '<=>' => \&three_way_comparison, '""' => \&stringification;

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
	my $self = shift;
	my $type = shift;

	$self->{type} = $type if (defined $type);

	return $self->{type};
}

sub timestamp {
	my $self = shift;
	my $timestamp = shift;

	$self->{timestamp} = $timestamp if (defined $timestamp);

	return $self->{timestamp};
}

sub payload {
	my $self = shift;
	my $payload = shift;

	$self->{payload} = $payload if (defined $payload);

	return $self->{payload};
}

sub three_way_comparison {
	my $self = shift;
	my $other = shift;
	my $inverted = shift;

	return $self->{type} <=> $other->{type} if
	($self->{timestamp} == $other->{timestamp});

	return $self->{timestamp} <=> $other->{timestamp};
}

sub stringification {
	my $self = shift;
	return "[$self->{type}, $self->{timestamp}, ($self->{payload})]";
}

1;

