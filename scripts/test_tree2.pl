#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use BinarySearchTree2;
use TestPackage;

my $tree = BinarySearchTree2->new([-1, -1, -1]);

my @arr = ([5, 2], [4, 2], [7, 1], [6, 3], [2, 1], [8, 5], [9, 1], [3,3], [12, 2], [13, 4]);
#my @arr =([9, 3, 5], [2, 3, 8], [5, 3, 4], [7, 4, 1], [2, 3, 5], [4, 8, 4], [6, 5, 3], [3, 2, 1], [1, 2, 6]);
#my @arr =(5, 4, 7, 6, 2);

$tree->add_content($_,1) for(@arr);

$tree->tycat();

print STDERR "Remove\n";
#$tree->remove_content([2,3,8]);
$tree->remove_content([7,1]);

$tree->tycat();
$tree->display_subtrees();

print STDERR "Done\n";
