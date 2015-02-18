#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper qw(Dumper);

use BinarySearchTree;
use TestPackage;

my $tree = BinarySearchTree->new(-1, 0);
$tree->add_content(TestPackage->new($_)) for(qw(15 9 11));
$tree->tycat();

my $node = $tree->find_previous_content(10);
print STDERR "$node\n";
die;

$tree->nodes_loop2(undef, undef,
	sub {
		my $content = shift;
		print STDERR "Got content $content\n";
		return 1;
	});

print STDERR "Done\n";
