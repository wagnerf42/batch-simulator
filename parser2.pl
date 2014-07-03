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

my $schedule_backfilling = Backfilling->new($trace, $trace->needed_cpus);
$schedule_backfilling->run();
$schedule_backfilling->print_svg("parser2.svg", "parser2.pdf");
exit;

