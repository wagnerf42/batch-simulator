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

# Clusters
for my $cluster (0..($platform_parts[$#platform_parts] - 1)) {
	$xml->{platform}{AS}{cluster}[$cluster] = {
		id => "C-$cluster",
		prefix => "",
		suffix => "",
		radical => ($cluster * 16) . '-' . (($cluster + 1) * 16 - 1),
		power => "286.087kf",
		bw => "125MBps",
		lat => "24us",
		router_id => "R-$#platform_parts-$cluster",
	};

	$xml->{platform}{AS}{link}[$cluster] = {
		id => "L-$cluster",
		bandwidth => "1.25GBps",
		latency => "24us",
	};

	$xml->{platform}{AS}{ASroute}[$cluster] = {
		src => "L-$cluster",
		dst => "AS_Tree",
		gw_src => "R-$#platform_parts-$cluster",
		gw_dst => 'R-',
		link_ctn => {id => "L-$cluster"},
	}
}

# Tree system
$xml->{platform}{AS}{AS} = {
	id => "AS_Tree",
	routing => "Floyd",
};

# Build levels
for my $level (0..($#platform_parts - 1)) {
	my $links_number = $platform_parts[$level + 1]/$platform_parts[$level];
	my $nodes_number = $platform_parts[$level];

	for my $node_number (0..($nodes_number - 1)) {
		push @{$xml->{platform}{AS}{AS}{router}}, {id => "R-$level-$node_number"};

		for my $base_link_number (0..($links_number - 1)) {
			my $link_number = $node_number * $links_number + $base_link_number;
			push @{$xml->{platform}{AS}{AS}{link}}, {id => "L-$level-$link_number" , bandwidth => "1.25GBps", latency => "24us"};

			push @{$xml->{platform}{AS}{AS}{route}}, {
				src => "R-$level-$node_number",
				dst => 'R-' . ($level + 1) . "-$link_number",
				link_ctk => {id => "L-$level-$link_number"},
			};
		}
	}
}

$xml->save('test.xml');
open(my $file, 'test.xml');
while (my $row = <$file>) {
	chomp $row;
	print "$row\n";
}

die;

# Switches
my $switches_number = sum @platform_parts[0..($#platform_parts - 1)];
$xml->{platform}{AS}{AS}{router}[$_] = {id => "AS_Tree_s" . $_} for (0..($switches_number - 1));

# Routers for clusters
my $routers_number = $platform_parts[$#platform_parts];
$xml->{platform}{AS}{AS}{router}[$_] = {id => "AS_Tree_r" . ($_ - $switches_number)} for ($switches_number..($switches_number + $routers_number - 1));

# Links
my $total_links_number = 0;
for my $level (0..($#platform_parts - 1)) {
	my $links_number = $platform_parts[$level + 1]/$platform_parts[$level];

	$xml->{platform}{AS}{AS}{link}[$total_links_number + $_] = {
		id => "AS_Tree_l" . ($total_links_number + $_),
		bandwidth => "1.25GBps",
		latency => "24us"
	} for (0..($links_number - 1));

	$xml->{platform}{AS}{AS}{route} = {
		src => "",
		dst => "",
	};

	$total_links_number += $links_number;
	last;
}

sub _build_level {
	my $level = shift;
	my $node = shift;

	return if ($level == $#platform_parts);

	my $children_number = $platform_parts[$level + 1]/$platform_parts[$level];
	print STDERR "$level-$node-$children_number\n";

	# Create the switch as a router
	push @{$xml->{platform}{AS}{AS}{router}}, {id => "S-$level-$node"};

	for my $node (0..($children_number - 1)) {
		# Create the link
		push @{$xml->{platform}{AS}{AS}{link}}, {id => "L-$level-$node", bandwidth => "1GBps", latency => "1ms"};
		_build_level($level + 1, $node);
	}
}

