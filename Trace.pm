package Trace;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max reduce);
use Storable qw(dclone);

use Job;
use Processor;

sub new {
	my $class = shift;
	my $self = {
		file => shift,
		jobs => [],
		status => [],
		partition_count => 0,
		needed_cpus => 0
	};

	bless $self, $class;
	return $self;
}

sub read {
	my $self = shift;

	open (FILE, $self->{file});

	while (my $line = <FILE>) {
		my @fields = split(' ', $line);

		next unless defined $fields[0];

		# Status line
		if ($fields[0] eq ';') { 
			push $self->{status}, [@fields];
		}

		# Job line
		elsif ($fields[0] ne ' ') {
			my $job = new Job(@fields);

			# Do not accept jobs with no run time
			next unless $job->run_time;

			# Do not accept jobs with no requested cpus
			next unless $job->requested_cpus;

			if ($job->requested_cpus > $self->{needed_cpus}) {
				$self->{needed_cpus} = $job->requested_cpus;
			}

			push $self->{jobs}, $job;
		}
	}
}

sub read_from_trace {
	my $self = shift;
	my $trace = shift;
	my $size = shift;

	for my $job_number (0..($size - 1)) {
		my $job_id = int(rand(@{$trace->jobs}));

		# This version is using a deep copy of the jobs so that even if the code
		# chooses the same job more then once it's ok. Maybe it's a better idea to
		# not use deep copy and instead use references and make sure no job is
		# used more then once in this case.
		my $new_job = dclone($trace->job($job_id));

		if ($new_job->requested_cpus > $self->{needed_cpus}) {
			$self->{needed_cpus} = $new_job->requested_cpus;
		}

		$new_job->job_number(scalar @{$self->{jobs}} + 1);

		push $self->{jobs}, $new_job;
	}
}

sub write {
	my $self = shift;
	my $trace_filename = shift;

	open(my $filehandle, "> $trace_filename") or die "unable to open $trace_filename";

	for my $job (@{$self->{jobs}}) {
		print $filehandle "$job\n";
	}
}


sub needed_cpus {
	my $self = shift;

	if (@_) {
		$self->{needed_cpus} = shift;
	}

	return $self->{needed_cpus};
}

sub print_jobs {
	my $self = shift;
	print join(',', @{$self->{jobs}})."\n";
}

sub jobs {
	my $self = shift;
	return $self->{jobs};
}

sub job {
	my $self = shift;
	my $job_number = shift;

	return $self->{jobs}[$job_number];
}

1;
