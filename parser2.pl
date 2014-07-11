#!/usr/bin/env perl
use strict;
use warnings;

use threads;
use Thread::Queue;

use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;

my $random_trace_size = 120;
my $executions = 20;
my $cores = 2;

my $trace = new Trace($ARGV[0]);
$trace->read();

my $trace_random = new Trace();
$trace_random->read_from_trace($trace, 20);
run_fcfs($trace_random);
run_fcfsc($trace_random);
exit;

sub run_fcfsc {
	my $trace = shift;

	my $schedule = new FCFSC($trace, $trace->needed_cpus);
	$schedule->run();
	$schedule->print_svg('fcfsc.svg', 'fcfsc.pdf');
}

sub run_fcfs {
	my $trace = shift;

	my $schedule = new FCFS($trace, $trace->needed_cpus);
	$schedule->run();
	$schedule->print_svg('fcfs.svg', 'fcfs.pdf');
}

sub run_threads {
	my $trace = shift;

	my $queue = Thread::Queue->new();

	# This is the element that will go in the queue
	my $trace_random = Trace->new();
	$trace_random->read_from_trace($trace, $random_trace_size);

	# Creating the thread
	my $thread_backfilling = threads->create(\&run_backfilling, $queue);

	# Using the queue as documented on http://perldoc.perl.org/Thread/Queue.html
	$queue->enqueue($trace_random);
	$queue->end();
	$thread_backfilling->join();
}

# Running the thread sub also as documented on that page
sub run_backfilling {
	my $queue = shift;

	while (defined(my $trace = $queue->dequeue())) {
		my $schedule = Backfilling->new($trace, $trace->needed_cpus);
		$schedule->run();
	}
}

