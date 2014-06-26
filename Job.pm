#!/usr/bin/perl

package Job;
use strict;
use warnings;
use overload
    '""' => \&stringification;

sub new {
	my $class = shift;

	my $self = {
		job_number => shift,
		submit_time => shift,
		wait_time => shift,
		run_time => shift,
		allocated_cpus => shift,
		avg_cpu_time => shift,
		used_mem => shift,
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
		think_time_prec_job => shift,
	};

	bless $self, $class;
	return $self;
}

sub stringification {
	my $self = shift;

	return join(' ', 
		$self->{job_number},
		$self->{submit_time},
		$self->{wait_time},
		$self->{run_time},
		$self->{allocated_cpus},
		$self->{avg_cpu_time},
		$self->{used_mem},
		$self->{requested_cpus},
		$self->{requested_time},
		$self->{requested_mem},
		$self->{status},
		$self->{uid},
		$self->{gid},
		$self->{exec_number},
		$self->{queue_number},
		$self->{partition_number},
		$self->{prec_job_number},
		$self->{think_time_prec_job},
		$self->{first_processor});
}

sub print_time_ratio {
	my $self = shift;

	if ($self->{run_time} <= $self->{requested_time}) {
		print $self->{run_time}/$self->{requested_time} . "\n";
	}
}

sub get_requested_cpus {
	my $self = shift;

	return $self->{requested_cpus};
}

1;
