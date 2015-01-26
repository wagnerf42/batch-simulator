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
my $trace = Trace->new_from_swf($trace_file_name);
#$trace->reset_jobs_numbers();
$trace->fix_submit_times();
my $cpus_number = $trace->needed_cpus();
my $cluster_size = 16;
#my $schedule = Backfilling->new(NEW_EXECUTION_PROFILE, $trace, $cpus_number, $cluster_size, BASIC);
my $schedule = Backfilling->new(REUSE_EXECUTION_PROFILE, $trace, $cpus_number, $cluster_size, BASIC);
$schedule->run();
$schedule->tycat("reuse.svg");

print STDERR "Done\n";

