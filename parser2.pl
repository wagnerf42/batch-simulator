#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper qw(Dumper);

use Trace;
use Schedule;

print "Executing parser version 2\n";

my $trace = new Trace($ARGV[0]);
$trace->read();

my $schedule = new Schedule($trace, 8);
$schedule->fcfs();

print "\n";
exit;


