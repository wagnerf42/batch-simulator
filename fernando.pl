#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;
use ExecutionProfile ':stooges';

my $trace = Trace->new_from_swf($ARGV[0]);
$trace->remove_large_jobs(10240);
$trace->reset_submit_times();

my $schedule = new Backfilling($trace, 10240, 16, EP_CONTIGUOUS);

$schedule->run();
$schedule->tycat();

print "Done\n";
