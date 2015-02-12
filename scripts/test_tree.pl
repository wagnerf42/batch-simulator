#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use BinarySearchTree;
use TestPackage;

my $tree = BinarySearchTree->new(-1, 0);
$tree->add(TestPackage->new($_)) for(qw(20 8 22 4 2 6 12 25 28 23 13 15));
$tree->save_svg("tree.svg");
#$tree->tycat();

$tree->nodes_loop2(undef, undef,
	sub {
		my $content = shift;
		print STDERR "Got content $content\n";
		return 1;
	});

print STDERR "Done\n";
