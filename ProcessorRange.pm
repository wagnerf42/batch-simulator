package ProcessorRange;

use strict;
use warnings;
use overload '""' => \&stringification;
use Carp;
use Data::Dumper;

sub new {
	my $class = shift;
	my $processor_ids = shift;
	my $self = {};
	my @processor_ids = sort {$a <=> $b} @{$processor_ids};

	bless $self, $class;

	$self->processors_ids(\@processor_ids);

	return $self;
}

sub intersection {
	# ranges[0] is $self and ranges[1] is other
	my @ranges = @_;

	my $inside_segments = 0;
	my $starting_point;
	my @result;

	my @indices = (0, 0);
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
				push @result, $ranges[$advancing_range]->{ranges}->[$indices[$advancing_range]];
			}
			$inside_segments--;
		}
		$indices[$advancing_range]++;
	}

	$ranges[0]->{ranges} = [@result];
}

sub is_empty {
	my $self = shift;
	return scalar @{$self->{ranges}};
}

sub processors_ids {
	my ($self, $processors_ids) = @_;

	if (defined $processors_ids) {
		$self->{ranges} = [];
		return unless @{$processors_ids};
		my $previous_id;

		for my $id (@{$processors_ids}) {
			if ((not defined $previous_id) or ($previous_id != $id -1)) {
				push @{$self->{ranges}}, $previous_id if defined $previous_id;
				push @{$self->{ranges}}, $id;
			}
			$previous_id = $id;
		}
		push @{$self->{ranges}}, $previous_id;
	} else {
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

#TODO Implement
sub sort_ranges_by_size {
	my ($self) = @_;
	$self->ranges_loop(
		sub {
		}
	);
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

	if (scalar @remaining_ranges) {
		$self->{ranges} = [@remaining_ranges];
	} else {
		$self->reduce_to_first($target_number);
	}
}

1;
