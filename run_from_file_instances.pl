#!/usr/bin/env perl
use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;
use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;
use Database;
use Random;
use ExecutionProfile ':stooges';

local $| = 1;

my ($trace_file_name, $instances_number, $jobs_number, $cpus_number, $cluster_size, $threads_number) = @ARGV;
die unless defined $threads_number;

my @variants = (
	EP_FIRST,
	EP_BEST_EFFORT,
	EP_CONTIGUOUS,
	EP_BEST_EFFORT_LOCALITY,
	EP_CLUSTER
);

my $results = [];
share($results);

# Create new execution in the database
my %execution = (
	trace_file => $trace_file_name,
	jobs_number => $jobs_number,
	executions_number => $instances_number,
	cpus_number => $cpus_number,
	threads_number => $threads_number,
	git_revision => `git rev-parse HEAD`,
	comments => "run_from_file_instances script, all variants",
	cluster_size => $cluster_size
);

my $database = Database->new();
#$database->prepare_tables();
#die 'created tables';
my $execution_id = $database->add_execution(\%execution);
print STDERR "Started execution $execution_id\n";

# Create a directory to store the output
my $basic_file_name = "run_from_file_instances-$instances_number-$jobs_number-$cpus_number-$cluster_size-$execution_id";
my $basic_dir = "experiment/run_from_file_instances/$basic_file_name";
mkdir "$basic_dir";

# Read the trace and write it to a file
my $trace = Trace->new_from_swf($trace_file_name);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();

print STDERR "Generating $instances_number random traces\n";
my @traces_random = map {Trace->new_from_trace($trace, $jobs_number)} (0..($instances_number - 1));

my $q = Thread::Queue->new();

print STDERR "Populating queue\n";
for my $instance_number (0..($instances_number - 1)) {
	for my $variant_number (0..$#variants) {
		my $instance = {
			number => $instance_number,
			variant => $variant_number
		};
		$q->enqueue($instance);
	}
}
$q->end();

print STDERR "Creating threads\n";
my $start_time = time();
my @threads;
for my $i (0..($threads_number - 1)) {
	my $thread = threads->create(\&run_all_thread, $i);
	push @threads, $thread;
}

# Wait for all threads to finish
$_->join() for (@threads);

# Update run time in the database
$database->update_execution_run_time($execution_id, time() - $start_time);

# save results on a file
print STDERR "Writing results to folder $basic_dir\n";
write_results_to_file($results);

sub run_all_thread {
	my ($id) = @_;

	while (defined(my $instance = $q->dequeue())) {
		my $results_instance = [];
		share($results_instance);

		print STDERR "Running $instance->{number}:$instance->{variant}:" . ($q->pending() ? $q->pending() : 0) . "\n";

		my $trace = Trace->copy_from_trace($traces_random[$instance->{number}]);
		my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variants[$instance->{variant}]);
		$schedule->run();

		#TODO use map here
		for my $job_number (0..($jobs_number - 1)) {
			push @{$results_instance}, $schedule->{jobs}->[$job_number]->{schedule_cmax};
		}

		$results->[$instance->{variant} * $instances_number + $instance->{number}] = $results_instance;
	}
}

sub write_results_to_file {
	my ($results, $variant_number) = @_;

	for my $variant (0..$#variants) {
		open(my $filehandle, "> $basic_dir/$basic_file_name-$variant.csv") or die;

		for my $instance_number (0..($instances_number - 1)) {
			print $filehandle join (' ', @{$results->[$variant * $instances_number + $instance_number]}) . "\n";
		}

		close $filehandle;
	}
}
