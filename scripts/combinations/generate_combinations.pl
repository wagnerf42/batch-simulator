#!/usr/bin/env perl
use strict;
use warnings;

use Algorithm::Permute;
use Algorithm::Combinatorics qw(combinations);
use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use List::Util qw(min max);

Log::Log4perl::init('log4perl.conf');

my $logger = get_logger('test');

my @levels = (1, 2, 4, 16);
my @available_cpus = (0..($levels[$#levels] - 1));
#my @available_cpus = (0, 1, 2, 4, 5);
my $required_cpus = 4;
my $permutations_file_name = "permutations";

# Put everything in the log file
$logger->info("platform: @levels");
$logger->info("available cpus: @available_cpus");
$logger->info("required cpus: $required_cpus");

my @combinations = generate_combinations();
save_permutations();

sub generate_combinations {
	my @combinations;
	my $iterator = combinations(\@available_cpus, $required_cpus);

	while (my $combination = $iterator->next()) {
		push @combinations, $combination;
	}

	return @combinations;
}

sub save_permutations {
	open(my $file, '>', $permutations_file_name);

	for my $combination (@combinations) {
		my $iterator = Algorithm::Permute->new($combination);
		while (my @permutation = $iterator->next()) {
			print $file join('-', @permutation) . "\n";
		}
	}
}

sub get_log_file {
	return "log/generate_combinations.log";
}


