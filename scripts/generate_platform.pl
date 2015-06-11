#!/usr/bin/env perl
use strict;
use warnings;

use XML::Smart;
use List::Util qw(sum);

my ($platform) = @ARGV;
my @platform_parts = split('-', $platform);
my $xml = XML::Smart->new();

$xml->{platform} = {version => 3};

# Root system
$xml->{platform}{AS} = {
	id => "AS_Root",
	routing => "Full",
};

# Tree system
$xml->{platform}{AS}{AS} = {
	id => "AS_Tree",
	routing => "Floyd",
};

# Push the first router
push @{$xml->{platform}{AS}{AS}{router}}, {id => "R-0-0"};

# Build levels
for my $level (1..$#platform_parts) {
	my $nodes_number = $platform_parts[$level];

	for my $node_number (0..($nodes_number - 1)) {
		push @{$xml->{platform}{AS}{AS}{router}}, {id => "R-$level-$node_number"};

		my $father_node = int $node_number/($platform_parts[$level]/$platform_parts[$level - 1]);
		push @{$xml->{platform}{AS}{AS}{link}}, {
			id => "L-$level-$node_number",
			bandwidth => "1.25GBps",
			latency => "24us",
		};

		push @{$xml->{platform}{AS}{AS}{route}}, {
			src => 'R-' . ($level - 1) . "-$father_node",
			dst => "R-$level-$node_number",
			link_ctn => {id => "L-$level-$node_number"},
		};
	}
}

# Clusters
for my $cluster (0..($platform_parts[$#platform_parts] - 1)) {
	push @{$xml->{platform}{AS}{cluster}}, {
		id => "C-$cluster",
		prefix => "",
		suffix => "",
		radical => ($cluster * 16) . '-' . (($cluster + 1) * 16 - 1),
		power => "286.087kf",
		bw => "125MBps",
		lat => "24us",
		router_id => "R-$cluster",
	};

	push @{$xml->{platform}{AS}{link}}, {
		id => "L-$cluster",
		bandwidth => "1.25GBps",
		latency => "24us",
	};

	push @{$xml->{platform}{AS}{ASroute}}, {
		src => "C-$cluster",
		gw_src => "R-$cluster",
		dst => "AS_Tree",
		gw_dst => "R-$#platform_parts-$cluster",
		link_ctn => {id => "L-$cluster"},
	}
}

print "<?xml version=\'1.0\'?>\n";
print "<!DOCTYPE platform SYSTEM \"http://simgrid.gforge.inria.fr/simgrid.dtd\">\n";
print $xml->data(noheader => 1, nometagen => 1);
