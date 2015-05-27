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

sub average_distance {
	my $self = shift;
	my $available_cpus = shift;
	my $required_cpus = shift;

	my @path;

	return $self->_reduce($available_cpus, $required_cpus, 0, \@path);
}

sub build_structure {
	my $self = shift;
	my $available_cpus = shift;

	$self->{structure} = [];

	for my $level (0..(scalar @{$self->{levels}} - 2)) {
		$self->{structure}->[$level] = [];
		for my $node (0..($self->{levels}->[$level] - 1)) {
			$self->{structure}->[$level]->[$node] = {
				size => 0,
				#distance => [],
			};
		}
	}

	my $maximum_cpus_number = $self->{levels}->[$#{$self->{levels}}];

	for my $cpu (@{$available_cpus}) {
		for my $level (0..(scalar @{$self->{levels}} - 2)) {
			my $children_number = $self->{levels}->[$level + 1]/$self->{levels}->[$level];
			my $cpus_per_children = $maximum_cpus_number/$children_number;
			my $position = $cpu/$cpus_per_children;

			$self->{structure}->[$level]->[$position]->{size}++;
		}
	}

}

sub combinations {
	my $self = shift;
	my $node = shift;
	my $level = shift;
	my $required_cpus = shift;
}

sub _reduce {
}



1;
