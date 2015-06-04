#!/usr/bin/env perl
use strict;
use warnings;
use FreeSchedule;
use Trace;

die "please give a swf trace file" unless defined $ARGV[0] and -f $ARGV[0];

my $trace = Trace->new_from_swf($ARGV[0]);
$trace->reset_requested_times();

my $schedule = FreeSchedule->new($trace, 33000);
$schedule->run();
$schedule->tycat();


