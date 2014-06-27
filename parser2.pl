#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper qw(Dumper);

use Trace;
use Schedule;
use Backfilling;

print "Executing parser version 2\n";

my $trace = new Trace($ARGV[0]);
$trace->read();

my $schedule = new Backfilling($trace, 4);
$schedule->run();

#my $schedule = new Schedule($trace, 3);
#$schedule->fcfs_contiguous();
#$schedule->print_schedule();
#$schedule->print_svg("parser2.svg", "parser2.pdf");

exit;


