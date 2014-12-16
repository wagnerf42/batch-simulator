#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);
use List::Util qw(max);

use Trace;
use Schedule;
use Backfilling;
use BinarySearchTree;
use TestPackage;

my $bst = BinarySearchTree->new(TestPackage->new(-1));
$bst->add(TestPackage->new($_)) for (15, 10, 20, 8, 9);
print "$bst\n";
#my $number = <STDIN>;
#$bst->remove_element($number);
#print "$bst\n";
die;


my ($trace_file_name) = @ARGV;
my $trace = Trace->new_from_swf($trace_file_name);
$trace->reset_jobs_numbers();
$trace->fix_submit_times();
#my $cpus_number = $trace->needed_cpus();
my $cpus_number = 77248;
my $cluster_size = 16;
my $schedule = Backfilling->new(NEW_EXECUTION_PROFILE, $trace, $cpus_number, $cluster_size, BASIC);
$schedule->run();

#print join(' ', $_->job_number(), $_->{schedule_times}, $_->{improved_schedule_times}) . "\n" for @{$schedule->{jobs}};

print STDERR "Done\n";

