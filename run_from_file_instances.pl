#!/usr/bin/env perl
use strict;
use warnings;

use threads;
use threads::shared;
use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;
use Database;
use Random;
use ExecutionProfile ':stooges';

local $| = 1;

my ($trace_file_name, $instances_number, $jobs_number, $cpus_number, $cluster_size) = @ARGV;
die unless defined $cluster_size;

# Read the trace and write it to a file
my $trace = Trace->new_from_swf($trace_file_name);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();

my @variants = (
	EP_FIRST,
	EP_BEST_EFFORT,
	EP_CONTIGUOUS,
	EP_BEST_EFFORT_LOCALITY,
	EP_CLUSTER
);

my @results;

for my $instance (1..$instances_number) {
	print "Running instance $instance/$instances_number\n";
	my $trace_random = Trace->new_from_trace($trace, $jobs_number);
	my @traces = map {Trace->copy_from_trace($trace_random)} (0..$#variants);
	my @schedules = map {Backfilling->new($traces[$_], $cpus_number, $cluster_size, $variants[$_])} (0..$#variants);
	$_->run() for (@schedules);
	my @results_instance;
	$results_instance[$_] = [] for (0..$#variants);

	for my $variant_number (0..$#variants) {
		for my $job_number (0..($jobs_number - 1)) {
			push @{$results_instance[$variant_number]}, $schedules[$variant_number]->{jobs}->[$job_number]->cmax();
		}
	}

	push @results, [@results_instance];
}

# save results on a file
print "Writing results\n";
write_results_to_file(\@results);

sub write_results_to_file {
	my ($results, $filename) = @_;

	for my $variant_number (0..$#variants) {
		open(my $filehandle, "> run_from_file_instances-$variant_number.csv") or die "unable to open $filename";


		for my $instance_number (0..($instances_number - 1)) {
			print $filehandle join (' ', @{$results[$instance_number]->[$variant_number]}) . "\n";
		}

		close $filehandle;
	}

}
