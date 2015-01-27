#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max);

use Trace;
use Schedule;
use Backfilling;
use BinarySearchTree;

my ($trace_file_name) = @ARGV;
my $cpus_number = 18;
my $trace = Trace->new_from_swf($trace_file_name);
$trace->remove_large_jobs($cpus_number);
#$trace->reset_jobs_numbers();
$trace->fix_submit_times();
my $cluster_size = 16;

my $schedule = Backfilling->new(REUSE_EXECUTION_PROFILE, $trace, $cpus_number, $cluster_size, BASIC);
$schedule->run();
$schedule->tycat("reuse.svg");

my $schedule2 = Backfilling->new(NEW_EXECUTION_PROFILE, $trace, $cpus_number, $cluster_size, BASIC);
$schedule2->run();
$schedule2->tycat("new.svg");

