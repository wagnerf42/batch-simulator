#!/usr/bin/env perl
use strict;
use warnings;

use Algorithm::Permute;
use Algorithm::Combinatorics qw(combinations);
use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);

use Platform;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('generate_permutations');

my ($cluster_size, $permutation) = @ARGV;
my @cpus = split('-', $permutation);
my @all_permutations = permutations(\@cpus);
my @duplicated_permutations;
my @final_permutations;

for my $permutation (@all_permutations) {
	unless (grep { $_ eq $permutation } @duplicated_permutations) {
		my @equivalent_permutations = equivalent_permutations($permutation);
		push @duplicated_permutations, @equivalent_permutations;
		push @final_permutations, $permutation;
	}
}

print join("\n", @final_permutations);

sub equivalent_permutations {
	my $permutation = shift;

	my @permutation_cpus = split('-', $permutation);
	my $permutation_size = scalar @permutation_cpus;
	my $clusters_number = $permutation_size/$cluster_size;
	my @combined_permutations;

	for my $cluster (0..($clusters_number - 1)) {
		my @cluster_cpus = @permutation_cpus[($cluster * $cluster_size)..(($cluster + 1) * $cluster_size - 1)];
		my @cluster_permutations = permutations(\@cluster_cpus);
		if (scalar @combined_permutations) {
			@combined_permutations = combine_permutations(\@combined_permutations, \@cluster_permutations);
		} else {
			@combined_permutations = @cluster_permutations;
		}
	}

	return @combined_permutations;
}

sub permutations {
	my $elements = shift;

	my @permutations;
	my $iterator = Algorithm::Permute->new($elements);

	while (my @permutation = $iterator->next()) {
		push @permutations, join('-', @permutation);
	}

	return @permutations;
}

sub combine_permutations {
	my $initial_permutations = shift;
	my $additional_permutations = shift;

	my @final_permutations;

	for my $initial_permutation (@$initial_permutations) {
		for my $additional_permutation (@$additional_permutations) {
			push @final_permutations, join('-', $initial_permutation, $additional_permutation);
		}
	}

	return @final_permutations;
}

sub get_log_file {
	return "log/generate_permutations.log";
}


