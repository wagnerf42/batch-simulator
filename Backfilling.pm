#!/usr/bin/perl

package Backfilling;
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Job;
use Processor;

sub new {
	my $class = shift;
	my $self = {
		trace => shift,
		num_processors => shift,
		processors => [],
		queued_jobs => [],
		profile => []
	};

	for my $id (0..($self->{num_processors} - 1)) {
		my $processor = new Processor($id);
		push $self->{processors}, $processor;
	}

	# The profile needs to start with one item stating that all processors are available on time 0
	my $profile_item = {
		available_cpus => $self->{num_processors},
		starting_time => 0
	};
	push $self->{profile}, $profile_item;

	bless $self, $class;
	return $self;
}

sub run {
	my $self = shift;

	map {$self->assign_job($_)} @{$self->{trace}->jobs};
}

sub assign_job {
	my $self = shift;
	my $job = shift;

	my $starting_time = -1;

	for my $profile_item (@{$self->{profile}}) {
		if ($profile_item->{available_cpus} >= $job->requested_cpus) {
			$starting_time = $profile_item->{starting_time};
			last;
		}
	}


}



1;

