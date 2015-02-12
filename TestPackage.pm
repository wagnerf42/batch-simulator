package TestPackage;
use strict;
use warnings;

use overload
	'""' => \&_stringification,
	'<=>' => \&_three_way_comparison,
;

sub new {
	my ($class, $value) = @_;

	my $self = {
		value => $value
	};

	bless $self, $class;
	return $self;
}

sub _stringification {
	my ($self) = @_;
	return $self->{value};
}

sub _three_way_comparison {
	my ($self, $other, $inverted) = @_;
	return $other <=> $self->{value} if $inverted;
	return $self->{value} <=> $other;
}

sub key {
	my $self = shift;
	return $self->{value};
}

1;
