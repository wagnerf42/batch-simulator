#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Trace;
use Backfilling;

my $trace = Trace->new_from_swf($ARGV[0]);
my $schedule = new Backfilling($trace, 16, 16, 3);

$schedule->run();
$schedule->tycat();

print "Done\n";
