#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Node;

my $tree = Node->new(-1);
$tree->add(10);
$tree->add(2);
$tree->add(20);
$tree->add(4);
$tree->add(5);
$tree->add(1);

my $node = $tree->find_node(4);
$tree->remove($node);

$node = $tree->find_node(10);
$tree->remove($node);

$tree->add(30);
$tree->add(3);
$tree->add(6);
$tree->add(4);
$tree->add(13);

$node = $tree->find_node(5);
$tree->remove($node);

#print Dumper($tree);
