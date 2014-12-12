#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max);

use Trace;
use Schedule;
use Backfilling;
use BinarySearchList;
use Util;
use TestPackage;
use BinarySearchTree;

my $bst = BinarySearchTree->new_test();
print "$bst\n";
$bst->add(15);
print "$bst\n";
die;

my ($trace_file_name, $cluster_size) = @ARGV;

my $trace = Trace->new_from_swf($trace_file_name);
$trace->reset_jobs_numbers();
$trace->fix_submit_times();
#my $cpus_number = $trace->needed_cpus();
my $cpus_number = 77248;
my $schedule = Backfilling->new(NEW_EXECUTION_PROFILE, $trace, $cpus_number, $cluster_size, BASIC);
$schedule->run();

print join(' ', $_->job_number(), $_->{schedule_times}, $_->{improved_schedule_times}) . "\n" for @{$schedule->{jobs}};

print STDERR "Done\n";

