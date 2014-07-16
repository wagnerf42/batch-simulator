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

my ($trace_file, $trace_size, $executions, $max_cpus, $threads) = @ARGV;

die 'missing arguments: tracefile jobs_number executions_number threads_number' unless defined $threads;

my $trace = new Trace($trace_file);
$trace->read();
$trace->remove_large_jobs($max_cpus);

my @trace_blocks;

# Asemble the trace blocks that will be used
print STDERR "Generating $executions trace(s) with size $trace_size\n";
for (1..$executions) {
	my $trace_random = new Trace();
	$trace_random->read_block_from_trace($trace, $trace_size);
	push @trace_blocks, $trace_random;
}

# Divide the block in chunks
print STDERR "Splitting\n";
my @trace_chunks = group_traces_by_chunks(\@trace_blocks, $executions/$threads);

# Create threads
# TODO Save these traces in files to control later
print STDERR "Creating threads\n";
my @threads;

for my $i (0..($threads - 1)) {
	my $thread = threads->create(\&run_all_thread, $i, $trace_chunks[$i]);
	push @threads, $thread;
}

# Wait for all threads to finish
print STDERR "Waiting for all threads to finish\n";
my @results;
for my $i (0..($threads - 1)) {
	my $results_thread = $threads[$i]->join();
	print STDERR "Thread $i finished\n";

	write_results_to_file($results_thread, "backfilling_FCFS-$i.csv");

	push @results, @{$results_thread};
}

# Print all results in a file
write_results_to_file(\@results, 'backfilling_FCFS.csv');
exit;

sub write_results_to_file {
	my $results = shift;
	my $filename = shift;


	open(my $filehandle, ">> $filename") or die "unable to open $filename";

	for my $results_item (@{$results}) {
		print $filehandle "$results_item->{fcfs} $results_item->{backfilling}\n";
	}

	close $filehandle;
}

sub run_all_thread {
	my $id = shift;
	my $traces = shift;
	my @results_all;
	my $trace_number = 0;

	for my $trace (@{$traces}) {
		$trace->write("backfilling_FCFS-$id-$trace_number.swf");
		$trace_number++;

		my $schedule_fcfs = new FCFS($trace, $trace->needed_cpus);
		$schedule_fcfs->run();

		my $schedule_backfilling = new Backfilling($trace, $trace->needed_cpus);
		$schedule_backfilling->run();

		my $results = {
			fcfs => $schedule_fcfs->cmax,
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
	my $thread_backfilling = threads->create(\&run_backfilling_queue, $queue);

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

