package Trace;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max reduce);
use Storable qw(dclone);

use Job;
use Processor;
use Database;

sub new_from_swf {
	my $class = shift;
	my $self = {
		file => shift,
		jobs => [],
		status => [],
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

			if ($job->requested_cpus > $self->{needed_cpus}) {
				$self->{needed_cpus} = $job->requested_cpus;
			}

			push $self->{jobs}, $job;
		}
	}

	bless $self, $class;
	return $self;
}

sub fix_submit_times {
	my $self = shift;

	return if (!$self->{jobs}[0]->submit_time());

	my $first_submit_time = $self->{jobs}[0]->submit_time();
	$_->submit_time($_->submit_time() - $first_submit_time) for @{$self->{jobs}};
}

#TODO Should this code use the references for the new jobs or deep copies?
sub new_block_from_trace {
	my $class = shift;
	my $self = {
		trace => shift,
		size => shift,
		status => [],
		partition_count => 0,
		needed_cpus => 0
	};

	my $start_point = int(rand(scalar @{$self->{trace}->jobs} - $self->{size} + 1));
	my @selected_jobs = @{$self->{trace}->jobs}[$start_point..($start_point + $self->{size} - 1)];
	my $first_submit_time = $selected_jobs[0]->submit_time();
	$_->submit_time($_->submit_time()-$first_submit_time) for @selected_jobs;

	$self->{jobs} = [ @selected_jobs ];

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
		needed_cpus => 0
	};

	for my $job_number (0..($self->{size} - 1)) {
		my $job_id = int(rand(@{$self->{trace}->jobs}));
		my $new_job = dclone($self->{trace}->job($job_id));

		$self->{needed_cpus} = max($self->{needed_cpus}, $new_job->requested_cpus);
		$new_job->job_number(scalar @{$self->{jobs}} + 1);
		push $self->{jobs}, $new_job;
	}

	bless $self, $class;
	return $self;
}

sub new_from_database {
	my $class = shift;
	my $self = {
		trace_id => shift,
		jobs => [],
		status => [],
		needed_cpus => 0
	};

	my $database = Database->new();
	my $trace_ref = $database->get_trace_ref($self->{trace_id});
	my @job_refs = $database->get_job_refs($self->{trace_id});

	for my $job_ref (@job_refs) {
		my $job = Job->new($job_ref->{job_number}, $job_ref->{submit_time}, $job_ref->{wait_time}, $job_ref->{run_time}, $job_ref->{allocated_cpus}, $job_ref->{avg_cpu_time}, $job_ref->{used_mem}, $job_ref->{requested_cpus}, $job_ref->{requested_time}, $job_ref->{requested_mem}, $job_ref->{status}, $job_ref->{uid}, $job_ref->{gid}, $job_ref->{exec_number}, $job_ref->{queue_number}, $job_ref->{partition_number}, $job_ref->{prec_job_number}, $job_ref->{think_time_prec_job});

		$self->{needed_cpus} = max($self->{needed_cpus}, $job->requested_cpus);
		push $self->{jobs}, $job;
	}

	bless $self, $class;
	return $self;
}

sub reset_submit_times {
	my $self = shift;

	$_->submit_time(0) for (@{$self->{jobs}});
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

sub reset {
	my $self = shift;
	$_->reset() for @{$self->{jobs}};
}

sub file {
	my $self = shift;
	return $self->{file};
}

1;
