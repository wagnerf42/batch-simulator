#!/usr/bin/env perl
use strict;
use warnings;

use XML::Smart;
use List::Util qw(sum);

my ($platform, $output_file) = @ARGV;

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
		src => "C-$cluster",
		dst => "AS_Tree",
		gw_src => "R-$#platform_parts-$cluster",
		gw_dst => 'R-' . ($#platform_parts - 1) . '-' . (int $cluster/($platform_parts[$#platform_parts]/$platform_parts[$#platform_parts - 1])),
		link_ctn => {id => "L-$cluster"},
	}
}

# Tree system
$xml->{platform}{AS}{AS} = {
	id => "AS_Tree",
	routing => "Floyd",
};

# Build levels
for my $level (0..($#platform_parts - 2)) {
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

# Generate the routers for the next level
push @{$xml->{platform}{AS}{AS}{router}}, {id => 'R-' . ($#platform_parts - 1) . "-$_"} for (0..($platform_parts[$#platform_parts]/$platform_parts[$#platform_parts - 1]) - 1);

$xml->save($output_file);

open(my $file, $output_file);
while (my $row = <$file>) {
	chomp $row;
	print "$row\n";
}

