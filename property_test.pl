#!/usr/bin/env perl
use strict;
use warnings;

use threads;
use threads::shared;
use Thread::Queue;
use Data::Dumper qw(Dumper);
use List::Util qw(sum reduce);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;
use Database;
use Job;

my ($trace_number, $cpus_number) = @ARGV;
die 'missing arguments: trace_number cpus_number' unless defined $cpus_number;

my $database = Database->new();
my $trace = Trace->new_from_database($trace_number);

my $schedule_fcfs = FCFS->new($trace, $cpus_number);
$schedule_fcfs->run();

# Count and print the number of jobs that use many processors
my @big_jobs = grep {$_->requested_cpus() > $cpus_number} @{$trace->jobs()};
print scalar @big_jobs . " jobs with more than $cpus_number CPUs\n";

# Find out the job average run time
my $average_run_time = 0;
$average_run_time += $_->run_time() for (@{$trace->jobs()});
$average_run_time /= @{$trace->jobs};

# Use the average run time to divide the trace in equal parts
my $parts_number = $schedule_fcfs/$average_run_time;
print "$parts_number equal parts\n";

