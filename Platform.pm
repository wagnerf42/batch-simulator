package Platform;
use strict;
use warnings;

sub new {
	my $class = shift;
	my $levels = shift;

	my $self = {
		levels => $levels,
	};

	bless $self, $class;
	return $self;
}

sub reduce {
	my $self = shift;
	my $level = shift;
	my $available_cpus = shift;
	my $required_cpus = shift;

	# No children
	return if $level == scalar $self->{levels};




}



1;
