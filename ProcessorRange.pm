package ProcessorRange;

use strict;
use warnings;
use overload '""' => \&stringification;
use Carp;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {
		local => 0,
		contiguous => 0
	};

	if (@_ == 2) {
		$self->{ranges} = [@_];
	} else {
		my $processors = shift; #processors might come in different formats

		if (defined $processors) {
			if (ref $processors eq $class) {
				#copy constructor
				$self->{ranges} = [@{$processors->{ranges}}];
			} else {
				#take a list of ids
				$self->{ranges} = [];
				if (@{$processors}) {
					my @processors_ids = sort {$a <=> $b} @{$processors};

					my $previous_id;

					for my $id (@processors_ids) {
						if ((not defined $previous_id) or ($previous_id != $id -1)) {
							push @{$self->{ranges}}, $previous_id if defined $previous_id;
							push @{$self->{ranges}}, $id;
						}
						$previous_id = $id;
					}
					push @{$self->{ranges}}, $previous_id;
				}
			}
		}
	}

	bless $self, $class;
	return $self;
}


sub intersection {
	my @ranges = @_;

	my $inside_segments = 0;
	my $starting_point;
	my @result;

	my @indices = (0, 0);
	#loop on points from left to right
	while (($indices[0] <= $#{$ranges[0]->{ranges}}) and ($indices[1] <= $#{$ranges[1]->{ranges}})) {
		# find next event
		my $advancing_range;
		my $event_type;

		if ($ranges[0]->{ranges}->[$indices[0]] <= $ranges[1]->{ranges}->[$indices[1]]) {
			$advancing_range = 0;
		} else {
			$advancing_range = 1;
		}

		$event_type = $indices[$advancing_range] % 2;
		if ($event_type == 0) {
			# start
			if ($inside_segments == 1) {
				$starting_point = $ranges[$advancing_range]->{ranges}->[$indices[$advancing_range]];
			}
			$inside_segments++;
		} else {
			# end of segment
			if ($inside_segments == 2) {
				push @result, $starting_point;
				my $end_point = $ranges[$advancing_range]->{ranges}->[$indices[$advancing_range]];
				push @result, $end_point;
			}
			$inside_segments--;
		}
		$indices[$advancing_range]++;
	}

	$ranges[0]->{ranges} = [@result];
}

#TODO: factorize and simplify code
sub remove {
	my @ranges = @_;

	my $inside_segments = 1;
	my $starting_point;
	my @result;

	my @indices = (0, 0);
	#loop on points from left to right
	while ($indices[0] <= $#{$ranges[0]->{ranges}}) {
		# find next event
		my $advancing_range;
		my $event_type;

		if (($indices[1] > $#{$ranges[1]->{ranges}}) or ($ranges[0]->{ranges}->[$indices[0]] <= $ranges[1]->{ranges}->[$indices[1]])) {
			$advancing_range = 0;
		} else {
			$advancing_range = 1;
		}

		$event_type = $indices[$advancing_range] % 2;
		if ($advancing_range == 1) {
			#invert events for removal for second range
			$event_type = 1 - $event_type;
		}
		if ($event_type == 0) {
			# start
			if ($inside_segments == 1) {
				$starting_point = $ranges[$advancing_range]->{ranges}->[$indices[$advancing_range]];
				$starting_point += $advancing_range;
			}
			$inside_segments++;
		} else {
			# end of segment
			if ($inside_segments == 2) {
				my $end_point = $ranges[$advancing_range]->{ranges}->[$indices[$advancing_range]];
				$end_point -= $advancing_range; # REMOVAL_OPERATION stops before
				if ($end_point >= $starting_point) {
					push @result, $starting_point;
					push @result, $end_point;
				}
			}
			$inside_segments--;
		}
		$indices[$advancing_range]++;
	}

	$ranges[0]->{ranges} = [@result];
}

#compute a list of paired (start,end) ranges
sub compute_pairs {
	my $self = shift;
	return unless @{$self->{ranges}};
	return map { [$self->{ranges}->[2*$_], $self->{ranges}->[2*$_+1]] } (0..($#{$self->{ranges}}/2));
}

sub is_empty {
	my $self = shift;
	return not (scalar @{$self->{ranges}});
}

sub processors_ids {
	my ($self, $processors_ids) = @_;

	my @ids;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			push @ids, ($start..$end);
			return 1;
		}
	);
	return @ids;
}

sub stringification {
	my $self = shift;
	my @strings;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			push @strings, "[$start-$end]";
			return 1;
		}
	);
	return join(' ', @strings);
}

sub ranges_loop {
	my $self = shift;
	my $callback = shift;
	return unless @{$self->{ranges}};
	for my $i (0..($#{$self->{ranges}}/2)) {
		return unless $callback->($self->{ranges}->[2*$i], $self->{ranges}->[2*$i+1], @_);
	}
}

sub contains_at_least {
	my $self = shift;
	my $limit = shift;
	my $count = 0;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			$count += 1 + $end - $start;
			return 1;
		}
	);
	return ($count >= $limit);
}

sub reduce_to_first {
	my $self = shift;
	my $target_number = shift;
	my @remaining_ranges;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			my $taking = $target_number;
			my $available_processors = $end + 1 - $start;
			if ($available_processors < $target_number) {
				$taking = $available_processors;
			}
			push @remaining_ranges, $start;
			push @remaining_ranges, $start + $taking - 1;
			$target_number -= $taking;
			return ($target_number != 0);
		},
	);
	$self->{ranges} = [@remaining_ranges];
}

sub reduce_to_forced_contiguous {
	my $self = shift;
	my $target_number = shift;
	my @remaining_ranges;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			my $available_processors = $end + 1 - $start;
			if ($available_processors < $target_number) {
				return 1;
			}

			push @remaining_ranges, $start;
			push @remaining_ranges, $start + $target_number - 1;
			return 0;
		},
	);

	$self->{ranges} = [@remaining_ranges];
}

sub reduce_to_best_effort_contiguous {
	my $self = shift;
	my $target_number = shift;
	my $remaining_ranges = [];

	my @sorted_pairs = sort { $b->[1] - $b->[0] <=> $a->[1] - $a->[0] } $self->compute_pairs();

	for my $pair (@sorted_pairs) {
		my ($start, $end) = @{$pair};
		my $available_processors = $end + 1 - $start;
		my $taking = min($target_number, $available_processors);

		push @{$remaining_ranges}, $start;
		push @{$remaining_ranges}, $start + $taking - 1;

		$target_number -= $taking;
		last if $target_number == 0;
	}

	$self->{ranges} = $remaining_ranges;

	if (scalar @{$self->{ranges}} == 1) {
		$self->{contiguous} = 1;
	}
}

sub reduce_to_best_effort_local {
	my ($self, $target_number, $cluster_size) = @_;
	my $remaining_ranges = [];

	my $used_clusters_number = 0;
	my $current_cluster;

	my @sorted_pairs = sort { $b->[1] - $b->[0] <=> $a->[1] - $a->[0] } $self->compute_pairs();

	for my $pair (@sorted_pairs) {
		my ($start, $end) = @{$pair};
		my $available_processors = $end - $start + 1;
		my $taking = min($target_number, $available_processors);

		# check if the processors are in the same cluster or not
		if ($start/$cluster_size != $end/$cluster_size) {
			$current_cluster = $end/$cluster_size;
			$used_clusters_number += ($start/$cluster_size != $current_cluster) ? 2 : 1;
		}

		elsif ($start/$cluster_size != $current_cluster) {
			$current_cluster = $start/$cluster_size;
			$used_clusters_number += 1;
		}


		push @{$remaining_ranges}, $start;
		push @{$remaining_ranges}, $start + $taking - 1;
		$target_number -= $taking;
		last if $target_number == 0;
	}

	$self->{ranges} = $remaining_ranges;

	if ($used_clusters_number == ceil($target_number/$cluster_size)) {
		$self->{local} = 1;
	}
}

#returns true if all processors form a contiguous block
#needs processors number as jobs can wrap around
sub contiguous {
	my $self = shift;
	my $processors_number = shift;
	die "are 0 processors contiguous ?" if $self->is_empty();
	return 1 if @{$self->{ranges}} == 2;
	if (@{$self->{ranges}} == 4) {
		#complex case
		return (($self->{ranges} == 0) and ($self->{ranges}->[4] == $processors_number - 1));
	} else {
		return 0;
	}
}

#returns true if all processors fall within the same cluster
#needs cluster size
sub local {
	my $self = shift;
	my $cluster_size = shift;
	die "are 0 processors local ?" if $self->is_empty();
	my $first_cluster_id = $self->{ranges}->[0] % $cluster_size;
	for my $processor_id (@{$self->{ranges}}) {
		my $cluster_id = $processor_id % $cluster_size;
		return 0 if $cluster_id != $first_cluster_id;
	}
	return 1;
}

1;
