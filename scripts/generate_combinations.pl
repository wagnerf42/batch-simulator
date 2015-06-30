#!/usr/bin/env perl
use strict;
use warnings;

use Algorithm::Permute;
use Algorithm::Combinatorics qw(combinations);
use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use List::Util qw(min max);

use Platform;

Log::Log4perl::init('log4perl.conf');

my $logger = get_logger('test');

my @levels = (1, 2, 4, 16);
#my @available_cpus = (0..($levels[$#levels] - 1));
my @available_cpus = (0, 1, 2, 4, 5);
my $required_cpus = 4;
my $permutations_file_name = "permutations";

# Put everything in the log file
$logger->info("platform: @levels");
$logger->info("available cpus: @available_cpus");
$logger->info("required cpus: $required_cpus");

my @combinations = generate_unique_combinations(8, 0, $levels[-1]/$levels[-2]);
print Dumper(@combinations);
die;

#my @combinations = generate_combinations();
#print Dumper(@combinations);
#save_permutations();

#sub generate_combinations {
#	my @combinations;
#	my $iterator = combinations(\@available_cpus, $required_cpus);
#
#	while (my $combination = $iterator->next()) {
#		push @combinations, $combination;
#	}
#
#	return @combinations;
#}

sub generate_unique_combinations {
	my $required_cpus = shift;
	my $start_cluster = shift;
	my $maximum_size = shift;

	print "generate($required_cpus, $start_cluster, $maximum_size)\n";

	my $cluster_size = $levels[-1]/$levels[-2];
	my $remaining_size = ($levels[-2] - $start_cluster) * $cluster_size;
	return if ($required_cpus > $remaining_size);

	return unless $required_cpus;
	return unless ($start_cluster < $levels[-2]);

	my @combinations;

	for (my $cpus_number = min($required_cpus, $maximum_size); $cpus_number >= 1; $cpus_number--) {
		if ($required_cpus - $cpus_number) {
			my @next_combinations = generate_unique_combinations($required_cpus - $cpus_number, $start_cluster + 1, min($cpus_number, $maximum_size));
			push @combinations, join('-', $cpus_number, $_) for (@next_combinations);
		} else {
			push @combinations, "$cpus_number";
		}
	}

	return @combinations;
}

#sub save_permutations {
#	open(my $file, '>', $permutations_file_name);
#
#	for my $combination (@combinations) {
#		my $iterator = Algorithm::Permute->new($combination);
#		while (my @permutation = $iterator->next()) {
#			print $file join('-', @permutation) . "\n";
#		}
#	}
#}

sub get_log_file {
	return "log/generate_combinations.log";
}


