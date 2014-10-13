#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;

my $trace = Trace->new_from_swf($ARGV[0]);
$trace->remove_large_jobs(8);
$trace = Trace->new_from_trace($trace, 20);

my $schedule = new Backfilling($trace, 8);
$schedule->run();

$schedule->tycat();
