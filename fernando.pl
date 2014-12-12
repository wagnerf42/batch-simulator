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

my $bst = BinarySearchTree->new(-1);
$bst->add(10);
$bst->add(5);
$bst->add(15);
$bst->add(3);
$bst->add(1);
$bst->add(4);
$bst->add(6);
print "$bst\n";
$bst->remove_element(5);
print "$bst\n";
#print Dumper(@{$bst});
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

