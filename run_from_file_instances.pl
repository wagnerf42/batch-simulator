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

local $| = 1;

my ($trace_file_name, $instances_number, $jobs_number, $cpus_number, $cluster_size, $threads_number) = @ARGV;
die unless defined $threads_number;

my @variants = (
	EP_FIRST,
	EP_BEST_EFFORT,
	EP_CONTIGUOUS,
	EP_BEST_EFFORT_LOCALITY,
	EP_CLUSTER
);

my $results = [];
share($results);

# Read the trace and write it to a file
my $trace = Trace->new_from_swf($trace_file_name);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();

print "Generating $instances_number random traces\n";
my @traces_random = map {Trace->new_from_trace($trace, $jobs_number)} (0..($instances_number - 1));

my $q = Thread::Queue->new();

my @threads;
for my $i (0..($threads_number - 1)) {
	my $thread = threads->create(\&run_all_thread, $i);
	push @threads, $thread;
}

for my $instance_number (0..($instances_number - 1)) {
	for my $variant_number (0..$#variants) {
		my $instance = {
			number => $instance_number,
			variant => $variant_number
		};
		$q->enqueue($instance);
	}
}
$q->end();

# Wait for all threads to finish
$_->join() for (@threads);

# save results on a file
print "Writing results\n";
write_results_to_file($results);

sub run_all_thread {
	my ($id) = @_;

	while (defined(my $instance = $q->dequeue())) {
		my $results_instance = [];
		share($results_instance);

		my $trace = Trace->copy_from_trace($traces_random[$instance->{number}]);
		my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variants[$instance->{variant}]);
		$schedule->run();

		#TODO use map here
		for my $job_number (0..($jobs_number - 1)) {
			push @{$results_instance}, $schedule->{jobs}->[$job_number]->{schedule_cmax};
		}

		$results->[$instance->{variant} * $instances_number + $instance->{number}] = $results_instance;
	}
}

sub write_results_to_file {
	my ($results, $variant_number) = @_;

	for my $variant (0..$#variants) {
		open(my $filehandle, "> run_from_file_instances-$variant.csv") or die;

		for my $instance_number (0..($instances_number - 1)) {
			print $filehandle join (' ', @{$results->[$variant * $instances_number + $instance_number]}) . "\n";
		}

		close $filehandle;
	}
}
