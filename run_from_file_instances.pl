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

my ($trace_file_name, $instances_number, $jobs_number, $cpus_number, $cluster_size, $threads_number, $execution_id) = @ARGV;
die 'wrong parameters' unless defined $threads_number;

my @variants = (
	EP_FIRST,
#	EP_BEST_EFFORT,
	EP_CONTIGUOUS,
#	EP_BEST_EFFORT_LOCALITY,
#	EP_CLUSTER
);

my @variants_names = (
	"first",
#	"becont",
	"cont",
#	"beloc",
#	"loc"
);

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

#my $database = Database->new();
#$database->prepare_tables();
#die 'created tables';

#my $execution_id = $database->add_execution(\%execution);
print STDERR "Started execution $execution_id\n";

# Create a directory to store the output
my $basic_file_name = "run_from_file_instances-$instances_number-$jobs_number-$cpus_number-$cluster_size-$execution_id";
my $basic_dir = "experiment/run_from_file_instances/$basic_file_name";
mkdir "$basic_dir";

# Main results array
my $results = [];
share($results);

# Read the trace and write it to a file
my $trace = Trace->new_from_swf($trace_file_name);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();

my $q = Thread::Queue->new();

print STDERR "Populating queue\n";
$q->enqueue($_) for (0..($instances_number - 1));
#$q->end();

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
#$database->update_execution_run_time($execution_id, time() - $start_time);

# save results on a file
print STDERR "Writing results to folder $basic_dir\n";
write_results_to_file($results);

sub run_all_thread {
	my ($id) = @_;

	while (defined(my $instance = $q->dequeue_nb())) {
		my $results_instance = [];
		share($results_instance);

		my $trace_random = Trace->new_from_trace($trace, $jobs_number);

		print STDERR "Running $instance\n";

		for my $variant (0..$#variants) {
			my $schedule = Backfilling->new($trace_random, $cpus_number, $cluster_size, $variants[$variant]);
			$schedule->run();

			my $results_instance = [];
			share($results_instance);
			push @{$results_instance}, map { $schedule->{jobs}->[$_]->{schedule_cmax} } (0..($jobs_number - 1));
			$results->[$variant * $instances_number + $instance] = $results_instance;
		}
	}

	print STDERR "Thread $id finished\n";
}

sub write_results_to_file {
	my ($results, $variant_number) = @_;

	for my $variant (0..$#variants) {
		open(my $filehandle, "> $basic_dir/$basic_file_name-$variants_names[$variant].csv") or die;
		print $filehandle join (' ', @{$results->[$variant * $instances_number + $_]}) . "\n" for (0..($instances_number - 1));
		close $filehandle;
	}
}
