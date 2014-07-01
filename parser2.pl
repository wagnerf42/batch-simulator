#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper qw(Dumper);

use Trace;
#use FCFS;
use FCFSC;
use Backfilling;

print "Executing parser version 2\n";

my $trace = new Trace($ARGV[0]);
$trace->read();

#my $schedule = new Backfilling($trace, 4);
#$schedule->run();
#$schedule->print_svg("parser2.svg", "parser2.pdf");

my $schedule = new FCFSC($trace, 8);
$schedule->run();
#$schedule->print();
$schedule->save_svg("parser2.svg");

exit;


