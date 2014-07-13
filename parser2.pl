#!/usr/bin/env perl
use strict;
use warnings;

use threads;
use Thread::Queue;

use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;

my $trace_size = 50;
my $executions = 10000;
my $cores = 4;

my $trace = new Trace($ARGV[0]);
$trace->read();

my @trace_blocks;

# Asemble the trace blocks that will be used
for my $i (0..($executions - 1)) {
	my $trace_random = new Trace();
	$trace_random->read_block_from_trace($trace, $trace_size);
	push @trace_blocks, $trace_random;
}

# Divide the block in chunks
my @trace_chunks = group_traces_by_chunks([@trace_blocks], $executions/$cores);

# Create threads
my @threads;
for my $i (0..($cores - 1)) {
	my $thread = threads->create(\&run_all_thread, $trace_chunks[$i]);
	push @threads, $thread
}

# Wait for all threads to finish
my @results;
for my $i (0..($cores - 1)) {
	my $results_thread = $threads[$i]->join();
	push @results, @{$results_thread};
}

# Print all results in a file
write_results_to_file([@results], 'backfilling_FCFS.csv');
die;

sub write_results_to_file {
	my $results = shift;
	my $filename = shift;


	open(my $filehandle, ">> $filename") or die "unable to open $filename";

	for my $results_item (@{$results}) {
		print $filehandle "$results_item->{fcfs} $results_item->{fcfsc} $results_item->{backfilling}\n";
	}

	close $filehandle;
}

sub run_all_thread {
	my $traces = shift;
	my @results_all;

	for my $trace (@{$traces}) {
		my $schedule_fcfs = new FCFS($trace, $trace->needed_cpus);
		$schedule_fcfs->run();

		my $schedule_fcfsc = new FCFSC($trace, $trace->needed_cpus);
		$schedule_fcfsc->run();

		my $schedule_backfilling = new Backfilling($trace, $trace->needed_cpus);
		$schedule_backfilling->run();

		my $results = {
			fcfs => $schedule_fcfs->cmax,
			fcfsc => $schedule_fcfsc->cmax,
			backfilling => $schedule_backfilling->cmax
		};

		push @results_all, $results;
	}

	return [@results_all];
}

sub group_traces_by_chunks {
	my $traces = shift;
	my $chunk_size = shift;
	my @chunks;

	push @chunks, [splice @{$traces}, 0, $chunk_size] while @{$traces};

	return @chunks;
}

sub run_fcfsc {
	my $trace = shift;

	my $schedule = new FCFSC($trace, $trace->needed_cpus);
	$schedule->run();
	$schedule->print_svg('fcfsc.svg', 'fcfsc.pdf');
}

sub run_fcfs {
	my $trace = shift;

	my $schedule = new FCFS($trace, $trace->needed_cpus);
	$schedule->run();
	$schedule->print_svg('fcfs.svg', 'fcfs.pdf');
}

sub run_threads_queue {
	my $trace = shift;

	my $queue = Thread::Queue->new();

	# This is the element that will go in the queue
	my $trace_random = Trace->new();
	$trace_random->read_from_trace($trace, $trace_size);

	# Creating the thread
	my $thread_backfilling = threads->create(\&run_backfilling, $queue);

	# Using the queue as documented on http://perldoc.perl.org/Thread/Queue.html
	$queue->enqueue($trace_random);
	$queue->end();
	$thread_backfilling->join();
}

# Running the thread sub also as documented on that page
sub run_backfilling_queue {
	my $queue = shift;

	while (defined(my $trace = $queue->dequeue())) {
		my $schedule = Backfilling->new($trace, $trace->needed_cpus);
		$schedule->run();
	}
}

