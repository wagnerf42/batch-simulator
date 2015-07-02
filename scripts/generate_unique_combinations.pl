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

my @levels = (1,2,4,8,64);
my @available_cpus = (0..($levels[$#levels] - 1));
#my @available_cpus = (0, 1, 2, 4, 5);
my $required_cpus = 8;
my $combinations_file_name = "permutations";
my $cluster_size = $levels[-1]/$levels[-2];

# Put everything in the log file
$logger->info("platform: @levels");
$logger->info("available cpus: @available_cpus");
$logger->info("required cpus: $required_cpus");

my @combinations = generate_unique_combinations($required_cpus, 0);
save_combinations();

sub generate_unique_combinations {
	my $required_cpus = shift;
	my $level = shift;

	return "$required_cpus" if ($level == $#levels - 1);

	unless ($required_cpus) {
		my $level_size = $levels[-1]/$levels[$level];
		my $cluster_size = $levels[-1]/$levels[-2];
		my $clusters_number = $level_size/$cluster_size;
		return join('-', ('0') x $clusters_number);
	}

	my @next_combinations = next_combinations($required_cpus, $level + 1, 0, $required_cpus);
	my @combinations;

	for my $next_combination (@next_combinations) {
		my @merging_combinations;
		my @combination_parts = split('-', $next_combination);
		for my $node_number (0..$#combination_parts) {
			my @node_combinations = generate_unique_combinations($combination_parts[$node_number], $level + 1);
			@merging_combinations = merge_combinations(\@merging_combinations, \@node_combinations);
		}
		push @combinations, @merging_combinations;
	}
	return @combinations;
}

sub merge_combinations {
	my $combinations = shift;
	my $node_combinations = shift;

	my @merged_combinations;

	# On the first call $combinations will be empty
	return @$node_combinations unless (@{$combinations});

	for my $combination (@$combinations) {
		for my $node_combination (@$node_combinations) {
			push @merged_combinations, join('-', $combination, $node_combination);
		}
	}

	return @merged_combinations;
}

sub next_combinations {
	my $required_cpus = shift;
	my $level = shift;
	my $node_number = shift;
	my $maximum_cpus = shift;

	return if ($node_number >= $levels[$level]);

	my @combinations;
	my $level_size = $levels[-1]/$levels[$level];
	my $level_arity = $levels[$level]/$levels[$level - 1];

	for (my $cpus_number = min($level_size, $maximum_cpus); $cpus_number >= 1; $cpus_number--) {
		if ($required_cpus - $cpus_number) {
			my $remaining_level_size = ($level_arity - $node_number - 1) * $level_size;
			last if ($remaining_level_size < $required_cpus - $cpus_number);

			my @next_combinations = next_combinations($required_cpus - $cpus_number, $level, $node_number + 1, $cpus_number);
			push @combinations, join('-', $cpus_number, $_) for (@next_combinations);
		} else {
			push @combinations, join('-', "$cpus_number", ('0') x (($levels[$level]/$levels[$level - 1]) - $node_number - 1));
		}
	}
	return @combinations;
}

sub save_combinations {
	open(my $file, '>', $combinations_file_name);

	for my $combination (@combinations) {
		my @combination_parts = split('-', $combination);
		my @selected_cpus;
		for my $node_number (0..$#combination_parts) {
			my @cluster_cpus = map {$node_number * $cluster_size + $_} (0..($combination_parts[$node_number] - 1));
			push @selected_cpus, @cluster_cpus;
		}

		print $file join('-', @selected_cpus) . "\n";
	}

	return;
}

sub get_log_file {
	return "log/generate_combinations.log";
}


