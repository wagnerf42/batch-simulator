#!/usr/bin/env perl

use strict;
use warnings;

use ProcessorRange;

my $r = new ProcessorRange([1,2,3,5,6,9,13,14,15,17,18]);
my $r2 = new ProcessorRange([2,3,4,5,6,7,14,15,16,17,18]);


print "$r\n$r2\n";
$r->intersection($r2);

print "intersect in $r\n";
