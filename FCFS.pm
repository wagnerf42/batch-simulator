#!/usr/bin/perl

package FCFS;
use parent 'Schedule';

use strict;
use warnings;

use Trace;
use Job;
use Processor;

sub assign_job {
	my $self = shift;
	my $job = shift;
	my $requested_cpus = $job->requested_cpus;

	my @sorted_processors = sort {$a->cmax <=> $b->cmax} @{$self->{processors}};
	my @selected_processors = splice(@sorted_processors, 0, $requested_cpus);

	my $starting_time = $selected_processors[$#selected_processors]->cmax;

	$job->first_processor($selected_processors[0]->id);

	map {$_->assign_job($job, $starting_time)} @selected_processors;
}

1;

