package FCFS;
use parent 'Schedule';

use strict;
use warnings;

use List::Util qw(max);
use ProcessorsSet;

sub assign_job {
	my $self = shift;
	my $job = shift;
	my $requested_cpus = $job->requested_cpus;

	@{$self->{processors}} = sort {$a->cmax() <=> $b->cmax()} @{$self->{processors}};
	my @selected_processors = @{$self->{processors}}[0..($requested_cpus - 1)];
	my $starting_time = max ($job->submit_time(), $selected_processors[$#selected_processors]->cmax());

	my @candidate_processors;
	for my $processor (@{$self->{processors}}) {
		push @candidate_processors, $processor if $processor->available_at($starting_time, $job->run_time());
	}

	# Best effort contiguous
	my $set = new ProcessorsSet(@candidate_processors);
	$set->reduce_to($requested_cpus);
	$job->assign_to($starting_time, [$set->processors()]);
}

1;
