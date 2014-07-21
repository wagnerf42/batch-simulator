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
$trace->remove_large_jobs($cpus_number);

my $schedule_fcfs = FCFS->new($trace, $cpus_number);
$schedule_fcfs->run();

# Count and print the number of jobs that use many processors
my @big_jobs = grep {$_->requested_cpus() > $cpus_number/2} @{$trace->jobs()};
print scalar @big_jobs . " jobs with more than " . $cpus_number/2 . " CPUs\n";

# Find out the ratio between FCFSBE and Backfilling
my $trace_random = Trace->new_block_from_trace($trace, $jobs_number);
my $trace_id = $database->add_trace($trace_random, $execution_id);

my $schedule_fcfs = FCFS->new($trace_random, $cpus_number);
my $results_fcfs = $schedule_fcfs->run();

