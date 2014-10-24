package ProcessorRange;

use strict;
use warnings;
use overload '""' => \&stringification;
use EventLine;
use Carp;
use Data::Dumper;
use POSIX qw(floor ceil);
use List::Util qw(max min sum);

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

sub check_ok {
	my $self = shift;
	my $last_end;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			if (defined $last_end) {
				die "bad range $self" if $start <= $last_end + 1;
				die "bad range $self" if $end < $last_end;
			}
			$last_end = $end;
			return 1;
		}
	);
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

sub compute_ranges_in_clusters {
	my $self = shift;
	my $cluster_size = shift;
	return unless @{$self->{ranges}};

	my $clusters;
	my $current_cluster = -1;

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
	my $self = shift;
	return not (scalar @{$self->{ranges}});
}

sub size {
	my $self = shift;
	my $size = 0;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			$size += $end - $start + 1;
			return 1;
		}
	);
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

}

sub cluster_size {
	my $cluster = shift;
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

#returns true if we use a minimal number of clusters
#needs cluster size
sub local {
	my $self = shift;
	my $cluster_size = shift;
	die "are 0 processors local ?" if $self->is_empty();
	my %used_clusters_ids;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			my $start_cluster = floor($start/$cluster_size);
			my $end_cluster = floor($end/$cluster_size);
			$used_clusters_ids{$_} = 1 for ($start_cluster..$end_cluster);
			return 1;
		}
	);

	my $needed_clusters = ceil($self->size() / $cluster_size);
	return ($needed_clusters == (keys %used_clusters_ids));
}

1;
