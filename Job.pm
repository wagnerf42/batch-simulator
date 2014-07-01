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
		$self->{first_processor}
	);
}

sub print_time_ratio {
	my $self = shift;

	if ($self->{run_time} <= $self->{requested_time}) {
		print $self->{run_time}/$self->{requested_time} . "\n";
	}
}

sub requested_cpus {
	my $self = shift;

	if (@_) {
		$self->{requested_cpus} = shift;
	}

	return $self->{requested_cpus};
}

sub run_time {
	my $self = shift;

	if (@_) {
		$self->{run_time} = shift;
	}

	return $self->{run_time};
}

sub starting_time {
	my $self = shift;

	if (@_) {
		$self->{starting_time} = shift;
	}

	return $self->{starting_time};
}

sub save_svg {
	my $self = shift;
	my $fh = shift;
	my $processor_id = shift;

	my $default_time_ratio = 5;
	my $default_processor_ratio = 20;

	print $fh "\t<rect x=\"" . $self->{starting_time} * $default_time_ratio . "\" y=\"" . $processor_id * $default_processor_ratio . "\" width=\"" . $self->{run_time} * $default_time_ratio . "\" height=\"20\" style=\"fill:blue;stroke:black;stroke-width:1;fill-opacity:0.2;stroke-opacity:0.8\" />\n";
	print $fh "\t<text x=\"" . ($self->{starting_time} * $default_time_ratio + 4) . "\" y=\"" . ($processor_id * $default_processor_ratio + 15) . "\" fill=\"black\">" . $self->{job_number} . "</text>\n";
}

sub assign_to {
	my $self = shift;
	$self->{starting_time} = shift;
	$self->{assigned_processors} = shift;
	$_->assign_job($self, $self->{starting_time}) for @{$self->{assigned_processors}};
}

1;
