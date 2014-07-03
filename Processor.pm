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

	for my $job (@{$self->{jobs}}) {
		return 0 if ($job->starting_time < $starting_time) and ($job->ending_time > $starting_time);
		return 0 if ($job->starting_time >= $starting_time) and ($job->starting_time < $starting_time + $duration);
	}

	return 1;
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
