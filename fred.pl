#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;

my $t = Trace->new_from_swf($ARGV[0]);
$t->remove_large_jobs(2000);
$t->reset_submit_times();
my $schedule = Backfilling->new(REUSE_EXECUTION_PROFILE, $t, 2000, 4, BASIC);
#my $schedule = Backfilling->new(NEW_EXECUTION_PROFILE, $t, 2000, 4, BASIC);

$schedule->run();
#$schedule->tycat();

print "Done\n";
