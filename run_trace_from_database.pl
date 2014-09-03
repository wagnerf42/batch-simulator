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

my ($trace_number, $cpus_number, $cluster_size) = @ARGV;
die 'missing arguments: trace_number cpus_number cluster_size' unless defined $cluster_size;

# Create a directory to store the output
my $basic_file_name = "run_trace_from_database-$trace_number-$cpus_number-$cluster_size";
mkdir "run_trace_from_database/$basic_file_name" unless -f "run_trace_from_database/$basic_file_name";

# Read the trace and write it to a file
my $database = Database->new();
my $trace = Trace->new_from_database($trace_number);
$trace->write_to_file("run_trace_from_database/$basic_file_name/$basic_file_name.swf");

#my $schedule1 = FCFS->new($trace, $cpus_number, $cluster_size, 0);
#$schedule1->run();
#$schedule1->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-fcfs0.svg");

# FCFS best effort
my $schedule2 = FCFS->new($trace, $cpus_number, $cluster_size, 1);
$schedule2->run();
$schedule2->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-fcfs_best_effort.svg");

# Backfilling best effort
my $schedule3 = Backfilling->new($trace, $cpus_number, $cluster_size, 0);
$schedule3->run();
$schedule3->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-backfilling_best_effort.svg");

# Backfilling cluster contiguous
my $schedule4 = Backfilling->new($trace, $cpus_number, $cluster_size, 1);
$schedule4->run();
$schedule4->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-backfilling_cluster_contiguous.svg");

#my $schedule5 = Backfilling->new($trace, $cpus_number, $cluster_size, 2);
#$schedule5->run();
#$schedule5->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-backfilling2.svg");

