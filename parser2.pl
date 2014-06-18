#!/usr/bin/perl

use strict;
use warnings;

use Trace;

print "Executing parser version 2\n";

my $trace = new Trace($ARGV[0]);

$trace->read();
$trace->print();
#$trace->print_jobs_time_ratio();
$trace->print_jobs();

exit;


