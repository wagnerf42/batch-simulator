package Trace;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max reduce);
use Storable qw(dclone);

use Job;
use Processor;

sub new_from_swf {
	my $class = shift;
	my $self = {
		file => shift,
		jobs => [],
		status => [],
		partition_count => 0,
		needed_cpus => 0
	};

	open (FILE, $self->{file}) or die "unable to open $self->{file}";

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
			next unless $job->requested_cpus > 0;

			if ($job->requested_cpus > $self->{needed_cpus}) {
				$self->{needed_cpus} = $job->requested_cpus;
			}

			push $self->{jobs}, $job;
		}
	}

	bless $self, $class;
	return $self;
}

#TODO Should this code use the references for the new jobs or deep copies?
sub new_block_from_trace {
	my $class = shift;
	my $self = {
		trace => shift,
		size => shift,
		jobs => [],
		status => [],
		partition_count => 0,
		needed_cpus => 0
	};

	my $start_point = int(rand(scalar @{$self->{trace}->jobs} - $self->{size} + 1));
	my @selected_jobs = @{$self->{trace}->jobs}[$start_point..($start_point + $self->{size} - 1)];
	push $self->{jobs}, @selected_jobs;

	$self->{needed_cpus} = max map {$_->requested_cpus} @{$self->{jobs}};

	bless $self, $class;
	return $self;
}

sub new_from_trace {
	my $class = shift;
	my $self = {
		trace => shift,
		size => shift,
		jobs => [],
		status => [],
		partition_count => 0,
		needed_cpus => 0
	};

	for my $job_number (0..($self->{size} - 1)) {
		my $job_id = int(rand(@{$self->{trace}->jobs}));
		my $new_job = dclone($self->{trace}->job($job_id));

		if ($new_job->requested_cpus > $self->{needed_cpus}) {
			$self->{needed_cpus} = $new_job->requested_cpus;
		}

		$new_job->job_number(scalar @{$self->{jobs}} + 1);

		push $self->{jobs}, $new_job;
	}

	bless $self, $class;
	return $self;
}

sub write_to_file {
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

sub number_of_jobs {
	my $self = shift;

	return scalar @{$self->{jobs}};
}

sub remove_large_jobs {
	my $self = shift;
	my $limit = shift;

	my @left_jobs = grep {$_->requested_cpus() <= $limit} @{$self->{jobs}};
	$self->{jobs} = [@left_jobs];
}

1;
