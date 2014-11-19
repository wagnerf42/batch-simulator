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

print "Generating $instances_number random traces\n";
my @traces_random = map {Trace->new_from_trace($trace, $jobs_number)} (0..($instances_number - 1));

my @variants = (
	EP_FIRST,
	EP_BEST_EFFORT,
	EP_CONTIGUOUS,
	EP_BEST_EFFORT_LOCALITY,
	EP_CLUSTER
);

my @threads;
for my $i (0..$#variants) {
	my $thread = threads->create(\&run_all_thread, $i);
	push @threads, $thread;
}

# Wait for all threads to finish
$_->join() for (@threads);


sub run_all_thread {
	my ($id) = @_;
	my @results;

	for my $instance (0..($instances_number - 1)) {
		print "Running instance $id:$instance/" . ($instances_number - 1) . "\n";
		my $trace = Trace->copy_from_trace($traces_random[$instance]);
		my $schedule = Backfilling->new($trace, $cpus_number, $cluster_size, $variants[$id]);
		$schedule->run();

		my @results_instance;

		for my $variant_number (0..$#variants) {
			for my $job_number (0..($jobs_number - 1)) {
				push @results_instance, $schedule->{jobs}->[$job_number]->{schedule_cmax};
			}
		}

		push @results, [@results_instance];
	}

	# save results on a file
	print "Writing results $id\n";
	write_results_to_file(\@results, $id);
}

sub write_results_to_file {
	my ($results, $variant_number) = @_;

	open(my $filehandle, "> run_from_file_instances-$variant_number.csv") or die;

	for my $instance_number (0..($instances_number - 1)) {
		print $filehandle join (' ', @{$results->[$instance_number]}) . "\n";
	}

	close $filehandle;

}
