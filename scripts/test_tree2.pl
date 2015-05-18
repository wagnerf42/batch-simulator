#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use BinarySearchTree2;

my $tree = BinarySearchTree2->new([-1, -1, -1]);

my @arr =([5, 0, 4], [4, 5, 9], [7, 12 ,7], [20, 10, 14], [5, 10, 14], [6, 8, 19], [5, 0, 14], [10, 5, 10],
          [4, 12, 3], [15, 2, 7], [5, 13, 20], [7, 5 , 20], [15, 8, 12], [12, 7, 4], [6, 10, 14],
          [10, 4, 6], [19, 12, 6]);

$tree->add_content($_,1) for(@arr);

$tree->tycat();
#$tree->display_subtrees();

my $start = [5,0,4];
my $end = [20,10,14];
print "start @$start ; end : @$end\n";
$tree->nodes_loop($start, $end, sub{
  my $node = shift;
  print STDERR "Node found for this range! $node\n";
  return 1;
});

print STDERR "Done\n";
