#!/usr/bin/env perl
use strict;
use warnings;

use threads;

use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;

my $random_trace_size = 120;

print "Executing parser version 2\n";

my $trace = Trace->new($ARGV[0]);
$trace->read();

open(my $filehandler, '>>', 'parser2.out');

print "Generating random trace with size $random_trace_size\n";
my $trace_random = Trace->new();
$trace_random->read_from_trace($trace, $random_trace_size);
$trace_random->write("random.swf");

my $thread_backfilling = threads->create(\&run_backfilling, $trace_random);
my $thread_FCFS = threads->create(\&run_FCFS, $trace_random);

my $schedule_backfilling = $thread_backfilling->join();
my $schedule_FCFS = $thread_FCFS->join();
print $filehandler join(' ',  $schedule_backfilling->cmax, $schedule_FCFS->cmax, $schedule_backfilling->backfilled_jobs) . "\n";

close $filehandler;

sub run_backfilling {
	my $trace = shift;

	my $schedule = Backfilling->new($trace, $trace->needed_cpus);

	print "Running backfilling algorithm\n";
	$schedule->run();
	print "Finished running backfilling algorithm\n";

	return $schedule;
}

sub run_FCFS {
	my $trace = shift;

	my $schedule = new FCFS($trace, $trace->needed_cpus);

	print "Running FCFS algorithm\n";
	$schedule->run();
	print "Finished running FCFS algorithm\n";

	return $schedule;
}
exit;

