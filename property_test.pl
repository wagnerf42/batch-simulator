#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use Trace;
use FCFS;
use FCFSC;
use Backfilling;

my ($trace_file_name, $jobs_number, $cpus_number, $runs) = @ARGV;
die 'missing arguments: trace_file jobs_number cpus_number number_of_runs' unless defined $runs;

my $trace = Trace->new_from_swf($trace_file_name);
$trace->remove_large_jobs($cpus_number);

for (1..$runs) {
	print STDERR "$_\n";
	my $trace_random = Trace->new_block_from_trace($trace, $jobs_number);

	# Count and print the number of jobs that use many processors
	my $characteristic = $trace_random->characteristic($cpus_number, 0);

	# Find out the ratio between FCFSBE and Backfilling
	my $schedule_fcfs = FCFS->new($trace_random, $trace_random->needed_cpus);
	$schedule_fcfs->run();

	my $schedule_backfilling = Backfilling->new($trace_random, $trace_random->needed_cpus());
	$schedule_backfilling->run();

	print $schedule_backfilling->cmax()/$schedule_fcfs->cmax();
	print "\t$characteristic\n";
}

