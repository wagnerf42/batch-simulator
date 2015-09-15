#!/usr/bin/env perl
use strict;
use warnings;

use Algorithm::Permute;
use Algorithm::Combinatorics qw(combinations);
use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use POSIX qw(floor);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('generate_permutations');

my ($cpus_number, $cluster_size) = @ARGV;
my @cpus = map { $_ } (0..($cpus_number - 1));
my @all_permutations = permutations(\@cpus);
my %seen_signatures;
my @final_permutations;

for my $permutation (@all_permutations) {
	my $permutation_signature = compute_permutation_signature($permutation);

	unless (exists $seen_signatures{$permutation_signature}) {
		$seen_signatures{$permutation_signature} = $permutation;
		push @final_permutations, $permutation;
	}
}

print join("\n", @final_permutations);

sub permutations {
	my $elements = shift;

	my @permutations;
	my $iterator = Algorithm::Permute->new($elements);

	while (my @permutation = $iterator->next()) {
		push @permutations, join('-', @permutation);
	}

	return @permutations;
}

sub compute_permutation_signature {
	my $permutation = shift;

	my @processors = split('-', $permutation);
	my $first_processor = shift @processors;
	my $current_cluster = floor($first_processor/$cluster_size);
	my $current_cpus = 1;
	my @signature;

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

sub get_log_file {
	return "log/generate_permutations.log";
}


