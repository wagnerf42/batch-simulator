package ProcessorRange;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use POSIX qw(floor ceil);
use List::Util qw(max min sum);
use Exporter qw(import);

use EventLine;

use overload '""' => \&stringification;

our @REDUCTION_FUNCTIONS = (
	\&reduce_to_basic,
	\&reduce_to_best_effort_contiguous,
	\&reduce_to_forced_contiguous,
	\&reduce_to_best_effort_local,
	\&reduce_to_forced_local,
);

our @EXPORT = qw(@REDUCTION_FUNCTIONS);

sub new {
	my $class = shift;
	my $self = {};

	if (@_ == 2) {
		$self->{ranges} = [@_];
	} else {
		my $processors = shift; #processors might come in different formats

		if (defined $processors) {
			if (ref $processors eq $class) {
				$self->{ranges} = [@{$processors->{ranges}}];
				$self->{size} = $processors->{size} if exists $processors->{size};
			} else {
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

	delete $self->{size};

	bless $self, $class;
	$self->check_ok();
	return $self;
}

sub check_ok {
	#return; #disabling check
	my $self = shift;
	my $last_end;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			confess "invalid range $self" unless $end >= $start;
			confess "invalid range $self" unless defined $end;
			confess "invalid range $self" unless defined $start;
			if (defined $last_end) {
				confess "bad range $self" if $start <= $last_end + 1;
				confess "bad range $self" if $end < $last_end;
			}
			$last_end = $end;
			return 1;
		}
	);
}

sub intersection {
	my @ranges = @_;
	$ranges[0]->{size} = 0;

	my $inside_segments = 0;
	my $starting_point;
	my @result;

	my @indices = (0, 0);
	my @limits = map {$#{$_->{ranges}}} @ranges;

	#loop on points from left to right
	while ($indices[0] <= $limits[0] and $indices[1] <= $limits[1]) {
		# find next event
		my $advancing_range;
		my $event_type;

		my @x = map {$ranges[$_]->{ranges}->[$indices[$_]]} (0..1);
		if ($x[0] < $x[1]) {
			$advancing_range = 0;
		} elsif($x[0] > $x[1]) {
			$advancing_range = 1;
		} elsif($indices[1] %2 == 0) {
			$advancing_range = 1;
		} else {
			$advancing_range = 0;
		}

		$event_type = $indices[$advancing_range] % 2;
		if ($event_type == 0) {
			# start
			if ($inside_segments == 1) {
				$starting_point = $x[$advancing_range];
			}
			$inside_segments++;
		} else {
			# end of segment
			if ($inside_segments == 2) {
				push @result, $starting_point;
				my $end_point = $x[$advancing_range];
				push @result, $end_point;
				$ranges[0]->{size} += $end_point - $starting_point + 1;
			}
			$inside_segments--;
		}
		$indices[$advancing_range]++;
	}

	$ranges[0]->{ranges} = [@result];
	$ranges[0]->check_ok();

}

sub remove {
	my $self = shift;
	my $other = shift;
	$self->set_operation($other, 1, 2);
}

sub add {
	my $self = shift;
	my $other = shift;
	$self->set_operation($other, 0, 1);
}

#TODO: render it readable
sub set_operation {
	my ($self, $other, $invert, $taking_limit) = @_;

	my $inside_segments = $invert;
	my $starting_point;
	my @result;

	my @lines;
	push @lines, new EventLine($self->{ranges}, 0);
	my $limit = $lines[0]->get_last_limit();
	push @lines, new EventLine($other->{ranges}, $invert);

	#loop on points from left to right
	my $completed_lines = 0;
	$completed_lines++ unless $lines[0]->is_not_completed();
	$completed_lines++ unless $lines[1]->is_not_completed($limit);

	#for union loop until two lines are completed
	#for removal loop until one line is completed
	while ($completed_lines < 3-$taking_limit) {
		# find next event
		my $advancing_range;
		my $event_type;

		my @x = map {$_->get_x()} @lines;
		if ($x[0] < $x[1]) {
			$advancing_range = 0;
		} elsif($x[0] > $x[1]) {
			$advancing_range = 1;
		} elsif($lines[1]->get_event_type() == 0) {
			$advancing_range = 1;
		} else {
			$advancing_range = 0;
		}

		$event_type = $lines[$advancing_range]->get_event_type;
		if ($event_type == 0) {
			# start
			$inside_segments++;
			if ($inside_segments == $taking_limit) {
				$starting_point = $x[$advancing_range];
			}
		} else {
			# end of segment
			if ($inside_segments == $taking_limit) {
				push @result, $starting_point;
				my $end_point = $x[$advancing_range];
				push @result, $end_point;
			}
			$inside_segments--;
		}
		$lines[$advancing_range]->advance;

		$completed_lines = 0;
		$completed_lines++ unless $lines[0]->is_not_completed();
		$completed_lines++ unless $lines[1]->is_not_completed($limit);
	}

	$self->{ranges} = [@result];
	if ($taking_limit == 1) {
		#union might generate contiguous ranges
		$self->{ranges} = sort_and_fuse_contiguous_ranges([$self->compute_pairs()]);
	}
	$self->check_ok();
	delete $self->{size};
}

sub compute_pairs {
	my ($self) = @_;
	return unless @{$self->{ranges}};
	return map { [$self->{ranges}->[2*$_], $self->{ranges}->[2*$_+1]] } (0..($#{$self->{ranges}}/2));
}

sub compute_ranges_in_clusters {
	my ($self, $cluster_size) = @_;
	my $clusters;
	my $current_cluster = -1;

	return unless @{$self->{ranges}};

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;

			my $start_cluster = floor($start/$cluster_size);
			my $end_cluster = floor($end/$cluster_size);

			for my $cluster ($start_cluster..$end_cluster) {
				my $start_point_in_cluster = max($start, $cluster*$cluster_size);
				my $end_point_in_cluster = min($end, ($cluster+1)*$cluster_size-1);
				push @{$clusters}, [] if ($cluster != $current_cluster);
				$current_cluster = $cluster;
				push @{$clusters->[$#{$clusters}]}, [$start_point_in_cluster, $end_point_in_cluster];
			}

			return 1;
		}
	);

	return $clusters;
}

sub is_empty {
	my ($self) = @_;
	return not (scalar @{$self->{ranges}});
}

sub size {
	my ($self) = @_;
	my $size = 0;

	return $self->{size} if exists $self->{size};
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			$size += $end - $start + 1;
			return 1;
		}
	);
	$self->{size} = $size;
	return $size;
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
	my ($self) = @_;
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
	my ($self, $callback) = @_;

	return unless @{$self->{ranges}};

	for my $i (0..($#{$self->{ranges}}/2)) {
		return unless $callback->($self->{ranges}->[2*$i], $self->{ranges}->[2*$i+1], @_);
	}
}

sub contains_at_least {
	my ($self, $limit) = @_;
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

sub reduce_to_basic {
	my ($self, $target_number) = @_;
	my @remaining_ranges;

	die if $target_number <= 0;

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
	delete $self->{size};
	$self->check_ok();
}

sub reduction_function {
	my $self = shift;
	my $reduction_function_index = shift;

	my $reduction_funcion = $REDUCTION_FUNCTIONS[$reduction_function_index];
	return $self->$reduction_funcion(@_);
}

sub reduce_to_forced_contiguous {
	my ($self, $target_number) = @_;
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
	delete $self->{size};
	$self->check_ok();
}

sub reduce_to_best_effort_contiguous {
	my ($self, $target_number) = @_;
	my @remaining_ranges;

	my @sorted_pairs = sort { $b->[1] - $b->[0] <=> $a->[1] - $a->[0] } $self->compute_pairs();

	for my $pair (@sorted_pairs) {
		my ($start, $end) = @{$pair};
		my $available_processors = $end + 1 - $start;
		my $taking = min($target_number, $available_processors);

		push @remaining_ranges, [ $start, $start + $taking - 1 ];

		$target_number -= $taking;
		last if $target_number == 0;
	}

	$self->{ranges} = [map {($_->[0], $_->[1])} sort {$a->[0] <=> $b->[0]} @remaining_ranges];
	delete $self->{size};
	$self->check_ok();

}

sub cluster_size {
	my ($cluster) = @_;
	return sum (map {$_->[1] - $_->[0] + 1} @{$cluster});
}

sub sort_and_fuse_contiguous_ranges {
	my $ranges = shift;
	my @sorted_ranges = sort {$a->[1] <=> $b->[1]} @{$ranges};
	my @remaining_ranges;

	push @remaining_ranges, (shift @sorted_ranges);

	for my $range (@sorted_ranges) {
		if ($range->[0] == $remaining_ranges[$#remaining_ranges]->[1] + 1) {
			$remaining_ranges[$#remaining_ranges]->[1] = $range->[1];
		} else {
			push @remaining_ranges, $range;
		}
	}

	my $result = [];
	push @{$result}, ($_->[0], $_->[1]) for @remaining_ranges;
	return $result;
}

sub reduce_to_best_effort_local {
	my ($self, $target_number, $cluster_size) = @_;
	my $remaining_ranges = [];
	my $used_clusters_number = 0;
	my $current_cluster;
	my $clusters = $self->compute_ranges_in_clusters($cluster_size);
	my @sorted_clusters = sort { cluster_size($b) - cluster_size($a) } @{$clusters};

	for my $cluster (@sorted_clusters) {
		for my $pair (@{$cluster}) {
			my ($start, $end) = @{$pair};
			my $available_processors = $end - $start + 1;
			my $taking = min($target_number, $available_processors);

			push @{$remaining_ranges}, [$start, $start + $taking - 1];
			$target_number -= $taking;
			last if $target_number == 0;
		}

		last if $target_number == 0;
	}

	$self->{ranges} = sort_and_fuse_contiguous_ranges($remaining_ranges);
	delete $self->{size};
	$self->check_ok();
}

sub reduce_to_forced_local {
	my ($self, $target_number, $cluster_size) = @_;
	my $remaining_ranges = [];
	my $used_clusters_number = 0;
	my $current_cluster;
	my $clusters = $self->compute_ranges_in_clusters($cluster_size);
	my @sorted_clusters = sort { cluster_size($b) - cluster_size($a) } @{$clusters};
	my $target_clusters_number = ceil($target_number/$cluster_size);

	for my $cluster (@sorted_clusters) {
		for my $pair (@{$cluster}) {
			my ($start, $end) = @{$pair};
			my $available_processors = $end - $start + 1;
			my $taking = min($target_number, $available_processors);

			push @{$remaining_ranges}, [$start, $start + $taking - 1];
			$target_number -= $taking;
			last if $target_number == 0;
		}

		$used_clusters_number++;

		if (($used_clusters_number == $target_clusters_number) and ($target_number > 0)) {
			$self->{ranges} = [];
			return;
		}

		last if $target_number == 0;
	}

	$self->{ranges} = sort_and_fuse_contiguous_ranges($remaining_ranges);
	delete $self->{size};
	$self->check_ok();
}

sub contiguous {
	my ($self, $processors_number) = @_;

	# Are 0 processors contiguous?
	die if $self->is_empty();
	return 1 if @{$self->{ranges}} == 2;

	if (@{$self->{ranges}} == 4) {
		return (($self->{ranges}->[0] == 0) and ($self->{ranges}->[3] == $processors_number - 1));
	} else {
		return 0;
	}
}

sub local {
	my ($self, $cluster_size) = @_;
	my $needed_clusters = ceil($self->size() / $cluster_size);
	return ($needed_clusters == $self->used_clusters($cluster_size));
}

sub used_clusters {
	my ($self, $cluster_size) = @_;
	my %used_clusters_ids;

	# Are 0 processors local?
	die if $self->is_empty();

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			my $start_cluster = floor($start/$cluster_size);
			my $end_cluster = floor($end/$cluster_size);
			$used_clusters_ids{$_} = 1 for ($start_cluster..$end_cluster);
			return 1;
		}
	);

	return scalar (keys %used_clusters_ids);
}

1;
