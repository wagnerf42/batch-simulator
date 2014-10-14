#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;

my $trace = Trace->new_from_swf($ARGV[0]);
$trace->remove_large_jobs(16);
my $t2 = new_from_trace Trace($trace, 20);
my $schedule = new Backfilling($t2, 16, 16, 3);

$schedule->run();
$schedule->tycat();

print "Done\n";
