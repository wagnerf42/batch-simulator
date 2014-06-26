#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper qw(Dumper);

use Trace;
use Schedule;

my $trace = new Trace($ARGV[0]);
$trace->read();

my $schedule = new Schedule($trace, 8);
$schedule->fcfs_contiguous();
#$schedule->print_schedule();
$schedule->print_svg2("parser2.svg", "parser2.pdf");

exit;


