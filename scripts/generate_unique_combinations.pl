#!/usr/bin/env perl
use strict;
use warnings;

use Algorithm::Permute;
use Data::Dumper;
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use List::Util qw(min max reduce);

use Platform;

Log::Log4perl::init('log4perl.conf');
my $logger = get_logger('test');

my @levels = (1, 2, 4, 8, 64);
my @available_cpus = (0..($levels[$#levels] - 1));
#my @available_cpus = (0, 1, 2, 4, 5);
my $required_cpus = 8;
my $combinations_file_name = "permutations";
my $cluster_size = $levels[-1]/$levels[-2];

# Put everything in the log file
$logger->info("platform: @levels");
$logger->info("available cpus: @available_cpus");
$logger->info("required cpus: $required_cpus");

generate_cluster_combinations('6-1-1', 0);

my @combinations = generate_unique_combinations(8, 0, $levels[-1]/$levels[-2]);
save_combinations();

sub generate_unique_combinations {
	my $required_cpus = shift;
	my $start_cluster = shift;
	my $maximum_size = shift;

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

sub generate_cluster_combinations {
	my $combination = shift;
	my $current_level = shift;

	my $next_level_arity = $levels[$current_level + 1];
	my $next_level_size = level_total_size($current_level + 1);

	my @possible_divisions = possible_divisions($combination, $next_level_arity, $next_level_size);


}

sub level_total_size {
	my $level = shift;
	return $levels[-1]/$levels[$level];
}

sub possible_divisions {
	my $combination = shift;
	my $next_level_arity = shift;
	my $next_level_size = shift;

	my @combination_parts = split('-', $combination);

	my @possible_divisions;

	for my $i (0..


}

sub save_combinations {
	open(my $file, '>', $combinations_file_name);

	for my $combination (@combinations) {
		my @combination_parts = split('-', $combination);
		my @selected_cpus;
		for my $cluster_number (0..$#combination_parts) {
			my @cluster_cpus = map {$cluster_number * $cluster_size + $_} (0..($combination_parts[$cluster_number] - 1));
			push @selected_cpus, @cluster_cpus;
		}

		print $file join('-', @selected_cpus) . "\n";
	}

	return;
}

sub get_log_file {
	return "log/generate_combinations.log";
}


