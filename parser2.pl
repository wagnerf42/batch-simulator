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
mkdir "parser2/$basic_file_name";

# Create threads
my $start_time = time();
my @threads;
for my $i (0..($threads_number - 1)) {
	my $thread = threads->create(\&run_all_thread, $i, $execution_id);
	push @threads, $thread;
}

# Wait for all threads to finish
my @results;
push @results, @{$_->join()} for (@threads);

# Update run time in the database
$database->update_execution_run_time($execution_id, time() - $start_time);

# Print all results in a file
print STDERR "Writing results to parser2/$basic_file_name/$basic_file_name.csv\n";
write_results_to_file(\@results, "parser2/$basic_file_name/$basic_file_name.csv");

sub write_results_to_file {
	my ($results, $filename) = @_;

	open(my $filehandle, "> $filename") or die "unable to open $filename";

	for my $results_item (@{$results}) {
		print $filehandle join(' ', @{$results_item}) . "\n";
	}

	close $filehandle;
}

sub run_all_thread {
	my ($id, $execution_id) = @_;
	my @results;
	my $database = Database->new();

	# Read the original trace
	my $trace = Trace->new_from_swf($trace_file_name);
	$trace->remove_large_jobs($cpus_number);
	$trace->reset_submit_times();

	for my $i (1..($executions_number/$threads_number)) {
		if (!$id) {
			print "Running trace $i/" . $executions_number/$threads_number . "\r";
		}

		# Generate the trace and add it to the database
		my $trace_random = Trace->new_block_from_trace($trace, $jobs_number);
		#$trace_random->fix_submit_times();
		#$trace_random->reset_jobs_numbers();
		my $trace_id = $database->add_trace($trace_random, $execution_id);

		#my $schedule_first = Backfilling->new($trace_random, $cpus_number, $cluster_size, EP_FIRST);
		#$schedule_first->run();
		#$database->add_run($trace_id, 'backfilling_not_contiguous', $schedule_first->cmax, $schedule_first->run_time);

		my $schedule_best_effort = Backfilling->new($trace_random, $cpus_number, $cluster_size, EP_BEST_EFFORT);
		$schedule_best_effort->run();
		$database->add_run($trace_id, 'backfilling_best_effort', $schedule_best_effort->cmax, $schedule_best_effort->run_time);

		#my $schedule_contiguous = Backfilling->new($trace_random, $cpus_number, $cluster_size, EP_CONTIGUOUS);
		#$schedule_contiguous->run();
		#$database->add_run($trace_id, 'backfilling_contiguous', $schedule_contiguous->cmax, $schedule_contiguous->run_time);
		
		#my $schedule_cluster_contiguous = Backfilling->new($trace_random, $cpus_number, $cluster_size, EP_CLUSTER_CONTIGUOUS);
		#$schedule_cluster_contiguous->run();
		#$database->add_run($trace_id, 'backfilling_cluster_contiguous', $schedule_cluster_contiguous->cmax, $schedule_cluster_contiguous->run_time);

		my $schedule_cluster = Backfilling->new($trace_random, $cpus_number, $cluster_size, EP_CLUSTER);
		$schedule_cluster->run();
		$database->add_run($trace_id, 'backfilling_cluster', $schedule_cluster->cmax, $schedule_cluster->run_time);

		push @results, [
			#$schedule_cluster->cmax()/$schedule_first->cmax(),
			$schedule_cluster->cmax()/$schedule_best_effort->cmax(),
			#$schedule_cluster_contiguous->cmax()/$schedule_first->cmax(),
			#$schedule_contiguous->cmax()/$schedule_first->cmax(),
			#$schedule_best_effort->cmax()/$schedule_first->cmax(),
			#$schedule_contiguous->mean_stretch()/$schedule_best_effort->mean_stretch(),
			#$schedule_best_effort->contiguous_jobs_number(),
			$trace_id
		];
	}

	return [@results];
}

