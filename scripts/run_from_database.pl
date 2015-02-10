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
use ExecutionProfile ':stooges';

my ($trace_number, $cpus_number, $cluster_size) = @ARGV;
die 'missing arguments: trace_number cpus_number cluster_size' unless defined $cluster_size;

# Create a directory to store the output
my $basic_file_name = "run_trace_from_database-$trace_number-$cpus_number-$cluster_size";
mkdir "run_trace_from_database/$basic_file_name" unless -f "run_trace_from_database/$basic_file_name";

# Read the trace and write it to a file
my $database = Database->new();
my $trace = Trace->new_from_database($trace_number);
$trace->write_to_file("run_trace_from_database/$basic_file_name/$basic_file_name.swf");

# Backfilling best effort
my $schedule_best_effort = Backfilling->new($trace, $cpus_number, $cluster_size, EP_BEST_EFFORT);
$schedule_best_effort->run();
$schedule_best_effort->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-backfilling_best_effort.svg");

# Backfilling best effort locality
my $schedule_best_effort_locality = Backfilling->new($trace, $cpus_number, $cluster_size, EP_BEST_EFFORT_LOCALITY);
$schedule_best_effort_locality->run();
$schedule_best_effort_locality->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-backfilling_best_effort_locality.svg");

# Backfilling cluster contiguous
my $schedule_cluster_contiguous = Backfilling->new($trace, $cpus_number, $cluster_size, EP_CLUSTER_CONTIGUOUS);
$schedule_cluster_contiguous->run();
$schedule_cluster_contiguous->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-backfilling_cluster_contiguous.svg");

my $schedule5 = Backfilling->new($trace, $cpus_number, $cluster_size, 2);
$schedule5->run();
$schedule5->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-backfilling2.svg");

