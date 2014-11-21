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
use ExecutionProfile ':stooges';
use Random;
use Database;

local $| = 1;

my ($trace_file_name, $jobs_number, $executions_number, $cpus_number, $cluster_size, $threads_number) = @ARGV;
die 'missing arguments: trace_file jobs_number executions_number cpus_number cluster_size threads_number' unless defined $threads_number;

# This line keeps the code from bein executed if there are uncommited changes in the git tree if the branch being used is the master branch
#my $git_branch = `git symbolic-ref --short HEAD`;
#chomp($git_branch);
#die 'git tree not clean' if ($git_branch eq 'master') and (system('./check_git.sh'));

# Create new execution in the database
my %execution = (
	trace_file => $trace_file_name,
	jobs_number => $jobs_number,
	executions_number => $executions_number,
	cpus_number => $cpus_number,
	threads_number => $threads_number,
	git_revision => `git rev-parse HEAD`,
	comments => "parser script, backfilling best effort vs local contiguous, blocks of jobs, without submit times",
	cluster_size => $cluster_size
);

my $database = Database->new();
#$database->prepare_tables();
#die 'created tables';
my $execution_id = $database->add_execution(\%execution);

# Create a directory to store the output
my $basic_file_name = "parser2-$jobs_number-$executions_number-$cpus_number-$execution_id";
mkdir "experiment/parser2/$basic_file_name";

# Basic data for all threads
my @variants = (
	EP_FIRST,
	EP_BEST_EFFORT,
	EP_CONTIGUOUS,
	EP_BEST_EFFORT_LOCALITY,
	EP_CLUSTER,
);

my @variants_names = (
	"backfilling_not_contiguous",
	"backfilling_best_effort",
	"backfilling_contiguous",
	"backfilling_best_effort_locality",
	"backfilling_cluster",
);

my $results = [];
share($results);

# Read the original trace
my $trace = Trace->new_from_swf($trace_file_name);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();

# Create thread queue
my $q = Thread::Queue->new();
for my $instance_number (0..($executions_number - 1)) {
	$q->enqueue($instance_number);
}
$q->end();

# Create threads
my $start_time = time();
my @threads;
for my $i (0..($threads_number - 1)) {
	my $thread = threads->create(\&run_all_thread, $i, $execution_id);
	push @threads, $thread;
}

# Wait for all threads to finish
$_->join() for (@threads);

# Update run time in the database
$database->update_execution_run_time($execution_id, time() - $start_time);

# Print all results in a file
print STDERR "Writing results to experiment/parser2/$basic_file_name/$basic_file_name.csv\n";
write_results_to_file($results, "experiment/parser2/$basic_file_name/$basic_file_name.csv");

#TODO update this subroutine
sub write_results_to_file {
	my ($results, $filename) = @_;

	open(my $filehandle, "> $filename") or die "unable to open $filename";

	print $filehandle join(' ',
		'FIRST_CMAX', 'FIRST_CONTJ', 'FIRST_LOCJ', 'FIRST_LOCF', 'FIRST_LOCF2', 'FIRST_RT',
		'BECONT_CMAX', 'BECONT_CONTJ', 'BECONT_LOCJ', 'BECONT_LOCF', 'BECONT_LOCF2', 'BECONT_RT',
		'CONT_CMAX', 'CONT_CONTJ', 'CONT_LOCJ', 'CONT_LOCF', 'CONT_LOCF2', 'CONT_RT',
		'BELOC_CMAX', 'BELOC_CONTJ', 'BELOC_LOCJ', 'BELOC_LOCF', 'BELOC_LOCF2', 'BELOC_RT',
		'LOC_CMAX', 'LOC_CONTJ', 'LOC_LOCJ', 'LOC_LOCF', 'LOC_LOCF2', 'LOC_RT',
		'TRACE_ID'
	) . "\n";

	for my $results_item (@{$results}) {
		print $filehandle join(' ', @{$results_item}) . "\n";
	}

	close $filehandle;
}

sub run_all_thread {
	my ($id, $execution_id) = @_;
	my @results;
	my $database = Database->new();

	while (defined(my $instance_number = $q->dequeue())) {
		print STDERR "Running $instance_number:" . ($q->pending() ? $q->pending() : 0) . "\n";

		# Generate the trace and add it to the database
		#my $trace_random = Trace->new_block_from_trace($trace, $jobs_number);
		#$trace_random->fix_submit_times();
		
		my $trace_random = Trace->new_from_trace($trace, $jobs_number);
		#$trace_random->reset_jobs_numbers();

		my $trace_id = $database->add_trace($trace_random, $execution_id);

		my @random_traces = map { Trace->copy_from_trace($trace_random) } (0..$#variants);
		my @schedules = map { Backfilling->new($random_traces[$_], $cpus_number, $cluster_size, $variants[$_]) } (0..$#variants);

		$_->run() for @schedules;

		my $results_instance = [];
	        share($results_instance);

		push @{$results_instance},
			(map {
				$_->cmax(),
				$_->contiguous_jobs_number(),
				$_->local_jobs_number(),
				$_->locality_factor(),
				$_->locality_factor_2(),
				$_->run_time()
			} @schedules),
			$trace_id
		;

		$results->[$instance_number] = $results_instance;
	}
}

