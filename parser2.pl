#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;

print "Executing parser version 2\n";

my $trace = Trace->new($ARGV[0]);
$trace->read();

my $trace_random = Trace->new();
$trace_random->read_from_trace($trace, 120);
$trace_random->write("random.swf");

my $schedule_backfilling = Backfilling->new($trace_random, $trace_random->needed_cpus);
$schedule_backfilling->run();
$schedule_backfilling->print_svg("parser2.svg", "parser2.pdf");

my $schedule_FCFS = new FCFS($trace_random, $trace_random->needed_cpus);
$schedule_FCFS->run();
$schedule_FCFS->print_svg("parser2_fcfs.svg", "parser2_fcfs.pdf");

print $schedule_backfilling->cmax . " " . $schedule_FCFS->cmax . "\n";
exit;

