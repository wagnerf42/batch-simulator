#!/usr/bin/perl

package FCFSC;
use parent 'Schedule';

use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Job;
use Processor;

sub verify_available_block {
	my $self = shift;
	my $first_processor_id = shift;
	my $requested_cpus = shift;

	my $block = {
		first_processor_id => $first_processor_id,
		starting_time => $self->{processors}[$first_processor_id]->cmax,
		size => $requested_cpus
	};

	for my $processor_id ($first_processor_id..($first_processor_id + $requested_cpus - 1)) {
		if ($self->{processors}[$processor_id]->cmax > $block->{starting_time}) {
			$block->{starting_time} = $self->{processors}[$processor_id]->cmax;
		}
	}

	return $block;
}

sub assign_job {
	my $self = shift;
	my $job = shift;
	my $requested_cpus = $job->requested_cpus;
	my @available_blocks;

	for my $processor_id (0..($self->{num_processors} - $requested_cpus)) {
		my $block = $self->verify_available_block($processor_id, $requested_cpus);
		push @available_blocks, $block if defined $block;
	}

	print Dumper(@available_blocks);

	my @sorted_blocks = sort {$a->{starting_time} <=> $b->{starting_time}} @available_blocks;
	my @selected_processors = @{$self->{processors}}[$sorted_blocks[0]->{first_processor_id}..($sorted_blocks[0]->{first_processor_id} + $sorted_blocks[0]->{size} - 1)];
	map {$_->assign_job($job, $sorted_blocks[0]->{starting_time})} @selected_processors;
	$job->first_processor($sorted_blocks[0]->{first_processor_id});
}

1;

