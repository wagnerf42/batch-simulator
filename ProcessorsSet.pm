package ProcessorsSet;

use strict;
use warnings;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {
		processors => shift,
		processors_number => shift,
	};

	@{$self->{processors}} = sort {$a->id <=> $b->id} @{$self->{processors}};

	bless $self, $class;
	return $self;
}

sub sort_processors {
	my %processors;

	$processors{$_} = $_ for @_;
	my @sorted_ids = sort {$a <=> $b} (keys %processors);
	my $sorted_processors = [];
	push @{$sorted_processors}, $processors{$_} for @sorted_ids;
	return $sorted_processors;
}

sub contains_at_least {
	my $self = shift;
	my $n = shift;
	return (@{$self->{processors}} >= $n);
}

#reduce number of processors to given value
#tries to stay contiguous if possible
sub reduce_to {
	my ($self, $number) = @_;

	#try each position and see if we can get a contiguous block
	for my $start_index (0..$#{$self->{processors}}) {
		my $ok = 1;
		my $start_id = $self->{processors}->[$start_index]->id();
		for my $num (1..($number-1)) {
			my $index = ($start_index + $num) % @{$self->{processors}};
			my $id = $self->{processors}->[$index]->id();
			my $expected_id = ($start_id + $num) % @{$self->{processors}};
			if ($id != $expected_id) {
				$ok = 0;
				last;
			}
		}
		if ($ok) {
			$self->keep_from($start_index, $number);
			$self->{contiguous} = 1;
			return;
		}
	}
	$self->{contiguous} = 0;
	$self->keep_from(0, $number);
}

sub reduce_to_contiguous {
	my ($self, $number) = @_;

	#try each position and see if we can get a contiguous block
	for my $start_index (0..$#{$self->{processors}}) {
		my $ok = 1;
		my $start_id = $self->{processors}->[$start_index]->id();
		for my $num (1..($number-1)) {
			my $index = ($start_index + $num) % scalar @{$self->{processors}};
			my $expected_id = ($start_id + $num) % $self->{processors_number};
			my $id = $self->{processors}[$index]->id();
			if ($id != $expected_id) {
				$ok = 0;
				last;
			}
		}
		if ($ok) {
			$self->keep_from($start_index, $number);
			$self->{contiguous} = 1;
			return;
		}
	}

	# In this case it was not possible, return an empty answer
	@{$self->{processors}} = ();
}

sub reduce_to_cluster {
	my ($self, $number) = @_;

	for my $start_index (0..(scalar @{$self->{processors}} - $number)) {
		my $ok = 1;
		my $start_cluster = $self->{processors}->[$start_index]->cluster();

		for my $index (($start_index + 1)..($start_index + $number - 1)) {
			my $cluster = $self->{processors}[$index]->cluster();
			if ($cluster != $start_cluster) {
				$ok = 0;
				last;
			}
		}

		if ($ok) {
			$self->keep_from($start_index, $number);
			$self->{local} = 1;
			return;
		}
	}

	# In this case it was not possible, return an empty answer
	@{$self->{processors}} = ();
}

sub reduce_to_contiguous_cluster {
	my ($self, $number) = @_;

	for my $start_index (0..(scalar @{$self->{processors}} - $number)) {
		my $ok = 1;
		my $start_cluster = $self->{processors}->[$start_index]->cluster();
		my $start_id = $self->{processors}->[$start_index]->id();

		for my $index (($start_index + 1)..($start_index + $number - 1)) {
			my $cluster = $self->{processors}[$index]->cluster();
			my $id = $self->{processors}[$index]->id();
			my $expected_id = $start_id + $index - $start_index;

			if (($cluster != $start_cluster) or ($id != $expected_id)) {
				$ok = 0;
				last;
			}
		}

		if ($ok) {
			$self->keep_from($start_index, $number);
			$self->{local} = 1;
			$self->{contiguous} = 1;
			return;
		}
	}

	# In this case it was not possible, return an empty answer
	@{$self->{processors}} = ();
}


sub keep_from {
	my $self = shift;
	my $index = shift;
	my $n = shift;
	my @kept_processors;
	for my $i ($index..($index+$n-1)) {
		my $real_index = $i % @{$self->{processors}};
		push @kept_processors, $self->{processors}->[$real_index];
	}
	@{$self->{processors}} = @kept_processors;
}

sub processors {
	my $self = shift;
	return @{$self->{processors}};
}

sub contiguous {
	my ($self) = @_;
	return $self->{contiguous};
}

sub local {
	my ($self) = @_;
	return $self->{local};
}

1;
