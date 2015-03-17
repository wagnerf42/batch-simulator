package Trace;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max reduce sum);
use List::MoreUtils qw(natatime);
use Storable qw(dclone);
use POSIX qw(ceil floor);

use Job;

sub new_from_swf {
	my $class = shift;
	my $filename = shift;
	my $jobs_number = shift;

	my $self = {
		filename => $filename,
		jobs => [],
		status => []
	};

	open (my $file, '<', $self->{filename}) or die "unable to open $self->{filename}";

	while (defined(my $line = <$file>) and (not defined $jobs_number or @{$self->{jobs}} < $jobs_number)) {
		my @fields = split(' ', $line);

		next unless defined $fields[0];

		# Status line
		if ($fields[0] =~/^;/) {
			push @{$self->{status}}, [@fields];
		}

		# Job line
		elsif ($fields[0] ne ' ') {
			my $job = Job->new(@fields);
			push @{$self->{jobs}}, $job;
		}
	}
	close($file);

	bless $self, $class;
	return $self;
}

sub keep_first_jobs {
	my $self = shift;
	my $jobs_number = shift;

	my $end = $jobs_number - 1;
	my $last_available = $#{$self->{jobs}};
	$end = $last_available if $last_available < $end;
	@{$self->{jobs}} = @{$self->{jobs}}[0..$end];
	return;
}

sub reset_requested_times {
	my $self = shift;
	$_->{requested_time} = $_->{run_time} for @{$self->{jobs}};
	return;
}

sub fix_submit_times {
	my $self = shift;
	my $start = $self->{jobs}->[0]->submit_time();
	return unless defined $start;
	$_->submit_time($_->submit_time() - $start) for @{$self->{jobs}};
	return;
}

sub new_block_from_trace {
	my $class = shift;
	my $trace = shift;
	my $size = shift;

	my $start_point = int(rand(scalar @{$trace->jobs()} - $size + 1));
	my $end_point = $start_point + $size - 1;
	my @selected_jobs = @{$trace->jobs()}[$start_point..$end_point];

	my $self = {
		jobs => [@selected_jobs]
	};

	bless $self, $class;
	return $self;
}

sub new_from_trace {
	my $class = shift;
	my $trace = shift;
	my $size = shift;

	die 'empty trace' unless defined $trace->{jobs}->[0];

	my $self = {
		jobs => []
	};

	push @{$self->{jobs}}, dclone($trace->{jobs}->[int rand(@{$trace->{jobs}})]) for (1..$size);

	bless $self, $class;
	return $self;
}

sub copy_from_trace {
	my $class = shift;
	my $trace = shift;

	my $self = {
		jobs => []
	};

	for my $job (@{$trace->jobs()}) {
		my $new_job = dclone($job);
		push @{$self->{jobs}}, $new_job;
	}

	bless $self, $class;
	return $self;
}


sub new_from_database {
	my $class = shift;
	my $trace_id = shift;

	my $self = {
		jobs => [],
	};

	my $database = Database->new();
	my $trace_ref = $database->get_trace_ref($trace_id);
	my @job_refs = $database->get_job_refs($trace_id);

	for my $job_ref (@job_refs) {
		my $job = Job->new(
			$job_ref->{job_number},
			$job_ref->{submit_time},
			$job_ref->{wait_time},
			$job_ref->{run_time},
			$job_ref->{allocated_cpus},
			$job_ref->{avg_cpu_time},
			$job_ref->{used_mem},
			$job_ref->{requested_cpus},
			$job_ref->{requested_time},
			$job_ref->{requested_mem},
			$job_ref->{status},
			$job_ref->{uid},
			$job_ref->{gid},
			$job_ref->{exec_number},
			$job_ref->{queue_number},
			$job_ref->{partition_number},
			$job_ref->{prec_job_number},
			$job_ref->{think_time_prec_job}
		);

		push @{$self->{jobs}}, $job;
	}

	bless $self, $class;
	return $self;
}

sub copy {
	my $class = shift;
	my $original = shift;

	my $self = {
		jobs => []
	};
	push @{$self->{jobs}}, Job->copy($_) for @{$original->{jobs}};
	bless $self, $class;
	return $self;
}


sub reset_submit_times {
	my $self = shift;
	$_->submit_time(0) for (@{$self->{jobs}});
	return;
}

#renumbers all jobs starting from 1
sub reset_jobs_numbers {
	my $self = shift;
	my $id = 1;
	for my $job (@{$self->{jobs}}) {
		$job->job_number($id);
		$id++;
	}
	return;
}

sub write_to_file {
	my $self = shift;
	my $trace_file_name = shift;

	open(my $filehandle, '>', "$trace_file_name") or die "unable to open $trace_file_name";

	for my $job (@{$self->{jobs}}) {
		print $filehandle "$job\n";
	}
	close($filehandle);
	return;
}

sub needed_cpus {
	my $self = shift;
	return max map {$_->requested_cpus()} @{$self->{jobs}};
}

sub jobs {
	my $self = shift;
	my $jobs = shift;
	$self->{jobs} = $jobs if defined $jobs;
	return $self->{jobs};
}

sub job {
	my $self = shift;
	my $job_number = shift;
	return $self->{jobs}->[$job_number];
}

sub remove_large_jobs {
	my $self = shift;
	my $limit = shift;
	die unless defined $limit;
	my @left_jobs = grep {$_->requested_cpus() <= $limit} @{$self->{jobs}};
	$self->{jobs} = [@left_jobs];
	return;
}

sub unassign_jobs {
	my $self = shift;
	$_->unassign() for @{$self->{jobs}};
	return;
}

sub load {
	my $self = shift;
	my $processors_number = shift;

	my $jobs_number = scalar @{$self->{jobs}};

	my $first_job_index = floor($jobs_number * 0.01);
	my $first_job = $self->{jobs}->[$first_job_index];
	my $t_start = $first_job->submit_time() + $first_job->wait_time();
	my @valid_jobs = @{$self->{jobs}}[$first_job_index..$#{$self->{jobs}}];

	my $last_submit_time = $self->{jobs}->[$#{$self->{jobs}}]->submit_time();
	@valid_jobs = grep {$_->submit_time() + $_->wait_time() + $_->run_time() < $last_submit_time} @valid_jobs;
	my $t_end = max map {$_->submit_time() + $_->wait_time() + $_->run_time()} @valid_jobs;

	my $load = sum map {$_->requested_cpus() * $_->run_time() / ($processors_number * ($t_end - $t_start))} @valid_jobs;
	return $load;
}

1;
