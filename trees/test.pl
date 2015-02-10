#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use Node;

my $tree = Node->new(-1);
$tree->add($_) for(qw(10 2 20 4 5 1));

my $node = $tree->find_node(4);
$node->remove();
print STDERR "removed 4\n";
$tree->create_dot();

$node = $tree->find_node(10);
$node->remove();
print STDERR "removed 10\n";
$tree->create_dot();

$tree->add(30);
$tree->add(3);
$tree->add(6);
$tree->add(4);
$tree->add(13);

$node = $tree->find_node(5);
$node->remove();
print STDERR "removed 5\n";
$tree->create_dot();

#print Dumper($tree);
