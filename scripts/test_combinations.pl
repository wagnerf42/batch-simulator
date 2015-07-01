#!/usr/bin/env perl
#

use strict;
use warnings;

use Data::Dumper;
use List::Util qw(reduce min);

my ($input_file, $cpus_number, $lines_per_combination) = @ARGV;


open(my $file, '<', $input_file) or die 'wrong file';

# Header
my $file_header = <$file>;
chomp $file_header;
my @file_header_parts = split(' ', $file_header);
my @benchmarks = @file_header_parts[1..$#file_header_parts];

my @permutations;

# Get each combination
while (my $line = <$file>) {
	chomp $line;
	my @line_parts = split(' ', $line);

	push @permutations, {
		permutation => $line_parts[0],
		times => [@line_parts[1..3]],
	};
}

my @best_times;
my @first_times;

for my $permutation (@permutations) {
	my $sorted_permutation = sort_permutation($permutation->{permutation});
	for my $benchmark_number (0..$#benchmarks) {
		my $time = $permutation->{times}->[$benchmark_number];
		if ($sorted_permutation eq $permutation->{permutation}) {
			$first_times[$benchmark_number]->{$sorted_permutation} = $time;
		}
		$best_times[$benchmark_number]->{$sorted_permutation} = $time unless defined $best_times[$benchmark_number]->{$sorted_permutation};
		$best_times[$benchmark_number]->{$sorted_permutation} = min($best_times[$benchmark_number]->{$sorted_permutation}, $time);
	}
}

for my $permutation (keys %{$best_times[0]}) {
	print "$permutation ";
	my @lfirst_times;
	my @lbest_times;
	my @ratios;
	for my $benchmark_number (0..$#benchmarks) {
		my $first_time = $first_times[$benchmark_number]->{$permutation};
		my $best_time = $best_times[$benchmark_number]->{$permutation};
		my $ratio = $first_time / $best_time;
		push @lfirst_times, $first_time;
		push @lbest_times, $best_time;
		push @ratios, $ratio;
	}
	print join(' ', @lfirst_times, @lbest_times, @ratios)."\n";
}

sub sort_permutation {
	my $string = shift;
	my @fields = split('-', $string);
	return join('-', sort {$a <=> $b} @fields);
}
