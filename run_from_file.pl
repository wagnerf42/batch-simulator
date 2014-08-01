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

my ($trace_file_name, $cpus_number, $cluster_size) = @ARGV;
die 'missing arguments: trace_file_name cpus_number cluster_size' unless defined $cluster_size;

# Create a directory to store the output
my $basic_file_name = "run_from_file-$cpus_number-$cluster_size";
mkdir $basic_file_name unless -f $basic_file_name;

# Read the trace and write it to a file
my $trace = Trace->new_from_swf($trace_file_name);

#my $schedule_fcfs = FCFS->new($trace, $cpus_number);
#$schedule_fcfs->run();
#print "FCFS: " . $schedule_fcfs->cmax() . "\n";
#$schedule_fcfs->save_svg("$basic_file_name/$basic_file_name-fcfs.svg");

#my $schedule_fcfsc = FCFSC->new($trace, $cpus_number);
#$schedule_fcfsc->run();
#print "FCFSC " . $schedule_fcfsc->cmax() . "\n";
#$schedule_fcfsc->save_svg("$basic_file_name/$basic_file_name-fcfsc.svg");

my $schedule_backfilling = Backfilling->new($trace, $cpus_number, $cluster_size);
$schedule_backfilling->run();
print "Backfilling " . $schedule_backfilling->cmax() . "\n";
$schedule_backfilling->save_svg("$basic_file_name/$basic_file_name-backfilling.svg");

#my $schedule_backfilling_contiguous = Backfilling->new($trace, $cpus_number, 1);
#$schedule_backfilling_contiguous->run();
#print "Backfilling contiguous " . $schedule_backfilling_contiguous->cmax() . "\n";
#$schedule_backfilling_contiguous->save_svg("$basic_file_name/$basic_file_name-backfilling_contiguous.svg");

