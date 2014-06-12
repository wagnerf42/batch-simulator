#!/usr/bin/perl

use strict;
use warnings;

use Trace;

my $trace = new Trace($ARGV[0]);

$trace->read();
$trace->print();

exit;


