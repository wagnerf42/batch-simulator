package Trace;
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max reduce sum);
use List::MoreUtils qw(natatime);
use Storable qw(dclone);
use POSIX qw(ceil floor);

use Job;
use Database;

sub new_from_swf {
	my ($class, $file, $jobs_number) = @_;

	my $self = {
		file => $file,
		jobs => [],
		status => []
	};

	open (FILE, $self->{file}) or die "unable to open $self->{file}";

	while (defined(my $line = <FILE>) and (not defined $jobs_number or @{$self->{jobs}} < $jobs_number)) {
		my @fields = split(' ', $line);

		next unless defined $fields[0];

		# Status line
		if ($fields[0] =~/^;/) {
			push @{$self->{status}}, [@fields];
		}

		# Job line
		elsif ($fields[0] ne ' ') {
			my $job = new Job(@fields);
			push @{$self->{jobs}}, $job;
		}
	}

	bless $self, $class;
	return $self;
}

sub keep_first_jobs {
	my ($self, $jobs_number) = @_;
	#@{$self->{jobs} = splice(@{$self->{jobs}}, 0, $jobs_number);
	@{$self->{jobs}} = @{$self->{jobs}}[0..($jobs_number-1)];
}

sub reset_requested_times {
	my ($self) = @_;
	$_->{requested_time} = $_->{run_time} for @{$self->{jobs}};
}

sub fix_submit_times {
	my $self = shift;
	my $start = $self->{jobs}->[0]->submit_time();
	return unless defined $start;
	$_->submit_time($_->submit_time() - $start) for @{$self->{jobs}};
}

sub new_block_from_trace {
	my ($class, $trace, $size) = @_;
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
	my ($class, $trace, $size) = @_;

	die 'empty trace' unless defined $trace->{jobs}->[0];

	my $self = {
		jobs => []
	};

	push @{$self->{jobs}}, dclone($trace->{jobs}->[int rand(@{$trace->{jobs}})]) for (1..$size);

	bless $self, $class;
	return $self;
}

sub copy_from_trace {
	my ($class, $trace) = @_;

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
	my ($class, $trace_id) = @_;

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
	my ($class, $original) = @_;
	my $self = {
		jobs => []
	};
	push @{$self->{jobs}}, Job->copy($_) for @{$original->{jobs}};
	bless $self, $class;
	return $self;
}


sub reset_submit_times {
	my ($self) = @_;
	$_->submit_time(0) for (@{$self->{jobs}});
}

sub reset_jobs_numbers {
	my ($self) = @_;

	for my $i (0..$#{$self->{jobs}}) {
		$self->{jobs}[$i]->job_number($i + 1);
	}
}

sub write_to_file {
	my ($self, $trace_file_name) = @_;

	open(my $filehandle, "> $trace_file_name") or die "unable to open $trace_file_name";

	for my $job (@{$self->{jobs}}) {
		print $filehandle "$job\n";
	}
}

sub needed_cpus {
	my ($self) = @_;
	return max map {$_->requested_cpus()} @{$self->{jobs}};
}

sub jobs {
	my ($self, $jobs) = @_;
	$self->{jobs} = $jobs if defined $jobs;
	return $self->{jobs};
}

sub job {
	my ($self, $job_number) = @_;
	return $self->{jobs}->[$job_number];
}

sub remove_large_jobs {
	my ($self, $limit) = @_;
	die unless defined $limit;
	my @left_jobs = grep {$_->requested_cpus() <= $limit} @{$self->{jobs}};
	$self->{jobs} = [@left_jobs];
}

sub reset {
	my ($self) = @_;
	$_->reset() for @{$self->{jobs}};
}

sub load {
	my ($self, $processors_number) = @_;

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
