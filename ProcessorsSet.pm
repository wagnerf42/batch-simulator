package ProcessorsSet;

use strict;
use warnings;
use Data::Dumper;
use POSIX;

sub new {
	my ($class, $processors, $processors_number, $cluster_size) = @_;

	my $self = {
		processors => $processors,
		processors_number => $processors_number,
		cluster_size => $cluster_size,
		contiguous => 0,
		local => 0
	};

	#@{$self->{processors}} = sort {$a->id <=> $b->id} @{$self->{processors}};

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
	my ($self, $n) = @_;
	return (@{$self->{processors}} >= $n);
}

sub reduce_to_first {
	my ($self, $number) = @_;
	$self->keep_from(0, $number);
}

sub reduce_to_first_random {
	my ($self, $number) = @_;
	my @selected_processors;

	for my $i (1..$number) {
		my $index = int(rand(@{$self->{processors}}));
		push @selected_processors, $self->{processors}[$index];
		splice(@{$self->{processors}}, $index, 1);
	}

	@{$self->{processors}} = @selected_processors;
}

sub reduce_to_contiguous_best_effort {
	my ($self, $number) = @_;

	@{$self->{processors}} = sort {$a->id <=> $b->id} @{$self->{processors}};

	for my $start_index (0..$#{$self->{processors}}) {
		my $ok = 1;
		my $start_id = $self->{processors}->[$start_index]->id();

		for my $num (1..($number-1)) {
			my $index = ($start_index + $num) % @{$self->{processors}};
			my $id = $self->{processors}->[$index]->id();
			my $expected_id = ($start_id + $num) % $self->{processors_number};

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

	$self->keep_from(0, $number);
}

sub reduce_to_contiguous {
	my ($self, $number) = @_;

	@{$self->{processors}} = sort {$a->id <=> $b->id} @{$self->{processors}};

	#try each position and see if we can get a contiguous block
	for my $start_index (0..$#{$self->{processors}}) {
		my $ok = 1;
		my $start_id = $self->{processors}->[$start_index]->id();

		for my $num (1..($number-1)) {
			my $index = ($start_index + $num) % @{$self->{processors}};
			my $id = $self->{processors}[$index]->id();
			my $expected_id = ($start_id + $num) % $self->{processors_number};

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

	@{$self->{processors}} = sort {$a->id <=> $b->id} @{$self->{processors}};

	my $max_clusters_number = ceil($number/$self->{cluster_size});

	for my $start_index (0..$#{$self->{processors}}) {
		my $ok = 1;
		my $start_id = $self->{processors}->[$start_index]->id();
		my $current_cluster = $self->{processors}->[$start_index]->cluster_number();
		my $clusters_number = 1;

		for my $num (1..($number-1)) {
			my $index = ($start_index + $num) % @{$self->{processors}};
			my $cluster = $self->{processors}[$index]->cluster_number();

			if ($cluster != $current_cluster) {
				$clusters_number++;
				$current_cluster = $cluster;
			}

			if ($clusters_number > $max_clusters_number) {
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

	@{$self->{processors}} = ();
}

sub reduce_to_cluster_contiguous {
	my ($self, $number) = @_;

	@{$self->{processors}} = sort {$a->id <=> $b->id} @{$self->{processors}};

	my $max_clusters_number = ceil($number/$self->{cluster_size});

	for my $start_index (0..$#{$self->{processors}}) {
		my $ok = 1;
		my $start_id = $self->{processors}->[$start_index]->id();
		my $current_cluster = $self->{processors}->[$start_index]->cluster_number();
		my $clusters_number = 1;

		for my $num (1..($number-1)) {
			my $index = ($start_index + $num) % @{$self->{processors}};
			my $cluster = $self->{processors}[$index]->cluster_number();
			my $id = $self->{processors}->[$index]->id();
			my $expected_id = ($start_id + $num) % $self->{processors_number};

			if ($id != $expected_id) {
				$ok = 0;
				last;
			}

			if ($cluster != $current_cluster) {
				$clusters_number++;
				$current_cluster = $cluster;
			}

			if ($clusters_number > $max_clusters_number) {
				$ok = 0;
				last;
			}
		}

		if ($ok) {
			$self->keep_from($start_index, $number);
			$self->{contiguous} = 1;
			$self->{local} = 1;
			return;
		}
	}

	@{$self->{processors}} = ();
}

sub keep_from {
	my ($self, $index, $n) = @_;
	my @kept_processors;
	for my $i ($index..($index+$n-1)) {
		my $real_index = $i % scalar @{$self->{processors}};
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
