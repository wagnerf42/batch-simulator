#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;

my $trace = Trace->new_from_swf($ARGV[0]);

my $schedule_fcfs = FCFS->new($trace, $ARGV[1]);
$schedule_fcfs->run();
print STDERR "fcfs: ".$schedule_fcfs->cmax()."\n";
$schedule_fcfs->tycat();

my $schedule_backfilling = Backfilling->new($trace, $ARGV[1]);
$schedule_backfilling->run();
print STDERR "backfilling: ".$schedule_backfilling->cmax()."\n";
$schedule_backfilling->tycat();

