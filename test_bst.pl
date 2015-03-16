#!/usr/bin/env perl

use strict;
use warnings;
use BinarySearchTree;

my $tree = BinarySearchTree->new(-1);
for my $value (1..20) {
	print "add $value\n";
	$tree->add_content($value);
	$tree->tycat();
}

for my $value (qw(10 15)) {
	print "remove $value\n";
	$tree->remove_content($value);
	$tree->tycat();
}
