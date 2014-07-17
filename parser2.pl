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
die 'missing arguments: tracefile jobs_number executions_number cpus_number threads_number' unless defined $threads;

my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($max_cpus);

#TODO Generate the traces inside the threads
# Asemble the trace blocks that will be used
print STDERR "Generating $executions trace(s) with size $trace_size\n";
my @trace_blocks;
for (1..$executions) {
	my $trace_random = Trace->new_from_trace($trace, $trace_size);
	push @trace_blocks, $trace_random;
}

# Divide the block in chunks
print STDERR "Splitting\n";
my @trace_chunks = group_traces_by_chunks(\@trace_blocks, $executions/$threads);

# Create threads
print STDERR "Creating threads\n";
my @threads;

for my $i (0..($threads - 1)) {
	my $thread = threads->create(\&run_all_thread, $i, $max_cpus, $trace_chunks[$i]);
	push @threads, $thread;
}

# Wait for all threads to finish
print STDERR "Waiting for all threads to finish\n";
my @results;
for my $i (0..($threads - 1)) {
	my $results_thread = $threads[$i]->join();
	print STDERR "Thread $i finished\n";

	#write_results_to_file($results_thread, "backfilling_FCFS-$i.csv");
	push @results, @{$results_thread};
}

# Print all results in a file
print STDERR "Writing results\n";
write_results_to_file(\@results, "backfilling_FCFS-$trace_size-$executions-$max_cpus.csv");
exit;

sub write_results_to_file {
	my $results = shift;
	my $filename = shift;


	open(my $filehandle, "> $filename") or die "unable to open $filename";

	for my $results_item (@{$results}) {
		print $filehandle "$results_item->{fcfs} $results_item->{backfilling}\n";
	}

	close $filehandle;
}

sub run_all_thread {
	my $id = shift;
	my $max_cpus = shift;
	my $traces = shift;
	my @results_all;

	for my $trace (@{$traces}) {
		my $schedule_fcfs = FCFS->new($trace, $max_cpus);
		$schedule_fcfs->run();

		my $schedule_backfilling = Backfilling->new($trace, $max_cpus);
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

