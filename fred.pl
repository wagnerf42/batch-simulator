#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;

my $t = Trace->new_from_swf($ARGV[0]);
$t->remove_large_jobs(2000);
$t->reset_submit_times();
my $r = new_from_trace Trace($t, 3000);
my $schedule = new Backfilling($r, 2000, 4, 3);

$schedule->run();
#$schedule->tycat();

print "Done\n";
