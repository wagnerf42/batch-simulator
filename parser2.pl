#!/usr/bin/perl

use strict;
use warnings;

use Trace;

my $trace = new Trace("small2.swf");

$trace->read();
$trace->print_jobs();

exit;


