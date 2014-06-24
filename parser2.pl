#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper qw(Dumper);

use Trace;
use Schedule_FCFS;

print "Executing parser version 2\n";

my $trace = new Trace($ARGV[0]);
$trace->read();
my $schedule = new Schedule_FCFS($trace);

$schedule->run();

$trace->print();
#$trace->print_jobs_time_ratio();
$trace->print_jobs();

exit;


