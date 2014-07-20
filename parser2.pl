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

my ($trace_file, $trace_size, $executions, $max_cpus, $threads) = @ARGV;
die 'missing arguments: tracefile jobs_number executions_number cpus_number threads_number' unless defined $threads;

# This line keeps the code from bein executed if there are uncommited changes in the git tree if the branch being used is the master branch
my $git_branch = `git symbolic-ref --short HEAD`;
die 'git tree not clean' if ($git_branch eq 'master') and (system('./check_git.sh'));

#my $database = Database->new();
#$database->prepare_tables();
#die 'created database tables';

# Create threads
print STDERR "Creating threads\n";
my @threads;
for my $i (0..($threads - 1)) {
	my $thread = threads->create(\&run_all_thread, $i);
	push @threads, $thread;
}

# Wait for all threads to finish
print STDERR "Waiting for all threads to finish\n";
my @results;
for my $i (0..($threads - 1)) {
	my $results_thread = $threads[$i]->join();
	print STDERR "Thread $i finished\n";

	push @results, @{$results_thread};
}

# Print all results in a file
#print STDERR "Writing results\n";
#write_results_to_file(\@results, "backfilling_FCFS-$trace_size-$executions-$max_cpus.csv");

sub write_results_to_file {
	my $results = shift;
	my $filename = shift;

	open(my $filehandle, "> $filename") or die "unable to open $filename";

	for my $results_item (@{$results}) {
		print $filehandle "$results_item->{contiguous}->{cmax} $results_item->{not_contiguous}->{cmax}\n";
	}

	close $filehandle;
}

sub run_all_thread {
	my $id = shift;
	my @results_all;

	my $database = Database->new();
	my %execution = (
		trace_file => $trace_file,
		jobs_number => $trace_size,
		executions_number => $executions,
		cpus_number => $max_cpus,
		threads_number => $threads,
		git_revision => `git rev-parse HEAD`
	);

	my $execution_id = $database->add_execution(\%execution);

	my $trace = Trace->new_from_swf($trace_file);
	$trace->remove_large_jobs($max_cpus);

	for (1..($executions/$threads)) {
		my $trace_random = Trace->new_block_from_trace($trace, $trace_size);

		my $schedule_fcfs = FCFS->new($trace_random, $max_cpus);
		$schedule_fcfs->run();
		my %results_fcfs = (
			execution => $execution_id,
			algorithm => $database->get_algorithm_by_name('fcfs_not_contiguous'),
			cmax => $schedule_fcfs->cmax(),
			run_time => $schedule_fcfs->run_time()
		);
		my $execution_algorithm_fcfs = $database->add_execution_algorithm(\%results_fcfs);
		$database->add_trace($execution_algorithm_fcfs, $trace_random);

		$trace_random->reset();

		my $schedule_backfilling = Backfilling->new($trace_random, $max_cpus);
		$schedule_backfilling->run();
		my %results_backfilling = (
			execution => $execution_id,
			algorithm => $database->get_algorithm_by_name('backfilling_not_contiguous'),
			cmax => $schedule_backfilling->cmax(),
			run_time => $schedule_backfilling->run_time()
		);
		my $execution_algorithm_backfilling = $database->add_execution_algorithm(\%results_backfilling);
		$database->add_trace($execution_algorithm_backfilling, $trace_random);
	}

	return [@results_all];
}

