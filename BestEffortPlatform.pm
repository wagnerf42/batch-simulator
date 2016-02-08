package BestEffortPlatform;
use parent 'Basic';
use strict;
use warnings;

use lib 'ProcessorRange/blib/lib', 'ProcessorRange/blib/arch';
use ProcessorRange;

use Data::Dumper;

sub new {
	my $class = shift;
	my $platform_levels = shift;

	my $self = {
		platform_levels => $platform_levels,
	};

	bless $self, $class;
	return $self;
}

sub reduce {
	my $self = shift;
	my $target_number = shift;
	my $left_processors = shift;

	my $cluster_size = $self->{platform_levels}->[$#{$self->{platform_levels}}]/$self->{platform_levels}->[$#{$self->{platform_levels}} - 1];

	my $available_cpus = $left_processors->available_cpus_in_clusters($cluster_size);
	my $platform = Platform->new($self->{platform_levels});
	my $cpus_structure = $platform->build_structure($available_cpus);
	my $chosen_ranges = $left_processors->choose_cpus_best_effort($cpus_structure, $target_number);

	$left_processors->affect_ranges(ProcessorRange::sort_and_fuse_contiguous_ranges($chosen_ranges));
	return;
}

1;

