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

my $queue = Thread::Queue->new();

my $trace = Trace->new($ARGV[0]);
$trace->read();

# This is the element that will go in the queue
my $trace_random = Trace->new();
$trace_random->read_from_trace($trace, $random_trace_size);

# Creating the thread
my $thread_backfilling = threads->create(\&run_backfilling);

# Using the queue as documented on http://perldoc.perl.org/Thread/Queue.html
$queue->enqueue($trace_random);
$queue->end();
$thread_backfilling->join();

# Running the thread sub also as documented on that page
sub run_backfilling {
	while (defined(my $trace = $queue->dequeue())) {
		my $schedule = Backfilling->new($trace, $trace->needed_cpus);
		$schedule->run();

		print "Nhack\n";
	}

	print "I'm out\n";
}

exit;

