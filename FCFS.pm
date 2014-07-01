package FCFS;
use parent 'Schedule';

use strict;
use warnings;

#dumbest possible fcfs algorithm

sub assign_job {
	my $self = shift;
	my $job = shift;
	my $requested_cpus = $job->requested_cpus;
	die "not enough processors (we need $requested_cpus, we have $self->{num_processors})" if $requested_cpus > $self->{num_processors};

	my @sorted_processors = sort {$a->cmax() <=> $b->cmax()} @{$self->{processors}};
	my @selected_processors = splice(@sorted_processors, 0, $requested_cpus);
	my $starting_time = $selected_processors[$#selected_processors]->cmax();

	$job->assign_to($starting_time, [@selected_processors]);
}

1;

