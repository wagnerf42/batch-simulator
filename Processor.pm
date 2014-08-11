package Processor;
use strict;
use warnings;

use overload
	'""' => \&stringification;

sub new {
	my ($class, $id, $cluster) = @_;

	my $self = {
		id => $id,
		cluster => $cluster,
		jobs => [],
		cmax => 0
	};

	bless $self, $class;
	return $self;
}

sub stringification {
	my ($self) = @_;
	return $self->{id};
}

sub id {
	my ($self, $id) = @_;
	$self->{id} = $id if defined $id;
	return $self->{id};
}

sub cmax {
	my ($self, $cmax) = @_;
	$self->{cmax} = $cmax if defined $cmax;
	return $self->{cmax};
}

sub assign_job {
	my ($self, $job) = @_;

	push $self->{jobs}, $job;

	my $candidate_cmax = $job->starting_time() + $job->run_time;
	$self->{cmax} = $candidate_cmax if $candidate_cmax > $self->{cmax};
}

sub available_at {
	my ($self, $starting_time, $duration) = @_;

	for my $job (@{$self->{jobs}}) {
		return 0 if ($job->starting_time < $starting_time) and ($job->ending_time > $starting_time);
		return 0 if ($job->starting_time >= $starting_time) and ($job->starting_time < $starting_time + $duration);
	}

	return 1;
}

sub jobs {
	my ($self) = @_;
	return $self->{jobs};
}

sub remove_all_jobs {
	my ($self) = @_;
	$self->{jobs} = [];
}

sub cluster_number {
	my ($self) = @_;
	return $self->{cluster};
}

1;
