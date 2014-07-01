#!/usr/bin/perl

package FCFSC;
use parent 'Schedule';

use strict;
use warnings;
use List::Util qw(max reduce);

use Trace;
use Job;
use Processor;

sub compute_block {
	my $self = shift;
	my $first_processor_id = shift;
	my $requested_cpus = shift;
	my @processors = @{$self->{processors}};
	my @selected_processors = splice(@processors, $first_processor_id, $requested_cpus);
	my $starting_time = max map {$_->cmax()} @selected_processors;

	return {
		first_processor_id => $first_processor_id,
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
	my $best_block = reduce { $a->{starting_time} < $b->{starting_time} ? $a : $b } @available_blocks;

	$_->assign_job($job, $best_block->{starting_time}) for @{$best_block->{selected_processors}};
	$job->first_processor($best_block->{first_processor_id}); #TODO : why do we need that ?
}

1;

