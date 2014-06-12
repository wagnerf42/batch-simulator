#!/usr/bin/perl

package Job;
use strict;
use warnings;

sub new {
	my $class = shift;

	my $self = {
		job_number => shift,
		submit_time => shift,
		wait_time => shift,
		run_time => shift,
		allocated_cpus => shift,
		avg_cpu_time => shift,
		used_memory => shift,
		requested_cpus => shift,
		requested_time => shift,
		requested_mem => shift,
		status => shift,
		uid => shift,
		gid => shift,
		exec_number => shift,
		queue_number => shift,
		partition_number => shift,
		prec_job_number => shift,
		think_time_prec_job => shift
	};

	bless $self, $class;
	return $self;
}

sub print {
	my $self = shift;

	print "Job with number $self->{job_number}\n";
}

1;
