#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;

my ($trace_file, $trace_size, $executions, $max_cpus) = @ARGV;
die 'missing arguments: tracefile jobs_number executions_number cpus_number ' unless defined $max_cpus;

my $trace = Trace->new_from_swf($trace_file);
$trace->remove_large_jobs($max_cpus);

for (1..$executions) {
	my $trace_random = Trace->new_block_from_trace($trace, $trace_size);

	my $schedule_fcfs = FCFS->new($trace_random, $max_cpus);
	$schedule_fcfs->run();
	print STDERR "fcfs: ".$schedule_fcfs->cmax()."\n";
	$schedule_fcfs->tycat();

	my $schedule_backfilling = Backfilling->new($trace_random, $max_cpus);
	$schedule_backfilling->run();
	print STDERR "backfilling: ".$schedule_backfilling->cmax()."\n";
	$schedule_backfilling->tycat();
}


