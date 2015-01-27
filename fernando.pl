#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max);

use Trace;
use Schedule;
use Backfilling;
use BinarySearchTree;

use Heap;
use Event;

my $heap = Heap->new(Event->new(1, -1));
$heap->add(Event->new(1, 1));
$heap->add(Event->new(1, 1));
$heap->add(Event->new(1, 1));
$heap->add(Event->new(1, 1));

my $nhack = $heap->retrieve_all();
print Dumper($nhack);
die;

my ($trace_file_name) = @ARGV;
my $trace = Trace->new_from_swf($trace_file_name);
my $cpus_number = $trace->needed_cpus();
#$trace->reset_jobs_numbers();
$trace->fix_submit_times();
my $cluster_size = 16;

#my $schedule = Backfilling->new(REUSE_EXECUTION_PROFILE, $trace, $cpus_number, $cluster_size, BASIC);
#$schedule->run();
##$schedule->tycat("reuse.svg");

my $schedule2 = Backfilling->new(NEW_EXECUTION_PROFILE, $trace, $cpus_number, $cluster_size, BASIC);
$schedule2->run();
$schedule2->tycat("new.svg");

