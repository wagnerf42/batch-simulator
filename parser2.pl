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

my ($trace_file_name, $jobs_number, $executions_number, $cpus_number, $threads_number) = @ARGV;
die 'missing arguments: trace_file jobs_number executions_number cpus_number threads_number' unless defined $threads_number;

# This line keeps the code from bein executed if there are uncommited changes in the git tree if the branch being used is the master branch
#my $git_branch = `git symbolic-ref --short HEAD`;
#chomp($git_branch);
#die 'git tree not clean' if ($git_branch eq 'master') and (system('./check_git.sh'));

# Create a directory to store the output
my $basic_file_name = "parser2-$jobs_number-$executions_number-$cpus_number";
mkdir $basic_file_name unless -f $basic_file_name;

my $database = Database->new();
#$database->prepare_tables();
#die 'created tables';

# Create new execution in the database
my %execution = (
	trace_file => $trace_file_name,
	jobs_number => $jobs_number,
	executions_number => $executions_number,
	cpus_number => $cpus_number,
	threads_number => $threads_number,
	git_revision => `git rev-parse HEAD`,
	comments => "parser script, all algorithms, remove large jobs, reset submit times"
);
my $execution_id = $database->add_execution(\%execution);

# Create threads
print STDERR "Creating threads\n";
my $start_time = time();
my @threads;
for my $i (0..($threads_number - 1)) {
	my $thread = threads->create(\&run_all_thread, $i, $execution_id);
	push @threads, $thread;
}

# Wait for all threads to finish
print STDERR "Waiting for all threads to finish\n";
my @results;
push @results, @{$_->join()} for (@threads);

# Update run time in the database
$database->update_execution_run_time($execution_id, time() - $start_time);

# Print all results in a file
print STDERR "Writing results to $basic_file_name/$basic_file_name.csv\n";
write_results_to_file(\@results, "$basic_file_name/$basic_file_name.csv");

sub write_results_to_file {
	my $results = shift;
	my $filename = shift;

	open(my $filehandle, "> $filename") or die "unable to open $filename";

	for my $results_item (@{$results}) {
		print $filehandle join(' ', @{$results_item}) . "\n";
	}

	close $filehandle;
}

sub run_all_thread {
	my $id = shift;
	my $execution_id = shift;
	my @results;
	my $database = Database->new();

	# Read the original trace
	my $trace = Trace->new_from_swf($trace_file_name);
	$trace->remove_large_jobs($cpus_number);
	$trace->reset_submit_times();

	for (1..($executions_number/$threads_number)) {
		# Generate the trace and add it to the database
		my $trace_random = Trace->new_block_from_trace($trace, $jobs_number);
		my $trace_id = $database->add_trace($trace_random, $execution_id);

		my $schedule_fcfs = FCFS->new($trace_random, $cpus_number);
		$schedule_fcfs->run();
		$database->add_run($trace_id, 'fcfs_best_effort', $schedule_fcfs->cmax, $schedule_fcfs->run_time);

		my $schedule_fcfsc = FCFSC->new($trace_random, $cpus_number);
		$schedule_fcfsc->run();
		$database->add_run($trace_id, 'fcfs_contiguous', $schedule_fcfsc->cmax, $schedule_fcfsc->run_time);

		my $schedule_backfilling = Backfilling->new($trace_random, $cpus_number);
		$schedule_backfilling->run();
		$database->add_run($trace_id, 'backfilling_best_effort', $schedule_backfilling->cmax, $schedule_backfilling->run_time);

		my $schedule_backfilling_contiguous = Backfilling->new($trace_random, $cpus_number, 1);
		$schedule_backfilling_contiguous->run();
		$database->add_run($trace_id, 'backfilling_contiguous', $schedule_backfilling_contiguous->cmax, $schedule_backfilling_contiguous->run_time);

		push @results, [
			$schedule_fcfs->cmax,
			$schedule_fcfs->run_time,
			$schedule_fcfsc->cmax,
			$schedule_fcfsc->run_time,
			$schedule_backfilling->cmax,
			$schedule_backfilling->run_time,
			$schedule_backfilling_contiguous->cmax,
			$schedule_backfilling->run_time,
			$trace_id
		];
	}

	return [@results];
}

