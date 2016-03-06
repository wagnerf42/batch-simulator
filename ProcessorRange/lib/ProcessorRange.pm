package ProcessorRange;

use 5.0;

use strict;
use warnings;

use Carp;
use Log::Log4perl qw(get_logger);
use POSIX qw(floor ceil);
use List::Util qw(min max sum);
use Data::Dumper;

use Platform;

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration use ProcessorRange ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our $VERSION = '0.01';

require XSLoader;
XSLoader::load('ProcessorRange', $VERSION);

use overload '""' => \&stringification;

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

sub pairs {
	my $self = shift;
	my @pairs;

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			push @pairs, [$start, $end];
			return 1;
		}
	);

	return @pairs;
}

sub check_ok {
	my $self = shift;
	my $last_end = -1;
	my $logger = get_logger('ProcessorRange::check_ok');

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;

			$logger->logdie("invalid range $self: repeated cpu ($last_end)") if $start == $last_end;
			$logger->logdie("invalid range $self: end < start ($end < $start)") if $end < $start;
			$logger->logdie("invalid range $self: start not defined") unless defined $end;
			$logger->logdie("invalid range $self: end not defined") unless defined $end;

			$last_end = $end;
			return 1;
		}
	);

	return;
}

sub ranges_in_clusters {
	my $self = shift;
	my $cluster_size = shift;

	my @clusters;
	my $current_cluster = -1;

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;

			my $start_cluster = floor($start/$cluster_size);
			my $end_cluster = floor($end/$cluster_size);

			for my $cluster ($start_cluster..$end_cluster) {
				my $start_point_in_cluster = max($start, $cluster*$cluster_size);
				my $end_point_in_cluster = min($end, ($cluster+1)*$cluster_size-1);

				push @clusters, [] if ($cluster != $current_cluster);
				push @{$clusters[-1]}, [$start_point_in_cluster, $end_point_in_cluster];

				$current_cluster = $cluster;
			}

			return 1;
		}
	);

	return @clusters;
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

sub sort_and_fuse_contiguous_ranges {
	my $ranges = shift;

	my @sorted_ranges = sort {$a->[1] <=> $b->[1]} @{$ranges};
	my @remaining_ranges;

	push @remaining_ranges, (@{shift @sorted_ranges});

	for my $range (@sorted_ranges) {
		if ($range->[0] == $remaining_ranges[-1] + 1) {
			$remaining_ranges[-1] = $range->[1];
		} else {
			push @remaining_ranges, @$range;
		}
	}

	return \@remaining_ranges;
}

sub available_cpus_in_clusters {
	my $self = shift;
	my $cluster_size = shift;

	my @available_cpus;

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;

			my $start_cluster = floor($start/$cluster_size);
			my $end_cluster = floor($end/$cluster_size);

			for my $cluster ($start_cluster..$end_cluster) {
				my $start_point_in_cluster = max($start, $cluster * $cluster_size);
				my $end_point_in_cluster = min($end, ($cluster + 1) * $cluster_size - 1);

				$available_cpus[$cluster] = {
					total_size => 0,
					cpus => [],
				} unless (defined $available_cpus[$cluster]);

				$available_cpus[$cluster]->{total_size} +=
				$end_point_in_cluster - $start_point_in_cluster + 1;

				push @{$available_cpus[$cluster]->{cpus}},
				($start_point_in_cluster..$end_point_in_cluster);
			}

			return 1;
		}
	);

	return \@available_cpus;
}

# Returns true if all processors form a contiguous block. Needs processors
# number as jobs can wrap around.
sub contiguous {
	my $self = shift;
	my $processors_number = shift;

	my @ranges = $self->pairs();

	return 1 if @ranges == 1;
	return 1 if (@ranges == 2 and $ranges[0]->[0] == 0
	and $ranges[1]->[1] == $processors_number - 1);

	return 0;
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

sub list_of_used_clusters {
	my $self = shift;
	my $cluster_size = shift;

	my %used_clusters_ids;

	my $logger = get_logger('ProcessorRange::used_clusters');

	$self->ranges_loop(
		sub {
			my ($start, $end) = @_;
			my $start_cluster = floor($start/$cluster_size);
			my $end_cluster = floor($end/$cluster_size);
			$used_clusters_ids{$_} = 1 for ($start_cluster..$end_cluster);
			return 1;
		}
	);

	return [keys %used_clusters_ids];
}

1;

