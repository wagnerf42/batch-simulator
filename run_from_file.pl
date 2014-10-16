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

sub write_results_to_file {
	my ($results, $filename) = @_;

	open(my $filehandle, "> $filename") or die "unable to open $filename";

	for my $results_item (@{$results}) {
		print $filehandle join(' ', @{$results_item}) . "\n";
	}

	close $filehandle;
}

my ($trace_file_name, $cpus_number, $cluster_size) = @ARGV;
die unless defined $cluster_size;

# Create a directory to store the output
my $basic_file_name = "run_from_file-$cpus_number-$cluster_size";
mkdir "run_from_file/$basic_file_name" unless -f "run_from_file/$basic_file_name";

# Read the trace and write it to a file
my $trace = Trace->new_from_swf($trace_file_name);
$trace->reset_submit_times();
$trace->remove_large_jobs($cpus_number);

my $trace_first = Trace->copy_from_trace($trace);
my $schedule_first = Backfilling->new($trace_first, $cpus_number, $cluster_size, EP_FIRST);
$schedule_first->run();

my $trace_best_effort_contiguous = Trace->copy_from_trace($trace);
my $schedule_best_effort_contiguous = Backfilling->new($trace_best_effort_contiguous, $cpus_number, $cluster_size, EP_BEST_EFFORT);
$schedule_best_effort_contiguous->run();

my $trace_contiguous = Trace->copy_from_trace($trace);
my $schedule_contiguous = Backfilling->new($trace_contiguous, $cpus_number, $cluster_size, EP_CONTIGUOUS);
$schedule_contiguous->run();

my $trace_best_effort_local = Trace->copy_from_trace($trace);
my $schedule_best_effort_local = Backfilling->new($trace_best_effort_local, $cpus_number, $cluster_size, EP_BEST_EFFORT_LOCALITY);
$schedule_best_effort_local->run();

my $trace_local = Trace->copy_from_trace($trace);
my $schedule_local = Backfilling->new($trace_local, $cpus_number, $cluster_size, EP_CONTIGUOUS);
$schedule_local->run();

for my $job_number (0..$#{$schedule_first->{jobs}}) {
	print join(' ', (
		$job_number,
		$schedule_first->{jobs}->[$job_number]->schedule_time(),
		$schedule_best_effort_contiguous->{jobs}->[$job_number]->schedule_time(),
		$schedule_contiguous->{jobs}->[$job_number]->schedule_time(),
		$schedule_best_effort_local->{jobs}->[$job_number]->schedule_time(),
		$schedule_local->{jobs}->[$job_number]->schedule_time()
	)) . "\n";
}


