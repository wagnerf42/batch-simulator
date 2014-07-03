#!/usr/bin/env perl

use strict;
use warnings;
use Data::Dumper qw(Dumper);

use Trace;
use FCFS;
use FCFSC;
use Backfilling;

print "Executing parser version 2\n";

my $trace = Trace->new($ARGV[0]);
$trace->read();

my $schedule;
#$schedule = Backfilling->new($trace, $trace->requested_cpus());
$schedule = Backfilling->new($trace, 6);
$schedule->run();
$schedule->print();

#$schedule = new FCFSC($trace, 4);
#$schedule->run();
#$schedule->print();
#$schedule->save_svg("parser2.svg");

$schedule->print_svg("parser2.svg", "parser2.pdf");

exit;


