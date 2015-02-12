#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use BinarySearchTree;
use TestPackage;

my $tree = BinarySearchTree->new(-1);
$tree->add(TestPackage->new($_)) for(qw(20 8 22 4 2 6 12));
$tree->save_svg("tree.svg");

my @nodes = $tree->find_node_range(4, 8);
print Dumper(@nodes);

print STDERR "Done\n";
