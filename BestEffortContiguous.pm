package BestEffortContiguous;
use parent 'Basic';
use strict;
use warnings;

use lib 'ProcessorRange/blib/lib', 'ProcessorRange/blib/arch';
use ProcessorRange;

use Data::Dumper;
use List::Util qw(min);

sub new {
	my $class = shift;

	my $self = {};

	bless $self, $class;
	return $self;
}

sub reduce {
	my $self = shift;
	my $target_number = shift;
	my $left_processors = shift;

	my @remaining_ranges;
	my @sorted_pairs = sort { $b->[1] - $b->[0] <=> $a->[1] - $a->[0] } $left_processors->compute_pairs();

	for my $pair (@sorted_pairs) {
		my ($start, $end) = @{$pair};
		my $available_processors = $end + 1 - $start;
		my $taking = min($target_number, $available_processors);

		push @remaining_ranges, [$start, $start + $taking - 1];

		$target_number -= $taking;
		last if $target_number == 0;
	}

	$left_processors->affect_ranges(ProcessorRange::sort_and_fuse_contiguous_ranges(\@remaining_ranges));
	return;
}

1;

