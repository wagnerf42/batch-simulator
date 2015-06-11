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
		id => "AS_Root_c" . $cluster,
		prefix => "",
		suffix => "",
		radical => ($cluster * 16) . '-' . (($cluster + 1) * 16 - 1),
		power => "286.087kf",
		bw => "125MBps",
		lat => "24us",
		router_id => "AS_Root_c" . $cluster . "_r1",
	};
}

# Tree system
$xml->{platform}{AS}{AS} = {
	id => "AS_Tree",
	routing => "Floyd",
};

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

$xml->save('test.xml');
open(my $file, 'test.xml');
while (my $row = <$file>) {
	chomp $row;
	print "$row\n";
}

