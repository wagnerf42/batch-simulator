package ForcedLocal;
use parent 'Basic';
use strict;
use warnings;

use lib 'ProcessorRange/blib/lib', 'ProcessorRange/blib/arch';
use ProcessorRange;

use Data::Dumper;
use POSIX qw(ceil);
use List::Util qw(min);

sub new {
	my $class = shift;
	my $cluster_size = shift;

	my $self = {
		cluster_size => $cluster_size,
	};

	bless $self, $class;
	return $self;
}

sub reduce {
	my $self = shift;
	my $job = shift;
	my $left_processors = shift;

	my $target_number = $job->requested_cpus();

	my @remaining_ranges;
	my $used_clusters_number = 0;
	my $current_cluster;
	my $clusters = $left_processors->compute_ranges_in_clusters($self->{cluster_size});
	my @sorted_clusters = sort { ProcessorRange::cluster_size($b) - ProcessorRange::cluster_size($a) } @{$clusters};
	my $target_clusters_number = ceil($target_number/$self->{cluster_size});

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
			$left_processors->remove_all();
			return;
		}

		last if $target_number == 0;
	}

	if (@remaining_ranges) {
		$left_processors->affect_ranges(ProcessorRange::sort_and_fuse_contiguous_ranges(\@remaining_ranges));
	} else {
		$left_processors->remove_all();
	}
	return;
}

1;

