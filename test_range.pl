#!/usr/bin/env perl

use strict;
use warnings;

use ProcessorRange;

my $r = new ProcessorRange([1,2,3,5,6,9,13,14,15,17,18]);
#my $r2 = new ProcessorRange([2,3,4,5,6,7,14,15,16,17,18]);

print "contains : ".join(' ', $r->processors_ids())."\n";

$r->reduce_to_best_effort_contiguous(5);
print("after reducing to 5 processors : $r\n");

$r = new ProcessorRange([1,2,3,5,6,9,13,14,15,17,18]);
$r2 = new ProcessorRange([2,3,4,5,6,7,14,15,16,17,18]);
print "$r\n$r2\n";
$r->remove($r2);
print "difference : $r\n";

