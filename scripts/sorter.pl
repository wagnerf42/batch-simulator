#!/usr/bin/env perl

use strict;
use warnings;
use POSIX qw(floor);

my @permutations;
my @times;

my $cluster_size = 4;

open(my $file, '<', "$ARGV[0]") or die "missing experiment file";
<$file>;
while (my $line = <$file>) {
	my ($permutation, $time) = split(';', $line);
	push @permutations, $permutation;
	push @times, $time;
}
close($file);

for my $index (0..$#permutations) {
	my $permutation = $permutations[$index];
	my $time = $times[$index];
	my $signature = compute_permutation_signature($permutation, $cluster_size);
	print "$signature $time ($permutation)\n";
}

sub compute_permutation_signature {
	my $permutation = shift;
	my $cluster_size = shift;
	my @processors = split('-', $permutation);
	my @signature;
	my $first_processor = shift @processors;
	my $current_cluster = floor($first_processor/$cluster_size);
	my $current_cpus = 1;
	push @processors, -1; #enforces last push
	for my $processor (@processors) {
		my $cluster = floor($processor/$cluster_size);
		if ($current_cluster == $cluster) {
			$current_cpus++;
		} else {
			push @signature, "$current_cluster($current_cpus)";
			$current_cluster = $cluster;
			$current_cpus = 1;
		}
	}
	return join('-', @signature);
}

