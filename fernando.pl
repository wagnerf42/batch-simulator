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

my ($trace_file_name, $jobs_number, $algorithm) = @ARGV;
my $trace = Trace->new_from_swf($trace_file_name, $jobs_number);
my $cpus_number = $trace->needed_cpus();
#$trace->reset_jobs_numbers();
$trace->fix_submit_times();
my $cluster_size = 16;

my $schedule = Backfilling->new($algorithm, $trace, $cpus_number, $cluster_size, BASIC);
$schedule->run();
$schedule->tycat("$algorithm.svg");
#print "$jobs_number $schedule->{schedule_time}\n";

#print STDERR "Done\n";

