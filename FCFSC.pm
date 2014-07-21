package FCFSC;
use parent 'Schedule';

use strict;
use warnings;
use List::Util qw(max reduce);
use Data::Dumper qw(Dumper);

sub compute_block {
	my $self = shift;
	my $first_processor_id = shift;
	my $requested_cpus = shift;
	my @selected_processors = @{$self->{processors}}[$first_processor_id..($first_processor_id + $requested_cpus - 1)];
	my $starting_time = max map {$_->cmax()} @selected_processors;

	return {
		starting_time => $starting_time,
		selected_processors => [@selected_processors]
	};
}

sub assign_job {
	my $self = shift;
	my $job = shift;
	my $requested_cpus = $job->requested_cpus;
	die "not enough processors (we need $requested_cpus, we have $self->{num_processors})" if $requested_cpus > $self->{num_processors};

	my @available_blocks = map {$self->compute_block($_, $requested_cpus)} (0..($self->{num_processors}-$requested_cpus));

	# First I will get all the blocks that start after the submit time
	my @available_blocks_after_submit_time = grep {$_->{starting_time} > $job->submit_time()} @available_blocks;

	# If there is at least one, pick the one that starts first
	my $best_block = reduce { $a->{starting_time} < $b->{starting_time} ? $a : $b } @available_blocks_after_submit_time;

	# If no block was found, use the one that starts before the submit time bas as close as possible to it
	$best_block = reduce { $a->{starting_time} > $b->{starting_time} ? $a : $b } @available_blocks if not defined $best_block;

	$job->assign_to(max($job->submit_time(), $best_block->{starting_time}), $best_block->{selected_processors});
}

sub print {
	my $self = shift;
	my @sorted_processors = sort {$a->cmax <=> $b->cmax} @{$self->{processors}};

	print "Details for the FCFSC schedule: {\n";
	print "\tCmax: " . $sorted_processors[$#sorted_processors]->cmax . "\n";
	print "}\n";
}

1;

