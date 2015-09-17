#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use POSIX qw(floor);

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('generate_random_permutations');

my ($cpus_number, $cluster_size, $permutations_number) = @ARGV;
my @cpus = reverse map { $_ } (0..($cpus_number - 1));
my %seen_signatures;
my $chosen_permutations_number = 0;

while ($chosen_permutations_number < $permutations_number) {

	fisher_yates_shuffle(\@cpus);

	my $permutation = join('-', @cpus);
	my $signature = compute_permutation_signature($permutation);

	unless (exists $seen_signatures{$signature}) {
		$seen_signatures{$signature} = undef;
		$chosen_permutations_number++;
		print "$permutation\n";
	}
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

sub fisher_yates_shuffle {
	my $array = shift;
	my $i;
	for ($i = @$array; --$i; ) {
		my $j = int rand ($i+1);
		next if $i == $j;
		@$array[$i,$j] = @$array[$j,$i];
	}
}

sub get_log_file {
	return "log/generate_random_permutations.log";
}
