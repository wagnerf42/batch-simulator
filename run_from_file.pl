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

my ($trace_file_name, $cpus_number, $cluster_size) = @ARGV;
die unless defined $cluster_size;

# Read the trace and write it to a file
my $trace = Trace->new_from_swf($trace_file_name);
#$trace->reset_submit_times();
$trace->remove_large_jobs($cpus_number);

my @variants = (
	EP_FIRST,
	EP_BEST_EFFORT,
	EP_CONTIGUOUS,
	EP_BEST_EFFORT_LOCALITY,
	EP_CLUSTER
);

my @traces = map {Trace->copy_from_trace($trace)} (0..$#variants);
my @schedules = map {Backfilling->new($traces[$_], $cpus_number, $cluster_size, $variants[$_])} (0..$#variants);

$_->run() for @schedules;

my @stretch_values = (0) x scalar @variants;

for my $job_number (0..$#{$schedules[0]->{jobs}}) {
	$stretch_values[$_] += $schedules[$_]->{jobs}->[$job_number]->wait_time() for (0..$#variants);

	print join(' ',
		$job_number,
#		(map { $_->{jobs}->[$job_number]->schedule_time() } @schedules),
#		(map { $_->{jobs}->[$job_number]->requested_cpus() } @schedules),
#		(map { $_->{jobs}->[$job_number]->run_time() } @schedules),
		(@stretch_values),
	) . "\n";
}


