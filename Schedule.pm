#!/usr/bin/perl

package Schedule;
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
		processors => []
	};

	for my $id (0..($self->{num_processors}-1)) {
		my $processor = new Processor($id);
		push $self->{processors}, $processor;
	}

	bless $self, $class;
	return $self;
}

sub fcfs {
	my $self = shift;

	for my $job (@{$self->{trace}->{jobs}}) {
		$self->assign_fcfs_job($job);
	}
}

sub assign_fcfs_job {
	my $self = shift;
	my $job = shift;
	my @sorted_processors = sort {$a->get_cmax() <=> $b->get_cmax()} @{$self->{processors}};
	my $requested_cpus = $job->get_requested_cpus();
	my @selected_processors = splice(@sorted_processors, 0, $requested_cpus);
	my $starting_time = $selected_processors[$#selected_processors]->get_cmax();
	map {$_->assign_job($job, $starting_time)} @selected_processors;
}

sub print_schedule {
	my $self = shift;

	print "Printing schedule\n";
	map {$_->print_jobs()} @{$self->{processors}};
}

1;

