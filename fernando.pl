#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;
use ExecutionProfile ':stooges';

my $trace = Trace->new_from_swf($ARGV[0]);
$trace->remove_large_jobs(9);
$trace->reset_submit_times();

my $schedule = new Backfilling($trace, 9, 9, EP_BEST_EFFORT);

$schedule->run();
$schedule->tycat();

print "Done\n";
