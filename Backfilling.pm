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

	print Dumper($self->{profile});
}

sub assign_job {
	my $self = shift;
	my $job = shift;

	my $profile_item_start = -1;
	my $profile_item_end = -1;

	for my $i (0..(@{$self->{profile}} - 1)) {
		if ($self->{profile}[$i]->{available_cpus} >= $job->requested_cpus) {
			$profile_item_start = $i;
			last;
		}
	}

	print "Found profile item ($self->{profile}[$profile_item_start]->{starting_time}, $self->{profile}[$profile_item_start]->{available_cpus})\n";


	#Look if there is already an entry for the end of the job's execution time
	for my $i (($profile_item_start + 1)..(@{$self->{profile}} - 1)) {
		if ($self->{profile}[$i]->{starting_time} == $self->{profile}[$profile_item_start]->{starting_time} + $job->run_time) {
			$profile_item_end = $i;
			last;
		}
	}

	if ($profile_item_end == -1) {
		my $profile_item = {
			available_cpus => $self->{num_processors},
			starting_time => $self->{profile}[$profile_item_start]->{starting_time} + $job->run_time
		};

		push $self->{profile}, $profile_item;
		$profile_item_end = @{$self->{profile}} - 1;
	}

	for my $i ($profile_item_start..($profile_item_end - 1)) {
		$self->{profile}[$i]->{available_cpus} -= $job->requested_cpus;
	}

	print "---------------------------\n";
	print Dumper($self->{profile});
}

1;

