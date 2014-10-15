package ProcessorRange;

use strict;
use warnings;
use overload '""' => \&stringification;
use EventLine;
use Carp;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {};

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
	set_operation(@_, 0);
}

sub remove {
	set_operation(@_, 1);
}

sub set_operation {
	my ($self, $other, $invert) = @_;

	my $inside_segments = $invert;
	my $starting_point;
	my @result;

	my @lines;
	push @lines, new EventLine($self->{ranges}, 0);
	my $limit = $lines[0]->get_last_limit();
	push @lines, new EventLine($other->{ranges}, $invert);

	#loop on points from left to right
	while ($lines[0]->is_not_completed() and $lines[1]->is_not_completed($limit)) {
		# find next event
		my $advancing_range;
		my $event_type;

		if ($lines[0]->get_x() < $lines[1]->get_x()) {
			$advancing_range = 0;
		} else {
			$advancing_range = 1;
		}

		$event_type = $lines[$advancing_range]->get_event_type;
		if ($event_type == 0) {
			# start
			if ($inside_segments == 1) {
				$starting_point = $lines[$advancing_range]->get_x();
			}
			$inside_segments++;
		} else {
			# end of segment
			if ($inside_segments == 2) {
				push @result, $starting_point;
				my $end_point = $lines[$advancing_range]->get_x();
				push @result, $end_point;
			}
			$inside_segments--;
		}
		$lines[$advancing_range]->advance;
	}

	$self->{ranges} = [@result];
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

	print Dumper(@sorted_pairs);

	for my $pair (@sorted_pairs) {
		my ($start, $end) = @{$pair};
		my $available_processors = $end + 1 - $start;
		my $taking = ($available_processors > $target_number)?$target_number:$available_processors;

		push @{$remaining_ranges}, $start;
		push @{$remaining_ranges}, $start + $taking - 1;
		$target_number -= $taking;
		last if $target_number == 0;
	}
	$self->{ranges} = $remaining_ranges;
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
