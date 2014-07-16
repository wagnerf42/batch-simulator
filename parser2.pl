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

my ($trace_file, $trace_size, $executions, $max_cpus, $threads, $execution_id) = @ARGV;

die 'missing arguments: tracefile jobs_number executions_number threads_number' unless defined $execution_id;

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

	#write_results_to_file($results_thread, "backfilling_FCFS-$i.csv");

	push @results, @{$results_thread};
}

# Print all results in a file
mkdir("backfilling_FCFS-$trace_size-$executions-$max_cpus");
write_results_to_file(\@results, "backfilling_FCFS-$trace_size-$executions-$max_cpus/backfilling_FCFS-$trace_size-$executions-$max_cpus-$execution_id.csv");
`Rscript backfilling_FCFS.R backfilling_FCFS-$trace_size-$executions-$max_cpus/backfilling_FCFS-$trace_size-$executions-$max_cpus-$execution_id.csv backfilling_FCFS-$trace_size-$executions-$max_cpus/backfilling_FCFS-$trace_size-$executions-$max_cpus-$execution_id.pdf`;
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
	my $traces = shift;
	my @results_all;

	for my $trace (@{$traces}) {
		my $schedule_fcfs = new FCFS($trace, $max_cpus);
		$schedule_fcfs->run();

		my $schedule_backfilling = new Backfilling($trace, $max_cpus);
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

