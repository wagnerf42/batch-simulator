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

my ($trace_file_name, $cpus_number, $cluster_size) = @ARGV;
die 'missing arguments: trace_file_name cpus_number cluster_size' unless defined $cluster_size;

# Create a directory to store the output
my $basic_file_name = "run_from_file-$cpus_number-$cluster_size";
mkdir "run_from_file/$basic_file_name" unless -f "run_from_file/$basic_file_name";

# Read the trace and write it to a file
my $trace = Trace->new_from_swf($trace_file_name);

my $schedule1 = FCFS->new($trace, $cpus_number, $cluster_size, 2);
$schedule1->run();
$schedule1->save_svg("run_from_file/$basic_file_name/$basic_file_name-fcfs0.svg");

# FCFS best effort
#my $schedule2 = FCFS->new($trace, $cpus_number, $cluster_size, 1);
#$schedule2->run();
#$schedule2->save_svg("run_from_file/$basic_file_name/$basic_file_name-fcfs_best_effort.svg");

# Backfilling best effort
#my $schedule3 = Backfilling->new($trace, $cpus_number, $cluster_size, 0);
#$schedule3->run();
#$schedule3->save_svg("run_from_file/$basic_file_name/$basic_file_name-backfilling_best_effort.svg");

# Backfilling cluster contiguous
#my $schedule4 = Backfilling->new($trace, $cpus_number, $cluster_size, 1);
#$schedule4->run();
#$schedule4->save_svg("run_from_file/$basic_file_name/$basic_file_name-backfilling_cluster_contiguous.svg");

#my $schedule5 = Backfilling->new($trace, $cpus_number, $cluster_size, 2);
#$schedule5->run();
#$schedule5->save_svg("run_trace_from_database/$basic_file_name/$basic_file_name-backfilling2.svg");

