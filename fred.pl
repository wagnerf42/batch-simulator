#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;

my $cpus = 9;
my $t = Trace->new_from_swf($ARGV[0]);
$t->remove_large_jobs($cpus);
$t->reset_submit_times();
#$t->write_to_file('test.swf');
my $schedule = Backfilling->new(REUSE_EXECUTION_PROFILE, $t, $cpus, 4, BASIC);
$schedule->run();
$schedule->tycat();

my $schedule2 = Backfilling->new(NEW_EXECUTION_PROFILE, $t, $cpus, 4, BASIC);
$schedule2->run();
$schedule2->tycat();



print "Done\n";
