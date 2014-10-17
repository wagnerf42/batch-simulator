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

my ($trace_file_name, $instances_number, $jobs_number, $cpus_number, $cluster_size) = @ARGV;
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

for my $instance (1..$instances_number) {
	my $trace_random = Trace->new_from_trace($trace, $jobs_number);
	my @traces = map {Trace->copy_from_trace($trace_random)} (0..$#variants);
	my @schedules = map {Backfilling->new($traces[$_], $cpus_number, $cluster_size, $variants[$_])} (0..$#variants);
	$_->run() for @schedules;

	my @results;

	for my $job_number (0..($jobs_number - 1)) {
		push @results, [
			$job_number,
			$schedules[0]->{jobs}->[$job_number]->submit_time(),
			$schedules[0]->{jobs}->[$job_number]->run_time(),
			(map {
				$_->{jobs}->[$job_number]->wait_time(),
				$_->{jobs}->[$job_number]->schedule_time(),
			} @schedules),
		];
	}


	# save results on a file
	write_results_to_file(\@results, "test.csv");
}

#		(map { $_->{jobs}->[$job_number]->schedule_time() } @schedules),
#		(map { $_->{jobs}->[$job_number]->requested_cpus() } @schedules),
#		(map { $_->{jobs}->[$job_number]->run_time() } @schedules),
