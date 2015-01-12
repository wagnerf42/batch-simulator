# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl ProcessorRange.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 19;
BEGIN { use_ok('ProcessorRange') };

#########################

my ($r, $s);
##basic routines
#new and stringification
$r = ProcessorRange->new(1,2);
ok ("$r" eq '[1-2]');
$r = ProcessorRange->new(1,1, 3,5);
ok ("$r" eq '[1-1] [3-5]');

##set operations
#invert
$r = ProcessorRange->new(1,5)->invert(9);
ok("$r" eq '[0-0] [6-9]');
$r = ProcessorRange->new(1,5)->invert(3);
ok("$r" eq '[0-0]');
$r = ProcessorRange->new(1,2, 5,6, 9,14)->invert(20);
ok("$r" eq '[0-0] [3-4] [7-8] [15-20]');

#intersection
$r = ProcessorRange->new(3,7);
$s = ProcessorRange->new(2,5);
$r->intersection($s);
ok("$r" eq '[3-5]');

$r = ProcessorRange->new(0,7, 12,14);
$s = ProcessorRange->new(3,5, 7,13);
$r->intersection($s);
ok("$r" eq '[3-5] [7-7] [12-13]');

#removal
$r = ProcessorRange->new(1,7);
$s = ProcessorRange->new(3,4);
$r->remove($s);
ok("$r" eq '[1-2] [5-7]');

$r = ProcessorRange->new(1,3, 6,8);
$s = ProcessorRange->new(0,0, 2,2, 4,5);
$r->remove($s);
ok("$r" eq '[1-1] [3-3] [6-8]');

#add
$r = ProcessorRange->new(1,4, 9,10);
$s = ProcessorRange->new(6,6);
$r->add($s);
ok("$r" eq '[1-4] [6-6] [9-10]');

##reductions
#first
$r = ProcessorRange->new(1,1, 3,3, 6,8);
$r->reduce_to_basic(2);
ok("$r" eq '[1-1] [3-3]');

$r = ProcessorRange->new(1,4, 9,10);
$s = ProcessorRange->new(5,6);
$r->add($s);
ok("$r" eq '[1-6] [9-10]');

$r = ProcessorRange->new(1,4, 9,10);
$s = ProcessorRange->new(5,8);
$r->add($s);
ok("$r" eq '[1-10]');

$r = ProcessorRange->new(1,4, 9,10);
$s = ProcessorRange->new(3,12);
$r->add($s);
ok("$r" eq '[1-12]');

#contiguous
$r = ProcessorRange->new(1,1, 3,3, 6,8);
$r->reduce_to_forced_contiguous(2);
ok("$r" eq '[6-7]');

##statistics routines
#contiguous
ok(ProcessorRange->new(0,9)->contiguous(10));
ok(ProcessorRange->new(0,3, 5,9)->contiguous(10));
ok(not ProcessorRange->new(1,3, 5,8)->contiguous(10));
