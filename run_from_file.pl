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
use Random;
use ExecutionProfile ':stooges';

my ($trace_file_name, $cpus_number, $cluster_size) = @ARGV;
die 'missing arguments: trace_file_name cpus_number cluster_size' unless defined $cluster_size;

# Create a directory to store the output
my $basic_file_name = "run_from_file-$cpus_number-$cluster_size";
mkdir "run_from_file/$basic_file_name" unless -f "run_from_file/$basic_file_name";

# Read the trace and write it to a file
my $trace = Trace->new_from_swf($trace_file_name);
$trace->remove_large_jobs($cpus_number);
$trace->reset_submit_times();
$trace->reset_jobs_numbers();

my $schedule_cluster = Backfilling->new($trace, $cpus_number, $cluster_size, EP_CLUSTER);
$schedule_cluster->run();
$schedule_cluster->save_svg("run_from_file/$basic_file_name/$basic_file_name-fcfs0.svg");

