package FCFS;
use parent 'Schedule';

use strict;
use warnings;

use List::Util qw(max);
use ProcessorsSet;

sub assign_job {
	my ($self, $job) = @_;
	my $requested_cpus = $job->requested_cpus;

	print "Job " . $job->job_number() . "\n";

	@{$self->{processors}} = sort {$a->cmax() <=> $b->cmax()} @{$self->{processors}};

	my @selected_processors = @{$self->{processors}}[0..($requested_cpus - 1)];
	my $starting_time = max ($job->submit_time(), $selected_processors[$#selected_processors]->cmax());
	
	my @candidate_processors = grep {$_->cmax() <= $starting_time} @{$self->{processors}};

	my $set = new ProcessorsSet(\@candidate_processors, scalar @{$self->{processors}}, $self->{cluster_size});

	if ($self->{version} == 0) {
		$set->reduce_to_first($requested_cpus);
	}

	elsif ($self->{version} == 1) {
		$set->reduce_to_contiguous_best_effort($requested_cpus);
	}

	elsif ($self->{version} == 2) {
		$set->reduce_to_first_random($requested_cpus);
	}

	$job->assign_to($starting_time, [$set->processors()]);
}

1;
