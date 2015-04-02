package ProcessorRange;

use 5.0;
use strict;
use warnings;
use overload '""' => \&stringification;
use Carp;
use Log::Log4perl qw(get_logger);

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration use ProcessorRange ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ('all' => [qw()]);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @REDUCTION_FUNCTIONS = (
	\&reduce_to_basic,
	\&reduce_to_best_effort_contiguous,
	\&reduce_to_forced_contiguous,
	\&reduce_to_best_effort_local,
	\&reduce_to_forced_local,
);

our @EXPORT = qw(@REDUCTION_FUNCTIONS);
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('ProcessorRange', $VERSION);

sub new {
	my $class = shift;
	my $self;

	if (@_ == 1) {
		my $original_range = shift;
		$self = copy_range($original_range);
	} else {
		die unless (@_ % 2) == 0;
		my $limits = [@_];
		$self = new_range($limits);
	}

	return $self;
}

sub remove {
	my $self = shift;
	my $other = shift;
	my $inverted_other = $other->invert($self->get_last());

	$self->intersection($inverted_other);
	$inverted_other->free_allocated_memory();

	return;
}

sub compute_pairs {
	my $self = shift;
	my @pairs;
	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			push @pairs, [$start, $end];
			return 1;
		}
	);

	return;
}

sub compute_ranges_in_clusters {
	my $self = shift;
	my $cluster_size = shift;
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

sub processors_ids {
	my $self = shift;
	my $processors_ids = shift;
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

sub contains_at_least {
	my $self = shift;
	my $limit = shift;

	return $self->size() >= $limit;
}

sub reduce_to_basic {
	my $self = shift;
	my $target_number = shift;
	my @remaining_ranges;

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			my $taking = $target_number;
			my $available_processors = $end + 1 - $start;

			$taking = $available_processors if ($available_processors < $target_number);

			push @remaining_ranges, $start;
			push @remaining_ranges, $start + $taking - 1;
			$target_number -= $taking;
			return ($target_number != 0);
		}
	);

	$self->affect_ranges([@remaining_ranges]);

	return;
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

	$self->affect_ranges([@remaining_ranges]);

	return;
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

	$self->affect_ranges([@remaining_ranges]);

	return;
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
	my @remaining_ranges;
	my $used_clusters_number = 0;
	my $current_cluster;
	my $clusters = $self->compute_ranges_in_clusters($cluster_size);
	my @sorted_clusters = sort { cluster_size($b) - cluster_size($a) } @{$clusters};

	for my $cluster (@sorted_clusters) {
		for my $pair (@{$cluster}) {
			my ($start, $end) = @{$pair};
			my $available_processors = $end - $start + 1;
			my $taking = min($target_number, $available_processors);

			push @remaining_ranges, [$start, $start + $taking - 1];
			$target_number -= $taking;
			last if $target_number == 0;
		}

		last if $target_number == 0;
	}

	$self->affect_ranges([@remaining_ranges]);

	return;
}

sub reduce_to_forced_local {
	my ($self, $target_number, $cluster_size) = @_;
	my @remaining_ranges;
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

			push @remaining_ranges, [$start, $start + $taking - 1];
			$target_number -= $taking;
			last if $target_number == 0;
		}

		$used_clusters_number++;

		if (($used_clusters_number == $target_clusters_number) and ($target_number > 0)) {
			$self->remove_all();
			return;
		}

		last if $target_number == 0;
	}

	$self->affect_ranges([@remaining_ranges]);

	return;
}

#returns true if all processors form a contiguous block
#needs processors number as jobs can wrap around
sub contiguous {
	my $self = shift;
	my $processors_number = shift;
	my @ranges;
	my $logger = get_logger('ProcessorRange::contiguous');

	$logger->logdie('are 0 processors contiguous ?') if $self->is_empty();

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			push @ranges, ($start, $end);
			return 1;
		}
	);

	return 1 if @ranges == 2;

	if (@ranges == 4) {
		#complex case
		return (($ranges[0] == 0) and ($ranges[3] == $processors_number - 1));
	} else {
		return 0;
	}
}

sub local {
	my $self = shift;
	my $cluster_size = shift;
	my $needed_clusters = ceil($self->size() / $cluster_size);

	return ($needed_clusters == $self->used_clusters($cluster_size));
}

sub used_clusters {
	my $self = shift;
	my $cluster_size = shift;
	my %used_clusters_ids;
	my $logger = get_logger('ProcessorRange::used_clusters');

	$logger->logdie('are 0 processors local ?') if $self->is_empty();

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

