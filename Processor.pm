package Processor;
use strict;
use warnings;

sub new {
	my $class = shift;
	my $self = {
		id => shift,
		jobs => [],
		cmax => 0
	};

	bless $self, $class;
	return $self;
}

sub id {
	my $self = shift;

	if (@_) {
		$self->{id} = shift;
	}

	return $self->{id};
}

sub cmax {
	my $self = shift;

	if (@_) {
		$self->{cmax} = shift;
	}

	return $self->{cmax};
}

sub assign_job {
	my $self = shift;
	my $job = shift;

	push $self->{jobs}, $job;
	@{$self->{jobs}} = sort {$a->starting_time <=> $b->starting_time} @{$self->{jobs}};

	my $candidate_cmax = $job->starting_time() + $job->run_time;
	$self->{cmax} = $candidate_cmax if $candidate_cmax > $self->{cmax};
}

sub available_at {
	my $self = shift;
	my $starting_time = shift;
	my $duration = shift;

	my $current_job;
	my $next_job;

	for my $i (0..$#{$self->{jobs}}) {
		# There is one job running
		if (($self->{jobs}[$i]->starting_time < $starting_time) && ($self->{jobs}[$i]->starting_time + $self->{jobs}[$i]->run_time > $starting_time)) {
			$current_job = $i;
			last;
		}

		# There is no job running and the next job was found
		if ($self->{jobs}[$i]->starting_time >= $starting_time) {
			$next_job = $i;
			last;
		}
	}

	# Processor is being used by a job
	return 0 if defined $current_job;

	# Processor is available if there is no next job
	return 1 if not defined $next_job;

	return $self->{jobs}[$next_job]->starting_time - ($self->{jobs}[$next_job - 1]->starting_time + $self->{jobs}[$next_job-1]->run_time) >= $duration ? 1 : 0;
}

sub print_jobs {
	my $self = shift;
	print "Jobs for processor with id $self->{id} and cmax $self->{cmax}:\n";
	print $_->stringification()."\n" for @{$self->{jobs}};
}

sub jobs {
	my $self = shift;

	if (@_) {
		$self->{jobs} = shift;
	}

	return $self->{jobs};
}

1;
